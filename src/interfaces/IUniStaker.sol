// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";
import {IERC20Delegates} from './IERC20Delegates.sol';

interface IUniStaker {
    type DepositIdentifier is uint256;
    /// @notice Metadata associated with a discrete staking deposit.
    /// @param balance The deposit's staked balance.
    /// @param owner The owner of this deposit.
    /// @param delegatee The governance delegate who receives the voting weight for this deposit.
    /// @param beneficiary The address that accrues staking rewards earned by this deposit.

    struct Deposit {
        uint96 balance;
        address owner;
        address delegatee;
        address beneficiary;
    }

    /// @notice Emitted when stake is deposited by a depositor, either to a new deposit or one that already exists.
    event StakeDeposited(address owner, DepositIdentifier indexed depositId, uint256 amount, uint256 depositBalance);

    /// @notice Emitted when a depositor withdraws some portion of stake from a given deposit.
    event StakeWithdrawn(DepositIdentifier indexed depositId, uint256 amount, uint256 depositBalance);

    /// @notice Emitted when a deposit's delegatee is changed.
    event DelegateeAltered(DepositIdentifier indexed depositId, address oldDelegatee, address newDelegatee);

    /// @notice Emitted when a deposit's beneficiary is changed.
    event BeneficiaryAltered(
        DepositIdentifier indexed depositId, address indexed oldBeneficiary, address indexed newBeneficiary
    );

    /// @notice Emitted when a beneficiary claims their earned reward.
    event RewardClaimed(address indexed beneficiary, uint256 amount);

    /// @notice Emitted when this contract is notified of a new reward.
    event RewardNotified(uint256 amount, address notifier);

    /// @notice Emitted when the admin address is set.
    event AdminSet(address indexed oldAdmin, address indexed newAdmin);

    /// @notice Emitted when a reward notifier address is enabled or disabled.
    event RewardNotifierSet(address indexed account, bool isEnabled);

    /// @notice Emitted when a surrogate contract is deployed.
    event SurrogateDeployed(address indexed delegatee, address indexed surrogate);

    /// @notice Thrown when an account attempts a call for which it lacks appropriate permission.
    /// @param reason Human readable code explaining why the call is unauthorized.
    /// @param caller The address that attempted the unauthorized call.
    error UniStaker__Unauthorized(bytes32 reason, address caller);

    /// @notice Thrown if the new rate after a reward notification would be zero.
    error UniStaker__InvalidRewardRate();

    /// @notice Thrown if the following invariant is broken after a new reward: the contract should always have a reward balance sufficient to distribute at the reward rate across the reward duration.
    error UniStaker__InsufficientRewardBalance();

    /// @notice Thrown if a caller attempts to specify address zero for certain designated addresses.
    error UniStaker__InvalidAddress();

    /// @notice Thrown when an onBehalf method is called with a deadline that has expired.
    error UniStaker__ExpiredDeadline();

    /// @notice Thrown if a caller supplies an invalid signature to a method that requires one.
    error UniStaker__InvalidSignature();

    /// @notice Set the admin address.
    /// @param _newAdmin Address of the new admin.
    /// @dev Caller must be the current admin.
    function setAdmin(address _newAdmin) external;

    /// @notice Enables or disables a reward notifier address.
    /// @param _rewardNotifier Address of the reward notifier.
    /// @param _isEnabled `true` to enable the `_rewardNotifier`, or `false` to disable.
    /// @dev Caller must be the current admin.
    function setRewardNotifier(address _rewardNotifier, bool _isEnabled) external;

    /// @notice Timestamp representing the last time at which rewards have been distributed, which is either the current timestamp (because rewards are still actively being streamed) or the time at which the reward duration ended (because all rewards to date have already been streamed).
    /// @return Timestamp representing the last time at which rewards have been distributed.
    function lastTimeRewardDistributed() external view returns (uint256);

    /// @notice Live value of the global reward per token accumulator. It is the sum of the last checkpoint value with the live calculation of the value that has accumulated in the interim. This number should monotonically increase over time as more rewards are distributed.
    /// @return Live value of the global reward per token accumulator.
    function rewardPerTokenAccumulated() external view returns (uint256);

    /// @notice Live value of the unclaimed rewards earned by a given beneficiary account. It is the sum of the last checkpoint value of their unclaimed rewards with the live calculation of the rewards that have accumulated for this account in the interim. This value can only increase, until it is reset to zero once the beneficiary account claims their unearned rewards.
    ///
    /// Note that the contract tracks the unclaimed rewards internally with the scale factor included, in order to avoid the accrual of precision losses as users takes actions that cause rewards to be checkpointed. This external helper method is useful for integrations, and returns the value after it has been scaled down to the reward token's raw decimal amount.
    /// @return Live value of the unclaimed rewards earned by a given beneficiary account.
    function unclaimedReward(address _beneficiary) external view returns (uint256);

