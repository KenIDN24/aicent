// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/// @title Aicent (AICENT)
/// @notice ERC-20 for the aicent share mint. Only the mint contract can mint.
/// 1 share = 1 AICENT (18 decimals), minted to the buyer at mint time (v1).
contract Aicent is ERC20, Ownable {
    address public minter;

    /// @notice Owner is passed explicitly (not msg.sender) so the contract can
    /// be deployed through a factory (e.g. the deterministic deployment proxy)
    /// while the user's wallet still becomes the owner.
    constructor(address owner_) ERC20("Aicent", "AICENT") Ownable(owner_) {
        require(owner_ != address(0), "zero owner");
    }

    /// @notice Set the mint contract once. Cannot be changed afterwards.
    function setMinter(address m) external onlyOwner {
        require(minter == address(0), "minter set");
        require(m != address(0), "zero address");
        minter = m;
    }

    function mint(address to, uint256 amount) external {
        require(msg.sender == minter, "not minter");
        _mint(to, amount);
    }
}
