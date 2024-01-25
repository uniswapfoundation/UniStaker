# Invariant Suite

The invariant suite is a collection of tests that ensure certain properties of the system are always true.

## Invariants under test

- [ ] the earned fees should equal the percentage of durations that have passed on the rewards
- [ ] Withdrawals for individual depositors + stake should equal the total staked throughout the tests
- [ ] The sum of all of the notified rewards should equal the rewards balance in the staking contract plus all claimed rewards

## Invariant Handler

The handler contract specifies the actions that should be taken in the black box of an invariant run. Included in the handler contract are actions such as:

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
- alterDelegatee
- alterBeneficiary
- permitAndStake
- enable rewards notifier
- notifyRewardAmount
- all of the `onBehalf` methods
- multicall

### Invalid user actions

- Staking without sufficient EC20 approval
- Stake more on a deposit that does not belong to you
- State more on a deposit that does not exist
- Alter beneficiary and alter delegatee on a deposit that is not yours or does not exist
- withdraw on deposit that's not yours
- call notifyRewardsAmount if you are not rewards notifier, or insufficient/incorrect reward balance
- setAdmin and setRewardNotifier without being the admin
- Invalid signature on the `onBehalf` methods
- multicall

### Weird user actions

These are actions that are outside the normal use of the system. They are used to test the system's behavior under abnormal conditions.

- transfer in arbitrary amount of STAKE_TOKEN
- transfer in arbitrary amount of REWARD_TOKEN
- transfer direct to surrogate
- reentrancy attempts
- SELFDESTRUCT to this contract
- flash loan?
- User uses the staking contract as the from address in a `transferFrom`
- A non-beneficiary calls claim reward
- withdraw with zero amount
- multicall

### Utility actions

- `warpAhead`: warp the block timestamp ahead by a specified number of seconds.