    /// @notice Stake tokens to a new deposit. The caller must pre-approve the staking contract to
    /// spend at least the would-be staked amount of the token.
    /// @param _amount The amount of the staking token to stake.
    /// @param _delegatee The address to assign the governance voting weight of the staked tokens.
    /// @return _depositId The unique identifier for this deposit.
    /// @dev The delegatee may not be the zero address. The deposit will be owned by the message sender, and the beneficiary will also be the message sender.
    function stake(uint96 _amount, address _delegatee) external returns (DepositIdentifier);

    /// @notice Method to stake tokens to a new deposit. The caller must pre-approve the staking
    /// contract to spend at least the would-be staked amount of the token.
    /// @param _amount Quantity of the staking token to stake.
    /// @param _delegatee Address to assign the governance voting weight of the staked tokens.
    /// @param _beneficiary Address that will accrue rewards for this stake.
    /// @return _depositId Unique identifier for this deposit.
    /// @dev Neither the delegatee nor the beneficiary may be the zero address. The deposit will be
    /// owned by the message sender.
    function stake(uint96 _amount, address _delegatee, address _beneficiary)
        external
        returns (DepositIdentifier _depositId);

    /// @notice Method to stake tokens to a new deposit. Before the staking operation occurs, a signature is passed to the token contract's permit method to spend the would-be staked amount of the token.
    /// @param _amount Quantity of the staking token to stake.
    /// @param _delegatee Address to assign the governance voting weight of the staked tokens.
    /// @param _beneficiary Address that will accrue rewards for this stake.
    /// @param _deadline The timestamp after which the permit signature should expire.
    /// @param _v ECDSA signature component: Parity of the `y` coordinate of point `R`
    /// @param _r ECDSA signature component: x-coordinate of `R`
    /// @param _s ECDSA signature component: `s` value of the signature
    /// @return _depositId Unique identifier for this deposit.
    /// @dev Neither the delegatee nor the beneficiary may be the zero address. The deposit will be
    /// owned by the message sender.
    function permitAndStake(
        uint96 _amount,
        address _delegatee,
        address _beneficiary,
        uint256 _deadline,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    ) external returns (DepositIdentifier _depositId);

    /// @notice Stake tokens to a new deposit on behalf of a user, using a signature to validate the user's intent. The caller must pre-approve the staking contract to spend at least the would-be staked amount of the token.
    /// @param _amount Quantity of the staking token to stake.
    /// @param _delegatee Address to assign the governance voting weight of the staked tokens.
    /// @param _beneficiary Address that will accrue rewards for this stake.
    /// @param _depositor Address of the user on whose behalf this stake is being made.
    /// @param _deadline The timestamp after which the signature should expire.
    /// @param _signature Signature of the user authorizing this stake.
    /// @return _depositId Unique identifier for this deposit.
    /// @dev Neither the delegatee nor the beneficiary may be the zero address.
    function stakeOnBehalf(
        uint96 _amount,
        address _delegatee,
        address _beneficiary,
        address _depositor,
        uint256 _deadline,
        bytes memory _signature
    ) external returns (DepositIdentifier _depositId);

    /// @notice Add more staking tokens to an existing deposit. A staker should call this method when they have an existing deposit, and wish to stake more while retaining the same delegatee and beneficiary.
    /// @param _depositId Unique identifier of the deposit to which stake will be added.
    /// @param _amount Quantity of stake to be added.
    /// @dev The message sender must be the owner of the deposit.
    function stakeMore(DepositIdentifier _depositId, uint96 _amount) external;

    /// @notice Add more staking tokens to an existing deposit. A staker should call this method when they have an existing deposit, and wish to stake more while retaining the same delegatee and beneficiary. Before the staking operation occurs, a signature is passed to the token contract's permit method to spend the would-be staked amount of the token.
    /// @param _depositId Unique identifier of the deposit to which stake will be added.
    /// @param _amount Quantity of stake to be added.
    /// @param _deadline The timestamp after which the permit signature should expire.
    /// @param _v ECDSA signature component: Parity of the `y` coordinate of point `R`
    /// @param _r ECDSA signature component: x-coordinate of `R`
    /// @param _s ECDSA signature component: `s` value of the signature
    /// @dev The message sender must be the owner of the deposit.
    function permitAndStakeMore(
        DepositIdentifier _depositId,
        uint96 _amount,
        uint256 _deadline,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    ) external;

