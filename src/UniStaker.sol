// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.23;

import {DelegationSurrogate} from "src/DelegationSurrogate.sol";
import {INotifiableRewardReceiver} from "src/interfaces/INotifiableRewardReceiver.sol";
import {IERC20Delegates} from "src/interfaces/IERC20Delegates.sol";
import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "openzeppelin/utils/ReentrancyGuard.sol";
import {Multicall} from "openzeppelin/utils/Multicall.sol";

/// @title UniStaker
/// @author ScopeLift
/// @notice This contract manages the distribution of rewards to stakers. Rewards are denominated
/// in an ERC20 token and sent to the contract by authorized reward notifiers. To stake means to
/// deposit a designated, delegable ERC20 governance token and leave it over a period of time.
/// The contract allows stakers to delegate the voting power of the tokens they stake to any
/// governance delegatee on a per deposit basis. The contract also allows stakers to designate the
/// beneficiary address that earns rewards for the associated deposit.
///
/// The staking mechanism of this contract is directly inspired by the Synthetix StakingRewards.sol
/// implementation. The core mechanic involves the streaming of rewards over a designated period
/// of time. Each staker earns rewards proportional to their share of the total stake, and each
/// staker earns only while their tokens are staked. Stakers may add or withdraw their stake at any
/// point. Beneficiaries can claim the rewards they've earned at any point. When a new reward is
/// received, the reward duration restarts, and the rate at which rewards are streamed is updated
/// to include the newly received rewards along with any remaining rewards that have finished
/// streaming since the last time a reward was received.
contract UniStaker is INotifiableRewardReceiver, ReentrancyGuard, Multicall {
  type DepositIdentifier is uint256;

  /// @notice Emitted when a depositor initially deposits a stake or deposits additional stake for
  /// an existing deposit.
  event StakeDeposited(DepositIdentifier indexed depositId, uint256 amount, uint256 depositBalance);

  /// @notice Emitted when a depositor withdraws some portion of  stake from a given deposit.
  event StakeWithdrawn(DepositIdentifier indexed depositId, uint256 amount, uint256 depositBalance);

  /// @notice Emitted when a deposit's delegatee is changed.
  event DelegateeAltered(
    DepositIdentifier indexed depositId, address oldDelegatee, address newDelegatee
  );

  /// @notice Emitted when a deposit's beneficiary is changed.
  event BeneficiaryAltered(
    DepositIdentifier indexed depositId,
    address indexed oldBeneficiary,
    address indexed newBeneficiary
  );

  /// @notice Emitted when a beneficiary claims their earned reward.
  event RewardClaimed(address indexed beneficiary, uint256 amount);

  /// @notice Emitted when this contract is notified of a new reward.
  event RewardNotified(uint256 amount, address caller);

  /// @notice Emitted when the admin address is set.
  event AdminSet(address indexed oldAdmin, address indexed newAdmin);

  /// @notice Emitted when a rewards notifier address is enabled or disabled.
  event RewardsNotifierSet(address indexed account, bool isEnabled);

  /// @notice Emitted when a surrogate contract is deployed.
  event SurrogateDeployed(address indexed delegatee, address indexed surrogate);

  /// @notice Thrown when an account attempts a call for which it lacks appropriate permission.
  /// @param reason Human readable code explaining why the call is unauthorized.
  /// @param caller The address that attempted the unauthorized call.
  error UniStaker__Unauthorized(bytes32 reason, address caller);

  /// @notice Thrown if the new rate after a reward notification would be zero.
  error UniStaker__InvalidRewardRate();

  /// @notice Thrown if the following invariant is broken after a new reward: the contract should
  /// always have a reward balance sufficient to distribute at the reward rate across the reward
  /// duration.
  error UniStaker__InsufficientRewardBalance();

  /// @notice Thrown if a caller attempts to specify address zero for certain designated addresses.
  error UniStaker__InvalidAddress();

  /// @notice Metadata associated with a discrete staking deposit.
  /// @param balance The deposit's staked balance.
  /// @param owner The owner of this deposit.
  /// @param delegatee The governance delegate who receives the voting weight for this deposit.
  /// @param beneficiary The address that accrues staking rewards earned by this deposit.
  struct Deposit {
    uint256 balance;
    address owner;
    address delegatee;
    address beneficiary;
  }

  /// @notice ERC20 token in which rewards are denominated and distributed.
  IERC20 public immutable REWARDS_TOKEN;

  /// @notice Delegable governance token which users stake to earn rewards.
  IERC20Delegates public immutable STAKE_TOKEN;

  /// @notice Length of time over which rewards sent to this contract are distributed to stakers.
  uint256 public constant REWARD_DURATION = 7 days;

  /// @dev Internal scale factor used in reward calculation math to reduce rounding errors caused
  /// by truncation during division.
  uint256 private constant SCALE_FACTOR = 1e24;

  /// @dev Unique identifier that will be used for the next deposit.
  DepositIdentifier private nextDepositId;

  /// @notice Permissioned actor that can enable/disable `rewardsNotifier` addresses.
  address public admin;

  /// @notice Global amount currently staked across all user deposits.
  uint256 public totalSupply;

  /// @notice Tracks the total staked by a depositor across all unique deposits.
  mapping(address depositor => uint256 amount) public totalDeposits;

  /// @notice Tracks the total stake actively earning rewards for a given beneficiary account.
  mapping(address beneficiary => uint256 amount) public earningPower;

  /// @notice Stores the metadata associated with a given deposit.
  mapping(DepositIdentifier depositId => Deposit deposit) public deposits;

  /// @notice Maps the account of each governance delegate with the surrogate contract which holds
  /// the staked tokens from deposits which assign voting weight to said delegate.
  mapping(address delegatee => DelegationSurrogate surrogate) public surrogates;

  /// @notice Time at which rewards distribution will complete if there are no new rewards.
  uint256 public finishAt;

  /// @notice Last time at which the global rewards accumulator was updated.
  uint256 public updatedAt;

  /// @notice Global rate at which rewards are currently being distributed to stakers,
  /// denominated in reward tokens per second.
  uint256 public rewardRate;

  /// @notice Snapshot value of the global rewards per token accumulator.
  uint256 public rewardPerTokenStored;

  /// @notice Snapshot of the reward per token accumulator on a per account basis. It represents
  /// the value of the global accumulator at the last time a given account's rewards were
  /// calculated and stored. The difference between the global value and this value can be
  /// used to calculate the interim rewards earned by given account.
  mapping(address account => uint256) public userRewardPerTokenPaid;

  /// @notice Snapshot of the unclaimed rewards earned by a given account. This value is stored any
  /// time an action is taken that impacts the rate at which rewards are earned by a given
  /// beneficiary account. Total unclaimed rewards for an account are thus this value plus all
  /// rewards earned after this snapshot was taken. This value is reset to zero when a beneficiary
  /// account claims their earned rewards.
  mapping(address account => uint256 amount) public rewards;

  /// @notice Maps addresses to whether they are authorized to call `notifyRewardsAmount`.
  mapping(address rewardsNotifier => bool) public isRewardsNotifier;

  /// @param _rewardsToken ERC20 token in which rewards will be denominated.
  /// @param _stakeToken Delegable governance token which users will stake to earn rewards.
  /// @param _admin Address which will have permission to manage rewardsNotifiers.
  constructor(IERC20 _rewardsToken, IERC20Delegates _stakeToken, address _admin) {
    REWARDS_TOKEN = _rewardsToken;
    STAKE_TOKEN = _stakeToken;
    _setAdmin(_admin);
  }

  /// @notice Set the admin address.
  /// @param _newAdmin Address of the new admin.
  /// @dev Caller must be the current admin.
  function setAdmin(address _newAdmin) external {
    _revertIfNotAdmin();
    _setAdmin(_newAdmin);
  }

  /// @notice Enables or disables a rewards notifier address.
  /// @param _rewardsNotifier Address of the rewards notifier.
  /// @param _isEnabled `true` to enable the `_rewardsNotifier`, or `false` to disable.
  /// @dev Caller must be the current admin.
  function setRewardsNotifier(address _rewardsNotifier, bool _isEnabled) external {
    _revertIfNotAdmin();
    isRewardsNotifier[_rewardsNotifier] = _isEnabled;
    emit RewardsNotifierSet(_rewardsNotifier, _isEnabled);
  }

  /// @notice Timestamp representing the last time at which rewards have been distributed, which is
  /// either the current timestamp (because rewards are still actively being streamed) or the time
  /// at which the reward duration ended (because all rewards to date have already been streamed).
  function lastTimeRewardApplicable() public view returns (uint256) {
    if (finishAt <= block.timestamp) return finishAt;
    else return block.timestamp;
  }

  /// @notice Live value of the global reward per token accumulator. It is the sum of the last
  /// snapshot value with the live calculation of the value that has accumulated in the interim.
  /// This number should monotonically increase over time as more rewards are distributed.
  function rewardPerToken() public view returns (uint256) {
    if (totalSupply == 0) return rewardPerTokenStored;

    return rewardPerTokenStored
      + (rewardRate * (lastTimeRewardApplicable() - updatedAt) * SCALE_FACTOR) / totalSupply;
  }

  /// @notice Live value of the unclaimed rewards earned by a given beneficiary account. It is the
  /// sum of the last snapshot value of their unclaimed rewards with the live calculation of the
  /// rewards that have accumulated for this account in the interim. This value can only increase,
  /// until it is reset to zero once the beneficiary account claims their unearned rewards.
  function earned(address _beneficiary) public view returns (uint256) {
    return rewards[_beneficiary]
      + (earningPower[_beneficiary] * (rewardPerToken() - userRewardPerTokenPaid[_beneficiary]))
        / SCALE_FACTOR;
  }

  /// @notice Stake tokens to a new deposit. The caller must pre-approve the staking contract to
  /// spend at least the would-be staked amount of the token.
  /// @param _amount The amount of the staking token to stake.
  /// @param _delegatee The address to assign the governance voting weight of the staked tokens.
  /// @return _depositId The unique identifier for this deposit.
  /// @dev The delegatee may not be the zero address. The deposit will be owned by the message
  /// sender, and the beneficiary will also be the message sender.
  function stake(uint256 _amount, address _delegatee)
    external
    nonReentrant
    returns (DepositIdentifier _depositId)
  {
    _depositId = _stake(_amount, _delegatee, msg.sender);
  }

  /// @notice Method to stake tokens to a new deposit. The caller must pre-approve the staking
  /// contract to spend at least the would-be staked amount of the token.
  /// @param _amount Quantity of the staking token to stake.
  /// @param _delegatee Address to assign the governance voting weight of the staked tokens.
  /// @param _beneficiary Address that will accrue rewards for this stake.
  /// @return _depositId Unique identifier for this deposit.
  /// @dev Neither the delegatee nor the beneficiary may be the zero address. The deposit will be
  /// owned by the message sender.
  function stake(uint256 _amount, address _delegatee, address _beneficiary)
    external
    nonReentrant
    returns (DepositIdentifier _depositId)
  {
    _depositId = _stake(_amount, _delegatee, _beneficiary);
  }

  /// @notice Add more staking tokens to an existing deposit. A staker should call this method when
  /// they have an existing deposit, and wish to stake more while retaining the same delegatee and
  /// beneficiary.
  /// @param _depositId Unique identifier of the deposit to which stake will be added.
  /// @param _amount Quantity of stake to be added.
  /// @dev The message sender must be the owner of the deposit.
  function stakeMore(DepositIdentifier _depositId, uint256 _amount) external nonReentrant {
    Deposit storage deposit = deposits[_depositId];
    _revertIfNotDepositOwner(deposit);

    _updateReward(deposit.beneficiary);

    DelegationSurrogate _surrogate = surrogates[deposit.delegatee];
    _stakeTokenSafeTransferFrom(msg.sender, address(_surrogate), _amount);

    totalSupply += _amount;
    totalDeposits[msg.sender] += _amount;
    earningPower[deposit.beneficiary] += _amount;
    deposit.balance += _amount;
    emit StakeDeposited(_depositId, _amount, deposit.balance);
  }

  /// @notice For an existing deposit, change the address to which governance voting power is
  /// assigned.
  /// @param _depositId Unique identifier of the deposit which will have its delegatee altered.
  /// @param _newDelegatee Address of the new governance delegate.
  /// @dev The new delegatee may not be the zero address. The message sender must be the owner of
  /// the deposit.
  function alterDelegatee(DepositIdentifier _depositId, address _newDelegatee)
    external
    nonReentrant
  {
    _revertIfAddressZero(_newDelegatee);
    Deposit storage deposit = deposits[_depositId];
    _revertIfNotDepositOwner(deposit);

    DelegationSurrogate _oldSurrogate = surrogates[deposit.delegatee];
    emit DelegateeAltered(_depositId, deposit.delegatee, _newDelegatee);
    deposit.delegatee = _newDelegatee;
    DelegationSurrogate _newSurrogate = _fetchOrDeploySurrogate(_newDelegatee);
    _stakeTokenSafeTransferFrom(address(_oldSurrogate), address(_newSurrogate), deposit.balance);
  }

  /// @notice For an existing deposit, change the beneficiary to which staking rewards are
  /// accruing.
  /// @param _depositId Unique identifier of the deposit which will have its beneficiary altered.
  /// @param _newBeneficiary Address of the new rewards beneficiary.
  /// @dev The new beneficiary may not be the zero address. The message sender must be the owner of
  /// the deposit.
  function alterBeneficiary(DepositIdentifier _depositId, address _newBeneficiary)
    external
    nonReentrant
  {
    _revertIfAddressZero(_newBeneficiary);
    Deposit storage deposit = deposits[_depositId];
    _revertIfNotDepositOwner(deposit);

    _updateReward(deposit.beneficiary);
    earningPower[deposit.beneficiary] -= deposit.balance;

    _updateReward(_newBeneficiary);
    emit BeneficiaryAltered(_depositId, deposit.beneficiary, _newBeneficiary);
    deposit.beneficiary = _newBeneficiary;
    earningPower[_newBeneficiary] += deposit.balance;
  }

  /// @notice Withdraw staked tokens from an existing deposit.
  /// @param _depositId Unique identifier of the deposit from which stake will be withdrawn.
  /// @param _amount Quantity of staked token to withdraw.
  /// @dev The message sender must be the owner of the deposit. Stake is withdrawn to the message
  /// sender's account.
  function withdraw(DepositIdentifier _depositId, uint256 _amount) external nonReentrant {
    Deposit storage deposit = deposits[_depositId];
    _revertIfNotDepositOwner(deposit);

    _updateReward(deposit.beneficiary);

    deposit.balance -= _amount; // overflow prevents withdrawing more than balance
    totalSupply -= _amount;
    totalDeposits[msg.sender] -= _amount;
    earningPower[deposit.beneficiary] -= _amount;
    _stakeTokenSafeTransferFrom(address(surrogates[deposit.delegatee]), deposit.owner, _amount);
    emit StakeWithdrawn(_depositId, _amount, deposit.balance);
  }

  /// @notice Claim reward tokens the message sender has earned as a stake beneficiary. Tokens are
  /// sent to the message sender.
  function claimReward() external nonReentrant {
    _updateReward(msg.sender);

    uint256 _rewards = rewards[msg.sender];
    if (_rewards == 0) return;
    rewards[msg.sender] = 0;
    emit RewardClaimed(msg.sender, _rewards);

    SafeERC20.safeTransfer(REWARDS_TOKEN, msg.sender, _rewards);
  }

  /// @notice Called by an authorized rewards notifier to alert the staking contract that a new
  /// reward has been transferred to it. Note the reward must already have been transferred to this
  /// staking contract before the rewards notifier calls this method.
  /// @param _amount Quantity of reward tokens the staking contract is being notified of.
  function notifyRewardsAmount(uint256 _amount) external {
    if (!isRewardsNotifier[msg.sender]) revert UniStaker__Unauthorized("not notifier", msg.sender);
    // TODO: It looks like the only thing we actually need to do here is update the
    // rewardPerTokenStored value. Can we save gas by doing only that?
    _updateReward(address(0));

    if (block.timestamp >= finishAt) {
      // TODO: Can we move the scale factor into the rewardRate? This should reduce rounding errors
      // introduced here when truncating on this division.
      rewardRate = _amount / REWARD_DURATION;
    } else {
      uint256 remainingRewards = rewardRate * (finishAt - block.timestamp);
      rewardRate = (remainingRewards + _amount) / REWARD_DURATION;
    }

    if (rewardRate == 0) revert UniStaker__InvalidRewardRate();
    if ((rewardRate * REWARD_DURATION) > REWARDS_TOKEN.balanceOf(address(this))) {
      revert UniStaker__InsufficientRewardBalance();
    }

    finishAt = block.timestamp + REWARD_DURATION;
    updatedAt = block.timestamp;
    emit RewardNotified(_amount, msg.sender);
  }

  /// @notice Internal method which finds the existing surrogate contract—or deploys a new one if
  /// none exists—for a given delegatee.
  /// @param _delegatee Account for which a surrogate is sought.
  /// @return _surrogate The address of the surrogate contract for the delegatee.
  function _fetchOrDeploySurrogate(address _delegatee)
    internal
    returns (DelegationSurrogate _surrogate)
  {
    _surrogate = surrogates[_delegatee];

    if (address(_surrogate) == address(0)) {
      _surrogate = new DelegationSurrogate(STAKE_TOKEN, _delegatee);
      surrogates[_delegatee] = _surrogate;
      emit SurrogateDeployed(_delegatee, address(_surrogate));
    }
  }

  /// @notice Internal convenience method which calls the `transferFrom` method on the stake token
  /// contract and reverts on failure.
  /// @param _from Source account from which stake token is to be transferred.
  /// @param _to Destination account of the stake token which is to be transferred.
  /// @param _value Quantity of stake token which is to be transferred.
  function _stakeTokenSafeTransferFrom(address _from, address _to, uint256 _value) internal {
    SafeERC20.safeTransferFrom(IERC20(address(STAKE_TOKEN)), _from, _to, _value);
  }

  /// @notice Internal method which generates and returns a unique, previously unused deposit
  /// identifier.
  /// @return _depositId Previously unused deposit identifier.
  function _useDepositId() internal returns (DepositIdentifier _depositId) {
    _depositId = nextDepositId;
    nextDepositId = DepositIdentifier.wrap(DepositIdentifier.unwrap(_depositId) + 1);
  }

  /// @notice Internal convenience methods which performs the staking operations.
  /// @dev See public stake methods for additional documentation.
  function _stake(uint256 _amount, address _delegatee, address _beneficiary)
    internal
    returns (DepositIdentifier _depositId)
  {
    _revertIfAddressZero(_delegatee);
    _revertIfAddressZero(_beneficiary);

    _updateReward(_beneficiary);

    DelegationSurrogate _surrogate = _fetchOrDeploySurrogate(_delegatee);
    _stakeTokenSafeTransferFrom(msg.sender, address(_surrogate), _amount);
    _depositId = _useDepositId();

    totalSupply += _amount;
    totalDeposits[msg.sender] += _amount;
    earningPower[_beneficiary] += _amount;
    deposits[_depositId] = Deposit({
      balance: _amount,
      owner: msg.sender,
      delegatee: _delegatee,
      beneficiary: _beneficiary
    });
    emit StakeDeposited(_depositId, _amount, _amount);
    emit BeneficiaryAltered(_depositId, address(0), _beneficiary);
    emit DelegateeAltered(_depositId, address(0), _delegatee);
  }

  // TODO: rename snapshotReward?
  // Extract into two methods global + user
  /// @notice Snapshots the global reward parameters, then snapshots the reward parameters for the
  /// beneficiary specified.
  /// @param _beneficiary The account for which reward parameters will be snapshotted.
  /// @dev If address zero is sent as the beneficiary, only the global snapshot is executed.
  function _updateReward(address _beneficiary) internal {
    rewardPerTokenStored = rewardPerToken();
    updatedAt = lastTimeRewardApplicable();

    if (_beneficiary == address(0)) return;

    rewards[_beneficiary] = earned(_beneficiary);
    userRewardPerTokenPaid[_beneficiary] = rewardPerTokenStored;
  }

  /// @notice Internal helper method which sets the admin address.
  /// @param _newAdmin Address of the new admin.
  function _setAdmin(address _newAdmin) internal {
    _revertIfAddressZero(_newAdmin);
    emit AdminSet(admin, _newAdmin);
    admin = _newAdmin;
  }

  /// @notice Internal helper method which reverts UniStaker__Unauthorized if the message sender is
  /// not the admin.
  function _revertIfNotAdmin() internal view {
    if (msg.sender != admin) revert UniStaker__Unauthorized("not admin", msg.sender);
  }

  /// @notice Internal helper method which reverts UniStaker__Unauthorized if the message sender is
  /// not the owner of the deposit.
  /// @param deposit Deposit to validate.
  function _revertIfNotDepositOwner(Deposit storage deposit) internal view {
    if (msg.sender != deposit.owner) revert UniStaker__Unauthorized("not owner", msg.sender);
  }

  /// @notice Internal helper method which reverts with UniStaker__InvalidAddress if the account in
  /// question is address zero.
  /// @param _account Account to verify.
  function _revertIfAddressZero(address _account) internal pure {
    if (_account == address(0)) revert UniStaker__InvalidAddress();
  }
}
