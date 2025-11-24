# Staking Reward Contract
This smart contract allows users to stake a specific fungible token and earn
periodic reward tokens based on the time their tokens remain staked.

## Features
- Stake and unstake tokens
- Accumulate claimable rewards over time
- Owner can update the reward emission rate
- Fully on-chain and transparent record of rewards

## How It Works
Users deposit (stake) tokens into the contract. While tokens remain staked,
rewards are continuously calculated based on:
- Amount staked
- Reward rate set by the contract owner
- Staking duration

Users can claim their rewards at any time or automatically when unstaking.

## Usage
1. Stake tokens: lock tokens into the contract.
2. Wait and accumulate rewards over time.
3. Claim or unstake to receive earned rewards.

## Disclaimer
This contract example is for learning and demonstration only. Please review and
test thoroughly before using in any real project.