    /// @notice Add more staking tokens to an existing deposit on behalf of a user, using a signature to validate the user's intent. A staker should call this method when they have an existing deposit, and wish to stake more while retaining the same delegatee and beneficiary.
    /// @param _depositId Unique identifier of the deposit to which stake will be added.
    /// @param _amount Quantity of stake to be added.
    /// @param _depositor Address of the user on whose behalf this stake is being made.
    /// @param _deadline The timestamp after which the signature should expire.
    /// @param _signature Signature of the user authorizing this stake.
    function stakeMoreOnBehalf(
        DepositIdentifier _depositId,
        uint96 _amount,
        address _depositor,
        uint256 _deadline,
        bytes memory _signature
    ) external;

    /// @notice For an existing deposit, change the address to which governance voting power is assigned.
    /// @param _depositId Unique identifier of the deposit which will have its delegatee altered.
    /// @param _newDelegatee Address of the new governance delegate.
    /// @dev The new delegatee may not be the zero address. The message sender must be the owner of the deposit.
    function alterDelegatee(DepositIdentifier _depositId, address _newDelegatee) external;

    /// @notice For an existing deposit, change the address to which governance voting power is assigned on behalf of a user, using a signature to validate the user's intent.
    /// @param _depositId Unique identifier of the deposit which will have its delegatee altered.
    /// @param _newDelegatee Address of the new governance delegate.
    /// @param _depositor Address of the user on whose behalf this stake is being made.
    /// @param _deadline The timestamp after which the signature should expire.
    /// @param _signature Signature of the user authorizing this stake.
    /// @dev The new delegatee may not be the zero address.
    function alterDelegateeOnBehalf(
        DepositIdentifier _depositId,
        address _newDelegatee,
        address _depositor,
        uint256 _deadline,
        bytes memory _signature
    ) external;

    /// @notice For an existing deposit, change the beneficiary to which staking rewards are accruing.
    /// @param _depositId Unique identifier of the deposit which will have its beneficiary altered.
    /// @param _newBeneficiary Address of the new rewards beneficiary.
    /// @dev The new beneficiary may not be the zero address. The message sender must be the owner of the deposit.
    function alterBeneficiary(DepositIdentifier _depositId, address _newBeneficiary) external;

    /// @notice For an existing deposit, change the beneficiary to which staking rewards are accruing on behalf of a user, using a signature to validate the user's intent.
    /// @param _depositId Unique identifier of the deposit which will have its beneficiary altered.
    /// @param _newBeneficiary Address of the new rewards beneficiary.
    /// @param _depositor Address of the user on whose behalf this stake is being made.
    /// @param _deadline The timestamp after which the signature should expire.
    /// @param _signature Signature of the user authorizing this stake.
    /// @dev The new beneficiary may not be the zero address.
    function alterBeneficiaryOnBehalf(
        DepositIdentifier _depositId,
        address _newBeneficiary,
        address _depositor,
        uint256 _deadline,
        bytes memory _signature
    ) external;

    /// @notice Withdraw staked tokens from an existing deposit.
    /// @param _depositId Unique identifier of the deposit from which stake will be withdrawn.
    /// @param _amount Quantity of staked token to withdraw.
    /// @dev The message sender must be the owner of the deposit. Stake is withdrawn to the message sender's account.
    function withdraw(DepositIdentifier _depositId, uint96 _amount) external;

    /// @notice Withdraw staked tokens from an existing deposit on behalf of a user, using a signature to validate the user's intent.
    /// @param _depositId Unique identifier of the deposit from which stake will be withdrawn.
    /// @param _amount Quantity of staked token to withdraw.
    /// @param _depositor Address of the user on whose behalf this stake is being made.
    /// @param _deadline The timestamp after which the signature should expire.
    /// @param _signature Signature of the user authorizing this stake.
    /// @dev Stake is withdrawn to the deposit owner's account.
    function withdrawOnBehalf(
        DepositIdentifier _depositId,
        uint96 _amount,
        address _depositor,
        uint256 _deadline,
        bytes memory _signature
    ) external;

    /// @notice Claim reward tokens the message sender has earned as a stake beneficiary. Tokens are sent to the message sender.
    /// @return Amount of reward tokens claimed.
    function claimReward() external returns (uint256);

    /// @notice Claim earned reward tokens for a beneficiary, using a signature to validate the beneficiary's intent. Tokens are sent to the beneficiary.
    /// @param _beneficiary Address of the beneficiary who will receive the reward.
    /// @param _deadline The timestamp after which the signature should expire.
    /// @param _signature Signature of the beneficiary authorizing this reward claim.
    /// @return Amount of reward tokens claimed.
    function claimRewardOnBehalf(address _beneficiary, uint256 _deadline, bytes memory _signature)
        external
        returns (uint256);

