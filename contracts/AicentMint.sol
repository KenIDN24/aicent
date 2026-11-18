// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IAicentToken {
    function mint(address to, uint256 amount) external;
}

interface IAgentIdRegistry {
    function ownerOf(uint256 tokenId) external view returns (address);
}

/// @title aicent share mint
/// @notice Tiered USDT mint modelled on the Jager curve, shifted to a 0.5U start.
/// - Payment in USDT (6 decimals). 1 share = 1 AICENT minted immediately (v1).
/// - Gate: caller must own the Agent ID passed in (registry.ownerOf check).
/// - Cap: 10 shares per Agent ID, 4,440,000 shares total.
/// - Split: 20% of each payment goes to treasury immediately, 80% stays in
///   this contract as poolReserve for future PancakeSwap pool seeding.
/// @dev v1 trust note: the owner can withdraw the pool reserve via
/// withdrawReserve. Before mainnet, replace that with a seedLiquidity()
/// function that can ONLY add USDT + AICENT to PancakeSwap.
contract AicentMint is Ownable {
    uint256 public constant MAX_SHARES = 4440000;
    uint256 public constant MAX_PER_AGENT_ID = 10;
    uint256 public constant TREASURY_BPS = 2000; // 20%

    IERC20 public immutable usdt;
    IAicentToken public immutable token;
    IAgentIdRegistry public immutable registry;
    address public treasury;

    uint256 public totalSold;
    uint256 public poolReserve; // USDT held for future pool seeding
    mapping(uint256 => uint256) public sharesByAgentId;

    event Minted(address indexed buyer, uint256 indexed agentTokenId, uint256 shares, uint256 cost);
    event TreasuryUpdated(address indexed treasury);

    /// @notice Owner is passed explicitly (not msg.sender) so the contract can
    /// be deployed through a factory while the user's wallet still becomes owner.
    constructor(address usdt_, address token_, address registry_, address treasury_, address owner_) Ownable(owner_) {
        require(
            usdt_ != address(0) && token_ != address(0) && registry_ != address(0) && treasury_ != address(0) && owner_ != address(0),
            "zero address"
        );
        usdt = IERC20(usdt_);
        token = IAicentToken(token_);
        registry = IAgentIdRegistry(registry_);
        treasury = treasury_;
    }

    /// @notice Price in USDT (6 decimals) of the next share given `sold` already sold.
    /// Jager tier curve shifted from a 1U start to a 0.5U start (same step sizes).
    function priceFor(uint256 sold) public pure returns (uint256) {
        if (sold < 10000) return 500000; // 0.50U
        if (sold < 21000) return 600000 + 100000 * ((sold - 10000) / 1000);
        if (sold < 100000) return 1620000 + 20000 * ((sold - 21000) / 1000);
        if (sold < 1000000) return 3200000 + 20000 * ((sold - 100000) / 10000);
        uint256 k = (sold - 1000000) / 20000;
        return 5000000 + (k / 2) * 30000 + (k % 2) * 20000;
    }

    /// @notice Total USDT cost for `shares` more shares at the current tier position.
    /// Prices per share, so a purchase crossing a tier boundary pays each share's own tier price.
    function quote(uint256 shares) public view returns (uint256 cost) {
        require(shares > 0, "zero shares");
        for (uint256 i = 0; i < shares; i++) {
            cost += priceFor(totalSold + i);
        }
    }

    /// @notice Mint `shares` shares for `agentTokenId`. Caller must own that Agent ID.
    /// Requires a prior USDT approval for the full cost.
    function mint(uint256 agentTokenId, uint256 shares) external {
        require(shares > 0, "zero shares");
        require(registry.ownerOf(agentTokenId) == msg.sender, "not agent owner");
        require(sharesByAgentId[agentTokenId] + shares <= MAX_PER_AGENT_ID, "agent cap");
        require(totalSold + shares <= MAX_SHARES, "sold out");
        uint256 cost = quote(shares);
        require(usdt.transferFrom(msg.sender, address(this), cost), "payment failed");
        uint256 toTreasury = (cost * TREASURY_BPS) / 10000;
        if (toTreasury > 0) require(usdt.transfer(treasury, toTreasury), "treasury failed");
        poolReserve += cost - toTreasury;
        sharesByAgentId[agentTokenId] += shares;
        totalSold += shares;
        token.mint(msg.sender, shares * 1 ether);
        emit Minted(msg.sender, agentTokenId, shares, cost);
    }

    function setTreasury(address t) external onlyOwner {
        require(t != address(0), "zero address");
        treasury = t;
        emit TreasuryUpdated(t);
    }

    /// @notice v1 only: withdraw pool reserve. See trust note above.
    function withdrawReserve(address to, uint256 amount) external onlyOwner {
        require(amount <= poolReserve, "exceeds reserve");
        poolReserve -= amount;
        require(usdt.transfer(to, amount), "withdraw failed");
    }
}
