# Submission Summary

## Security Issues Found & Fixed

The original `claimReward` function had multiple security issues.

First, there was no validation on the `amount` parameter, allowing callers to request arbitrarily large rewards. This was fixed by introducing a `MAX_REWARD_PER_BATTLE` constant and validating the amount using require statements.

Second, the `claimedRewards` mapping originally tracked only whether a reward was claimed but not who claimed it. This could allow unintended blocking of legitimate claims. The mapping was updated to store the address of the claimant and ensure that rewards cannot be claimed more than once.

Third, there was no restriction ensuring that only the actual battle winner could claim the reward. This was fixed by implementing a battle winner mapping and validating that msg.sender matches the registered winner before allowing the claim.

Additionally, checks were added to prevent zero-value reward claims, ensure the owner's balance is sufficient before transfer, and enforce a maximum total reward pool limit to prevent draining contract funds.

## Battle Verification Approach

I implemented an Authorized Verifier approach where a trusted verifier (contract owner) registers the battle winner using setBattleWinner before a reward can be claimed.

This approach was chosen because it is simple, transparent, and aligns with backend-controlled game logic. The verifier acts as the trusted authority responsible for confirming valid winners.

## Tradeoffs & Design Decisions

Using a centralized verifier introduces a trust assumption, meaning the verifier must be secure. However, this approach keeps the system simple and easy to audit.

For production systems, this role could be replaced with:

- multisig verification
- backend signature validation
- oracle-based result verification

Additional validation checks slightly increase gas usage but significantly improve contract safety and reliability.