    /// @notice Called by an authorized rewards notifier to alert the staking contract that a new reward has been transferred to it. It is assumed that the reward has already been transferred to this staking contract before the rewards notifier calls this method.
    /// @param _amount Quantity of reward tokens the staking contract is being notified of.
    /// @dev It is critical that only well behaved contracts are approved by the admin to call this method, for two reasons.
    ///
    /// 1. A misbehaving contract could grief stakers by frequently notifying this contract of tiny rewards, thereby continuously stretching out the time duration over which real rewards are distributed. It is required that reward notifiers supply reasonable rewards at reasonable intervals.
    ///
    /// 2. A misbehaving contract could falsely notify this contract of rewards that were not actually distributed, creating a shortfall for those claiming their rewards after others. It is required that a notifier contract always transfers the `_amount` to this contract before calling this method.
    function notifyRewardAmount(uint256 _amount) external;

    /// @notice ERC20 token in which rewards are denominated and distributed.
    function REWARD_TOKEN() external view returns (IERC20);

    /// @notice Delegable governance token which users stake to earn rewards.
    function STAKE_TOKEN() external view returns (IERC20Delegates);

    /// @notice Length of time over which rewards sent to this contract are distributed to stakers.
    function REWARD_DURATION() external view returns (uint256);

    /// @notice Scale factor used in reward calculation math to reduce rounding errors caused by truncation during division.
    function SCALE_FACTOR() external view returns (uint256);

    /// @dev Unique identifier that will be used for the next deposit.
    function nextDepositId() external view returns (DepositIdentifier);

    /// @notice Permissioned actor that can enable/disable `rewardNotifier` addresses.
    function rewardNotifier() external view returns (address);

    /// @notice Global amount currently staked across all deposits.
    function totalStaked() external view returns (uint256);

    /// @notice Tracks the total staked by a depositor across all unique deposits.
    function depositorTotalStaked(address) external view returns (uint256);

    /// @notice Tracks the total stake actively earning rewards for a given beneficiary account.
    function earningPower(address) external view returns (uint256);

    /// @notice Stores the metadata associated with a given deposit.
    function deposits(DepositIdentifier) external view returns (Deposit memory);

    /// @notice Maps the account of each governance delegate with the surrogate contract which holds the staked tokens from deposits which assign voting weight to said delegate.
    function surrogates(address) external view returns (address);

    /// @notice Time at which rewards distribution will complete if there are no new rewards.
    function rewardEndTime() external view returns (uint256);

    /// @notice Last time at which the global rewards accumulator was updated.
    function lastCheckpointTime() external view returns (uint256);

    /// @notice Global rate at which rewards are currently being distributed to stakers, denominated in scaled reward tokens per second, using the SCALE_FACTOR.
    function scaledRewardRate() external view returns (uint256);

    /// @notice Checkpoint value of the global reward per token accumulator.
    function rewardPerTokenAccumulatedCheckpoint() external view returns (uint256);

    /// @notice Checkpoint of the reward per token accumulator on a per account basis. It represents the value of the global accumulator at the last time a given beneficiary's rewards were calculated and stored. The difference between the global value and this value can be used to calculate the interim rewards earned by given account.
    function beneficiaryRewardPerTokenCheckpoint(address) external view returns (uint256);

    /// @notice Checkpoint of the unclaimed rewards earned by a given beneficiary with the scale factor included. This value is stored any time an action is taken that specifically impacts the rate at which rewards are earned by a given beneficiary account. Total unclaimed rewards for an account are thus this value plus all rewards earned after this checkpoint was taken. This value is reset to zero when a beneficiary account claims their earned rewards.
    function beneficiaryUnclaimedRewardsCheckpoint(address) external view returns (uint256);

    /// @notice Maps addresses to whether they are authorized to call `notifyRewardAmount`.
    function isRewardNotifier(address) external view returns (bool);

    /// @notice Type hash used when encoding data for `stakeOnBehalf` calls.
    function STAKE_TYPEHASH() external view returns (bytes32);
    /// @notice Type hash used when encoding data for `stakeMoreOnBehalf` calls.
    function STAKE_MORE_TYPEHASH() external view returns (bytes32);
    /// @notice Type hash used when encoding data for `alterDelegateeOnBehalf` calls.
    function ALTER_DELEGATEE_TYPEHASH() external view returns (bytes32);
    /// @notice Type hash used when encoding data for `alterBeneficiaryOnBehalf` calls.
    function ALTER_BENEFICIARY_TYPEHASH() external view returns (bytes32);
    /// @notice Type hash used when encoding data for `withdrawOnBehalf` calls.
    function WITHDRAW_TYPEHASH() external view returns (bytes32);
    /// @notice Type hash used when encoding data for `claimRewardOnBehalf` calls.
    function CLAIM_REWARD_TYPEHASH() external view returns (bytes32);
}