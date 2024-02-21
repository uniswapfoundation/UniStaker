// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.23;

import {DelegationSurrogate} from "src/DelegationSurrogate.sol";
import {INotifiableRewardReceiver} from "src/interfaces/INotifiableRewardReceiver.sol";
import {IERC20Delegates} from "src/interfaces/IERC20Delegates.sol";
import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin/token/ERC20/utils/SafeERC20.sol";
import {Multicall} from "openzeppelin/utils/Multicall.sol";
import {Nonces} from "openzeppelin/utils/Nonces.sol";
import {SignatureChecker} from "openzeppelin/utils/cryptography/SignatureChecker.sol";
import {EIP712} from "openzeppelin/utils/cryptography/EIP712.sol";

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
contract UniStaker is INotifiableRewardReceiver, Multicall, EIP712, Nonces {
  type DepositIdentifier is uint256;

  /// @notice Emitted when stake is deposited by a depositor, either to a new deposit or one that
  /// already exists.
  event StakeDeposited(
    address owner, DepositIdentifier indexed depositId, uint256 amount, uint256 depositBalance
  );

  /// @notice Emitted when a depositor withdraws some portion of stake from a given deposit.
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

  /// @notice Thrown if the following invariant is broken after a new reward: the contract should
  /// always have a reward balance sufficient to distribute at the reward rate across the reward
  /// duration.
  error UniStaker__InsufficientRewardBalance();

  /// @notice Thrown if a caller attempts to specify address zero for certain designated addresses.
  error UniStaker__InvalidAddress();

  /// @notice Thrown if a caller supplies an invalid signature to a method that requires one.
  error UniStaker__InvalidSignature();

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

  /// @notice Type hash used when encoding data for `stakeOnBehalf` calls.
  bytes32 public constant STAKE_TYPEHASH = keccak256(
    "Stake(uint256 amount,address delegatee,address beneficiary,address depositor,uint256 nonce)"
  );
  /// @notice Type hash used when encoding data for `stakeMoreOnBehalf` calls.
  bytes32 public constant STAKE_MORE_TYPEHASH =
    keccak256("StakeMore(uint256 depositId,uint256 amount,address depositor,uint256 nonce)");
  /// @notice Type hash used when encoding data for `alterDelegateeOnBehalf` calls.
  bytes32 public constant ALTER_DELEGATEE_TYPEHASH = keccak256(
    "AlterDelegatee(uint256 depositId,address newDelegatee,address depositor,uint256 nonce)"
  );
  /// @notice Type hash used when encoding data for `alterBeneficiaryOnBehalf` calls.
  bytes32 public constant ALTER_BENEFICIARY_TYPEHASH = keccak256(
    "AlterBeneficiary(uint256 depositId,address newBeneficiary,address depositor,uint256 nonce)"
  );
  /// @notice Type hash used when encoding data for `withdrawOnBehalf` calls.
  bytes32 public constant WITHDRAW_TYPEHASH =
    keccak256("Withdraw(uint256 depositId,uint256 amount,address depositor,uint256 nonce)");
  /// @notice Type hash used when encoding data for `claimRewardOnBehalf` calls.
  bytes32 public constant CLAIM_REWARD_TYPEHASH =
    keccak256("ClaimReward(address beneficiary,uint256 nonce)");

  /// @notice ERC20 token in which rewards are denominated and distributed.
  IERC20 public immutable REWARD_TOKEN;

  /// @notice Delegable governance token which users stake to earn rewards.
  IERC20Delegates public immutable STAKE_TOKEN;

  /// @notice Length of time over which rewards sent to this contract are distributed to stakers.
  uint256 public constant REWARD_DURATION = 30 days;

  /// @notice Scale factor used in reward calculation math to reduce rounding errors caused by
  /// truncation during division.
  uint256 public constant SCALE_FACTOR = 1e36;

  /// @dev Unique identifier that will be used for the next deposit.
  DepositIdentifier private nextDepositId;

  /// @notice Permissioned actor that can enable/disable `rewardNotifier` addresses.
  address public admin;

  /// @notice Global amount currently staked across all deposits.
  uint256 public totalStaked;

  /// @notice Tracks the total staked by a depositor across all unique deposits.
  mapping(address depositor => uint256 amount) public depositorTotalStaked;

  /// @notice Tracks the total stake actively earning rewards for a given beneficiary account.
  mapping(address beneficiary => uint256 amount) public earningPower;

  /// @notice Stores the metadata associated with a given deposit.
  mapping(DepositIdentifier depositId => Deposit deposit) public deposits;

  /// @notice Maps the account of each governance delegate with the surrogate contract which holds
  /// the staked tokens from deposits which assign voting weight to said delegate.
  mapping(address delegatee => DelegationSurrogate surrogate) public surrogates;

  /// @notice Time at which rewards distribution will complete if there are no new rewards.
  uint256 public rewardEndTime;

  /// @notice Last time at which the global rewards accumulator was updated.
  uint256 public lastCheckpointTime;

  /// @notice Global rate at which rewards are currently being distributed to stakers,
  /// denominated in scaled reward tokens per second, using the SCALE_FACTOR.
  uint256 public scaledRewardRate;

  /// @notice Checkpoint value of the global reward per token accumulator.
  uint256 public rewardPerTokenAccumulatedCheckpoint;

  /// @notice Checkpoint of the reward per token accumulator on a per account basis. It represents
  /// the value of the global accumulator at the last time a given beneficiary's rewards were
  /// calculated and stored. The difference between the global value and this value can be
  /// used to calculate the interim rewards earned by given account.
  mapping(address account => uint256) public beneficiaryRewardPerTokenCheckpoint;

  /// @notice Checkpoint of the unclaimed rewards earned by a given beneficiary. This value is
  /// stored any time an action is taken that specifically impacts the rate at which rewards are
  /// earned by a given beneficiary account. Total unclaimed rewards for an account are thus this
  /// value plus all rewards earned after this checkpoint was taken. This value is reset to zero
  /// when a beneficiary account claims their earned rewards.
  mapping(address account => uint256 amount) public unclaimedRewardCheckpoint;

  /// @notice Maps addresses to whether they are authorized to call `notifyRewardAmount`.
  mapping(address rewardNotifier => bool) public isRewardNotifier;

  /// @param _rewardToken ERC20 token in which rewards will be denominated.
  /// @param _stakeToken Delegable governance token which users will stake to earn rewards.
  /// @param _admin Address which will have permission to manage rewardNotifiers.
  constructor(IERC20 _rewardToken, IERC20Delegates _stakeToken, address _admin)
    EIP712("UniStaker", "1")
  {
    REWARD_TOKEN = _rewardToken;
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

  /// @notice Enables or disables a reward notifier address.
  /// @param _rewardNotifier Address of the reward notifier.
  /// @param _isEnabled `true` to enable the `_rewardNotifier`, or `false` to disable.
  /// @dev Caller must be the current admin.
  function setRewardNotifier(address _rewardNotifier, bool _isEnabled) external {
    _revertIfNotAdmin();
    isRewardNotifier[_rewardNotifier] = _isEnabled;
    emit RewardNotifierSet(_rewardNotifier, _isEnabled);
  }

  /// @notice Timestamp representing the last time at which rewards have been distributed, which is
  /// either the current timestamp (because rewards are still actively being streamed) or the time
  /// at which the reward duration ended (because all rewards to date have already been streamed).
  function lastTimeRewardDistributed() public view returns (uint256) {
    if (rewardEndTime <= block.timestamp) return rewardEndTime;
    else return block.timestamp;
  }

  /// @notice Live value of the global reward per token accumulator. It is the sum of the last
  /// checkpoint value with the live calculation of the value that has accumulated in the interim.
  /// This number should monotonically increase over time as more rewards are distributed.
  function rewardPerTokenAccumulated() public view returns (uint256) {
    if (totalStaked == 0) return rewardPerTokenAccumulatedCheckpoint;

    return rewardPerTokenAccumulatedCheckpoint
      + (scaledRewardRate * (lastTimeRewardDistributed() - lastCheckpointTime)) / totalStaked;
  }

  /// @notice Live value of the unclaimed rewards earned by a given beneficiary account. It is the
  /// sum of the last checkpoint value of their unclaimed rewards with the live calculation of the
  /// rewards that have accumulated for this account in the interim. This value can only increase,
  /// until it is reset to zero once the beneficiary account claims their unearned rewards.
  function unclaimedReward(address _beneficiary) public view returns (uint256) {
    return unclaimedRewardCheckpoint[_beneficiary]
      + (
        earningPower[_beneficiary]
          * (rewardPerTokenAccumulated() - beneficiaryRewardPerTokenCheckpoint[_beneficiary])
      ) / SCALE_FACTOR;
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
    returns (DepositIdentifier _depositId)
  {
    _depositId = _stake(msg.sender, _amount, _delegatee, msg.sender);
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
    returns (DepositIdentifier _depositId)
  {
    _depositId = _stake(msg.sender, _amount, _delegatee, _beneficiary);
  }

  /// @notice Method to stake tokens to a new deposit. The caller must approve the staking
  /// contract to spend at least the would-be staked amount of the token via a signature which is
  /// is also provided, and is passed to the token contract's permit method before the staking
  /// operation occurs.
  /// @param _amount Quantity of the staking token to stake.
  /// @param _delegatee Address to assign the governance voting weight of the staked tokens.
  /// @param _beneficiary Address that will accrue rewards for this stake.
  /// @param _deadline The timestamp at which the permit signature should expire.
  /// @param _v ECDSA signature component: Parity of the `y` coordinate of point `R`
  /// @param _r ECDSA signature component: x-coordinate of `R`
  /// @param _s ECDSA signature component: `s` value of the signature
  /// @return _depositId Unique identifier for this deposit.
  /// @dev Neither the delegatee nor the beneficiary may be the zero address. The deposit will be
  /// owned by the message sender.
  function permitAndStake(
    uint256 _amount,
    address _delegatee,
    address _beneficiary,
    uint256 _deadline,
    uint8 _v,
    bytes32 _r,
    bytes32 _s
  ) external returns (DepositIdentifier _depositId) {
    STAKE_TOKEN.permit(msg.sender, address(this), _amount, _deadline, _v, _r, _s);
    _depositId = _stake(msg.sender, _amount, _delegatee, _beneficiary);
  }

  /// @notice Stake tokens to a new deposit on behalf of a user, using a signature to validate the
  /// user's intent. The caller must pre-approve the staking contract to spend at least the
  /// would-be staked amount of the token.
  /// @param _amount Quantity of the staking token to stake.
  /// @param _delegatee Address to assign the governance voting weight of the staked tokens.
  /// @param _beneficiary Address that will accrue rewards for this stake.
  /// @param _depositor Address of the user on whose behalf this stake is being made.
  /// @param _signature Signature of the user authorizing this stake.
  /// @return _depositId Unique identifier for this deposit.
  /// @dev Neither the delegatee nor the beneficiary may be the zero address.
  function stakeOnBehalf(
    uint256 _amount,
    address _delegatee,
    address _beneficiary,
    address _depositor,
    bytes memory _signature
  ) external returns (DepositIdentifier _depositId) {
    _revertIfSignatureIsNotValidNow(
      _depositor,
      _hashTypedDataV4(
        keccak256(
          abi.encode(
            STAKE_TYPEHASH, _amount, _delegatee, _beneficiary, _depositor, _useNonce(_depositor)
          )
        )
      ),
      _signature
    );
    _depositId = _stake(_depositor, _amount, _delegatee, _beneficiary);
  }

  /// @notice Add more staking tokens to an existing deposit. A staker should call this method when
  /// they have an existing deposit, and wish to stake more while retaining the same delegatee and
  /// beneficiary.
  /// @param _depositId Unique identifier of the deposit to which stake will be added.
  /// @param _amount Quantity of stake to be added.
  /// @dev The message sender must be the owner of the deposit.
  function stakeMore(DepositIdentifier _depositId, uint256 _amount) external {
    Deposit storage deposit = deposits[_depositId];
    _revertIfNotDepositOwner(deposit, msg.sender);
    _stakeMore(deposit, _depositId, _amount);
  }

  /// @notice Add more staking tokens to an existing deposit. A staker should call this method when
  /// they have an existing deposit, and wish to stake more while retaining the same delegatee and
  /// beneficiary. The caller must approve the staking contract to spend at least the would-be
  /// staked amount of the token via a signature which is is also provided, and is passed to the
  /// token contract's permit method before the staking operation occurs.
  /// @param _depositId Unique identifier of the deposit to which stake will be added.
  /// @param _amount Quantity of stake to be added.
  /// @param _deadline The timestamp at which the permit signature should expire.
  /// @param _v ECDSA signature component: Parity of the `y` coordinate of point `R`
  /// @param _r ECDSA signature component: x-coordinate of `R`
  /// @param _s ECDSA signature component: `s` value of the signature
  /// @dev The message sender must be the owner of the deposit.
  function permitAndStakeMore(
    DepositIdentifier _depositId,
    uint256 _amount,
    uint256 _deadline,
    uint8 _v,
    bytes32 _r,
    bytes32 _s
  ) external {
    Deposit storage deposit = deposits[_depositId];
    _revertIfNotDepositOwner(deposit, msg.sender);

    STAKE_TOKEN.permit(msg.sender, address(this), _amount, _deadline, _v, _r, _s);
    _stakeMore(deposit, _depositId, _amount);
  }

  /// @notice Add more staking tokens to an existing deposit on behalf of a user, using a signature
  /// to validate the user's intent. A staker should call this method when they have an existing
  /// deposit, and wish to stake more while retaining the same delegatee and beneficiary.
  /// @param _depositId Unique identifier of the deposit to which stake will be added.
  /// @param _amount Quantity of stake to be added.
  /// @param _depositor Address of the user on whose behalf this stake is being made.
  /// @param _signature Signature of the user authorizing this stake.
  function stakeMoreOnBehalf(
    DepositIdentifier _depositId,
    uint256 _amount,
    address _depositor,
    bytes memory _signature
  ) external {
    Deposit storage deposit = deposits[_depositId];
    _revertIfNotDepositOwner(deposit, _depositor);

    _revertIfSignatureIsNotValidNow(
      _depositor,
      _hashTypedDataV4(
        keccak256(
          abi.encode(STAKE_MORE_TYPEHASH, _depositId, _amount, _depositor, _useNonce(_depositor))
        )
      ),
      _signature
    );

    _stakeMore(deposit, _depositId, _amount);
  }

  /// @notice For an existing deposit, change the address to which governance voting power is
  /// assigned.
  /// @param _depositId Unique identifier of the deposit which will have its delegatee altered.
  /// @param _newDelegatee Address of the new governance delegate.
  /// @dev The new delegatee may not be the zero address. The message sender must be the owner of
  /// the deposit.
  function alterDelegatee(DepositIdentifier _depositId, address _newDelegatee) external {
    Deposit storage deposit = deposits[_depositId];
    _revertIfNotDepositOwner(deposit, msg.sender);
    _alterDelegatee(deposit, _depositId, _newDelegatee);
  }

  /// @notice For an existing deposit, change the address to which governance voting power is
  /// assigned on behalf of a user, using a signature to validate the user's intent.
  /// @param _depositId Unique identifier of the deposit which will have its delegatee altered.
  /// @param _newDelegatee Address of the new governance delegate.
  /// @param _depositor Address of the user on whose behalf this stake is being made.
  /// @param _signature Signature of the user authorizing this stake.
  /// @dev The new delegatee may not be the zero address.
  function alterDelegateeOnBehalf(
    DepositIdentifier _depositId,
    address _newDelegatee,
    address _depositor,
    bytes memory _signature
  ) external {
    Deposit storage deposit = deposits[_depositId];
    _revertIfNotDepositOwner(deposit, _depositor);

    _revertIfSignatureIsNotValidNow(
      _depositor,
      _hashTypedDataV4(
        keccak256(
          abi.encode(
            ALTER_DELEGATEE_TYPEHASH, _depositId, _newDelegatee, _depositor, _useNonce(_depositor)
          )
        )
      ),
      _signature
    );

    _alterDelegatee(deposit, _depositId, _newDelegatee);
  }

  /// @notice For an existing deposit, change the beneficiary to which staking rewards are
  /// accruing.
  /// @param _depositId Unique identifier of the deposit which will have its beneficiary altered.
  /// @param _newBeneficiary Address of the new rewards beneficiary.
  /// @dev The new beneficiary may not be the zero address. The message sender must be the owner of
  /// the deposit.
  function alterBeneficiary(DepositIdentifier _depositId, address _newBeneficiary) external {
    Deposit storage deposit = deposits[_depositId];
    _revertIfNotDepositOwner(deposit, msg.sender);
    _alterBeneficiary(deposit, _depositId, _newBeneficiary);
  }

  /// @notice For an existing deposit, change the beneficiary to which staking rewards are
  /// accruing on behalf of a user, using a signature to validate the user's intent.
  /// @param _depositId Unique identifier of the deposit which will have its beneficiary altered.
  /// @param _newBeneficiary Address of the new rewards beneficiary.
  /// @param _depositor Address of the user on whose behalf this stake is being made.
  /// @param _signature Signature of the user authorizing this stake.
  /// @dev The new beneficiary may not be the zero address.
  function alterBeneficiaryOnBehalf(
    DepositIdentifier _depositId,
    address _newBeneficiary,
    address _depositor,
    bytes memory _signature
  ) external {
    Deposit storage deposit = deposits[_depositId];
    _revertIfNotDepositOwner(deposit, _depositor);

    _revertIfSignatureIsNotValidNow(
      _depositor,
      _hashTypedDataV4(
        keccak256(
          abi.encode(
            ALTER_BENEFICIARY_TYPEHASH,
            _depositId,
            _newBeneficiary,
            _depositor,
            _useNonce(_depositor)
          )
        )
      ),
      _signature
    );

    _alterBeneficiary(deposit, _depositId, _newBeneficiary);
  }

  /// @notice Withdraw staked tokens from an existing deposit.
  /// @param _depositId Unique identifier of the deposit from which stake will be withdrawn.
  /// @param _amount Quantity of staked token to withdraw.
  /// @dev The message sender must be the owner of the deposit. Stake is withdrawn to the message
  /// sender's account.
  function withdraw(DepositIdentifier _depositId, uint256 _amount) external {
    Deposit storage deposit = deposits[_depositId];
    _revertIfNotDepositOwner(deposit, msg.sender);
    _withdraw(deposit, _depositId, _amount);
  }

  /// @notice Withdraw staked tokens from an existing deposit on behalf of a user, using a
  /// signature to validate the user's intent.
  /// @param _depositId Unique identifier of the deposit from which stake will be withdrawn.
  /// @param _amount Quantity of staked token to withdraw.
  /// @param _depositor Address of the user on whose behalf this stake is being made.
  /// @param _signature Signature of the user authorizing this stake.
  /// @dev Stake is withdrawn to the deposit owner's account.
  function withdrawOnBehalf(
    DepositIdentifier _depositId,
    uint256 _amount,
    address _depositor,
    bytes memory _signature
  ) external {
    Deposit storage deposit = deposits[_depositId];
    _revertIfNotDepositOwner(deposit, _depositor);

    _revertIfSignatureIsNotValidNow(
      _depositor,
      _hashTypedDataV4(
        keccak256(
          abi.encode(WITHDRAW_TYPEHASH, _depositId, _amount, _depositor, _useNonce(_depositor))
        )
      ),
      _signature
    );

    _withdraw(deposit, _depositId, _amount);
  }

  /// @notice Claim reward tokens the message sender has earned as a stake beneficiary. Tokens are
  /// sent to the message sender.
  function claimReward() external {
    _claimReward(msg.sender);
  }

  /// @notice Claim earned reward tokens for a beneficiary, using a signature to validate the
  /// beneficiary's intent. Tokens are sent to the beneficiary.
  /// @param _beneficiary Address of the beneficiary who will receive the reward.
  /// @param _signature Signature of the beneficiary authorizing this reward claim.
  function claimRewardOnBehalf(address _beneficiary, bytes memory _signature) external {
    _revertIfSignatureIsNotValidNow(
      _beneficiary,
      _hashTypedDataV4(
        keccak256(abi.encode(CLAIM_REWARD_TYPEHASH, _beneficiary, _useNonce(_beneficiary)))
      ),
      _signature
    );
    _claimReward(_beneficiary);
  }

  /// @notice Called by an authorized rewards notifier to alert the staking contract that a new
  /// reward has been transferred to it. Note the reward must already have been transferred to this
  /// staking contract before the rewards notifier calls this method.
  /// @param _amount Quantity of reward tokens the staking contract is being notified of.
  function notifyRewardAmount(uint256 _amount) external {
    if (!isRewardNotifier[msg.sender]) revert UniStaker__Unauthorized("not notifier", msg.sender);

    // We checkpoint the accumulator without updating the timestamp at which it was updated, because
    // that second operation will be done after updating the reward rate.
    rewardPerTokenAccumulatedCheckpoint = rewardPerTokenAccumulated();

    if (block.timestamp >= rewardEndTime) {
      scaledRewardRate = (_amount * SCALE_FACTOR) / REWARD_DURATION;
    } else {
      uint256 _remainingReward = scaledRewardRate * (rewardEndTime - block.timestamp);
      scaledRewardRate = (_remainingReward + _amount * SCALE_FACTOR) / REWARD_DURATION;
    }

    rewardEndTime = block.timestamp + REWARD_DURATION;
    lastCheckpointTime = block.timestamp;

    if ((scaledRewardRate / SCALE_FACTOR) == 0) revert UniStaker__InvalidRewardRate();
    if (
      (scaledRewardRate * REWARD_DURATION) > (REWARD_TOKEN.balanceOf(address(this)) * SCALE_FACTOR)
    ) revert UniStaker__InsufficientRewardBalance();

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
  /// @dev This method must only be called after proper authorization has been completed.
  /// @dev See public stake methods for additional documentation.
  function _stake(address _depositor, uint256 _amount, address _delegatee, address _beneficiary)
    internal
    returns (DepositIdentifier _depositId)
  {
    _revertIfAddressZero(_delegatee);
    _revertIfAddressZero(_beneficiary);

    _checkpointGlobalReward();
    _checkpointReward(_beneficiary);

    DelegationSurrogate _surrogate = _fetchOrDeploySurrogate(_delegatee);
    _depositId = _useDepositId();

    totalStaked += _amount;
    depositorTotalStaked[_depositor] += _amount;
    earningPower[_beneficiary] += _amount;
    deposits[_depositId] = Deposit({
      balance: _amount,
      owner: _depositor,
      delegatee: _delegatee,
      beneficiary: _beneficiary
    });
    _stakeTokenSafeTransferFrom(_depositor, address(_surrogate), _amount);
    emit StakeDeposited(_depositor, _depositId, _amount, _amount);
    emit BeneficiaryAltered(_depositId, address(0), _beneficiary);
    emit DelegateeAltered(_depositId, address(0), _delegatee);
  }

  /// @notice Internal convenience method which adds more stake to an existing deposit.
  /// @dev This method must only be called after proper authorization has been completed.
  /// @dev See public stakeMore methods for additional documentation.
  function _stakeMore(Deposit storage deposit, DepositIdentifier _depositId, uint256 _amount)
    internal
  {
    _checkpointGlobalReward();
    _checkpointReward(deposit.beneficiary);

    DelegationSurrogate _surrogate = surrogates[deposit.delegatee];

    totalStaked += _amount;
    depositorTotalStaked[deposit.owner] += _amount;
    earningPower[deposit.beneficiary] += _amount;
    deposit.balance += _amount;
    _stakeTokenSafeTransferFrom(deposit.owner, address(_surrogate), _amount);
    emit StakeDeposited(deposit.owner, _depositId, _amount, deposit.balance);
  }

  /// @notice Internal convenience method which alters the delegatee of an existing deposit.
  /// @dev This method must only be called after proper authorization has been completed.
  /// @dev See public alterDelegatee methods for additional documentation.
  function _alterDelegatee(
    Deposit storage deposit,
    DepositIdentifier _depositId,
    address _newDelegatee
  ) internal {
    _revertIfAddressZero(_newDelegatee);
    DelegationSurrogate _oldSurrogate = surrogates[deposit.delegatee];
    emit DelegateeAltered(_depositId, deposit.delegatee, _newDelegatee);
    deposit.delegatee = _newDelegatee;
    DelegationSurrogate _newSurrogate = _fetchOrDeploySurrogate(_newDelegatee);
    _stakeTokenSafeTransferFrom(address(_oldSurrogate), address(_newSurrogate), deposit.balance);
  }

  /// @notice Internal convenience method which alters the beneficiary of an existing deposit.
  /// @dev This method must only be called after proper authorization has been completed.
  /// @dev See public alterBeneficiary methods for additional documentation.
  function _alterBeneficiary(
    Deposit storage deposit,
    DepositIdentifier _depositId,
    address _newBeneficiary
  ) internal {
    _revertIfAddressZero(_newBeneficiary);
    _checkpointGlobalReward();
    _checkpointReward(deposit.beneficiary);
    earningPower[deposit.beneficiary] -= deposit.balance;

    _checkpointReward(_newBeneficiary);
    emit BeneficiaryAltered(_depositId, deposit.beneficiary, _newBeneficiary);
    deposit.beneficiary = _newBeneficiary;
    earningPower[_newBeneficiary] += deposit.balance;
  }

  /// @notice Internal convenience method which withdraws the stake from an existing deposit.
  /// @dev This method must only be called after proper authorization has been completed.
  /// @dev See public withdraw methods for additional documentation.
  function _withdraw(Deposit storage deposit, DepositIdentifier _depositId, uint256 _amount)
    internal
  {
    _checkpointGlobalReward();
    _checkpointReward(deposit.beneficiary);

    deposit.balance -= _amount; // overflow prevents withdrawing more than balance
    totalStaked -= _amount;
    depositorTotalStaked[deposit.owner] -= _amount;
    earningPower[deposit.beneficiary] -= _amount;
    _stakeTokenSafeTransferFrom(address(surrogates[deposit.delegatee]), deposit.owner, _amount);
    emit StakeWithdrawn(_depositId, _amount, deposit.balance);
  }

  /// @notice Internal convenience method which claims earned rewards.
  /// @dev This method must only be called after proper authorization has been completed.
  /// @dev See public claimReward methods for additional documentation.
  function _claimReward(address _beneficiary) internal {
    _checkpointGlobalReward();
    _checkpointReward(_beneficiary);

    uint256 _reward = unclaimedRewardCheckpoint[_beneficiary];
    if (_reward == 0) return;
    unclaimedRewardCheckpoint[_beneficiary] = 0;
    emit RewardClaimed(_beneficiary, _reward);

    SafeERC20.safeTransfer(REWARD_TOKEN, _beneficiary, _reward);
  }

  /// @notice Checkpoints the global reward per token accumulator.
  function _checkpointGlobalReward() internal {
    rewardPerTokenAccumulatedCheckpoint = rewardPerTokenAccumulated();
    lastCheckpointTime = lastTimeRewardDistributed();
  }

  /// @notice Checkpoints the unclaimed rewards and reward per token accumulator of a given
  /// beneficiary account.
  /// @param _beneficiary The account for which reward parameters will be checkpointed.
  /// @dev This is a sensitive internal helper method that must only be called after global rewards
  /// accumulator has been checkpointed. It assumes the global `rewardPerTokenCheckpoint` is up to
  /// date.
  function _checkpointReward(address _beneficiary) internal {
    unclaimedRewardCheckpoint[_beneficiary] = unclaimedReward(_beneficiary);
    beneficiaryRewardPerTokenCheckpoint[_beneficiary] = rewardPerTokenAccumulatedCheckpoint;
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

  /// @notice Internal helper method which reverts UniStaker__Unauthorized if the alleged owner is
  /// not the true owner of the deposit.
  /// @param deposit Deposit to validate.
  /// @param owner Alleged owner of deposit.
  function _revertIfNotDepositOwner(Deposit storage deposit, address owner) internal view {
    if (owner != deposit.owner) revert UniStaker__Unauthorized("not owner", owner);
  }

  /// @notice Internal helper method which reverts with UniStaker__InvalidAddress if the account in
  /// question is address zero.
  /// @param _account Account to verify.
  function _revertIfAddressZero(address _account) internal pure {
    if (_account == address(0)) revert UniStaker__InvalidAddress();
  }

  /// @notice Internal helper method which reverts with UniStaker__InvalidSignature if the signature
  /// is invalid.
  /// @param _signer Address of the signer.
  /// @param _hash Hash of the message.
  /// @param _signature Signature to validate.
  function _revertIfSignatureIsNotValidNow(address _signer, bytes32 _hash, bytes memory _signature)
    internal
    view
  {
    bool _isValid = SignatureChecker.isValidSignatureNow(_signer, _hash, _signature);
    if (!_isValid) revert UniStaker__InvalidSignature();
  }
}
