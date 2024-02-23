# Invariant Suite

The invariant suite is a collection of tests designed to build confidence around certain properties of the system expected to be true.

## Invariants under test

- The total staked balance should equal the sum of all individual depositors' balances
- The sum of beneficiary earning power should equal the total staked balance
- The sum of all surrogate balance should equal the total staked balance
- Cumulative deposits minus withdrawals should equal the total staked balance
- The sum of all notified rewards should be greater or equal to all claimed rewards plus the rewards balance in the staking contract (TODO: not strictly equal because of stray transfers in, which are not yet implemented in handler)
- Sum of unclaimed reward across all beneficiaries should be less than or equal to total rewards
- `rewardPerTokenAccumulatedCheckpoint` should be greater or equal to the last `rewardPerTokenAccumulatedCheckpoint` value

## Invariant Handler

The handler contract specifies the actions that should be taken in the black box of an invariant run. Here is a list of implemented actions the handler contract can take, as well as ideas for further actions.

### Valid user actions

These actions are typical user actions that can be taken on the system. They are used to test the system's behavior under normal conditions.

- [x] stake: a user deposits some amount of STAKE_TOKEN, specifying a delegatee and optionally a beneficiary.
  - Action taken by: any user
- [x] stakeMore: a user increments the balance on an existing deposit that she owns.
  - Action taken by: existing depositors
- [x] withdraw: a user withdraws some balance from a deposit that she owns.
  - Action taken by: existing depositors
- [x] claimReward: A beneficiary claims the reward that is due to her.
  - Action taken by: existing beneficiaries
- [ ] alterDelegatee
- [ ] alterBeneficiary
- [ ] permitAndStake
- [x] enable rewards notifier
- [x] notifyRewardAmount
- [ ] all of the `onBehalf` methods
- [ ] multicall

### Invalid user actions

- [ ] Staking without sufficient ERC20 approval
- [ ] Stake more on a deposit that does not belong to you
- [ ] State more on a deposit that does not exist
- [ ] Alter beneficiary and alter delegatee on a deposit that is not yours or does not exist
- [ ] withdraw on deposit that's not yours
- [ ] call notifyRewardsAmount if you are not rewards notifier, or insufficient/incorrect reward balance
- [ ] setAdmin and setRewardNotifier without being the admin
- [ ] Invalid signature on the `onBehalf` methods
- [ ] multicall

### Weird user actions

These are actions that are outside the normal use of the system. They are used to test the system's behavior under abnormal conditions.

- [ ] directly transfer in some amount of STAKE_TOKEN to UniStaker
- [ ] directly transfer some amount of REWARD_TOKEN to UniStaker
- [ ] transfer stake directly to surrogate
- [ ] reentrancy attempts
- [ ] SELFDESTRUCT to this contract
- [ ] flash loan?
- [ ] User uses the staking contract as the from address in a `transferFrom`
- [ ] A non-beneficiary calls claim reward
- [x] withdraw with zero amount
- [ ] multicall

### Utility actions

- [x] `warpAhead`: warp the block timestamp ahead by a specified number of seconds.
