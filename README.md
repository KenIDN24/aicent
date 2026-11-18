# Aicent

**Agent ID-gated tiered share mint on BNB Chain.**

Aicent is a live dApp built around Binance **Agent ID**. Its mint contract
(`AicentMint`) verifies on-chain — through the Agent ID registry's `ownerOf` —
that the caller owns the Agent ID they mint with. Wallets without an Agent ID
cannot participate at all.

- Purchases are accounted **per Agent ID**, not per wallet, with a hard cap of
  **10 shares per Agent ID** (`MAX_PER_AGENT_ID`) — distribution stays fair and
  Sybil-resistant even if one person controls many wallets.
- Shares are priced in USDT on a rising tier curve (starting at 0.50 USDT);
  80% of proceeds are held as pool reserve, 20% go to the treasury.
- Contracts are deployed on BNB Chain mainnet and verified on BscScan.

## Live product

https://kenidn24.github.io/aicent/

## Contracts (BNB Chain, chain 56)

| Contract | Address |
| --- | --- |
| AicentMint | `0xd467435dac6fb658E32aA7dC1B25dE83711e45bB` |
| Aicent (token) | `0xc81Ac0466Ddb97f6ae701CB7a607146e084c212A` |
| Agent ID registry | `0x60B9262456dE011F7d15a54CdD8c48bAaa8B022F` |

Source code: [`contracts/`](contracts/)
