// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.23;

import {DelegationSurrogate} from "src/DelegationSurrogate.sol";
import {IERC20Delegates} from "src/interfaces/IERC20Delegates.sol";
import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "openzeppelin/utils/ReentrancyGuard.sol";

contract UniStaker is ReentrancyGuard {
  type DepositIdentifier is uint256;

  error UniStaker__Unauthorized(bytes32 reason, address caller);
  error UniStaker__InvalidRewardRate();
  error UniStaker__InsufficientRewardBalance();

  struct Deposit {
    uint256 balance;
    address owner;
    address delegatee;
    address beneficiary;
  }

  IERC20 public immutable REWARDS_TOKEN;
  IERC20Delegates public immutable STAKE_TOKEN;
  address public immutable REWARDS_NOTIFIER;
  uint256 public constant REWARD_DURATION = 7 days;
  uint256 private constant SCALE_FACTOR = 1e24;

  DepositIdentifier private nextDepositId;

  uint256 public totalSupply;

  mapping(address depositor => uint256 amount) public totalDeposits;

  mapping(address beneficiary => uint256 amount) public earningPower;

  mapping(DepositIdentifier depositId => Deposit deposit) public deposits;

  mapping(address delegatee => DelegationSurrogate surrogate) public surrogates;

  uint256 public finishAt;
  uint256 public updatedAt;
  uint256 public rewardRate;
  uint256 public rewardPerTokenStored;
  mapping(address account => uint256) public userRewardPerTokenPaid;
  mapping(address account => uint256 amount) public rewards;

  constructor(IERC20 _rewardsToken, IERC20Delegates _stakeToken, address _rewardsNotifier) {
    REWARDS_TOKEN = _rewardsToken;
    STAKE_TOKEN = _stakeToken;
    REWARDS_NOTIFIER = _rewardsNotifier;
  }

  function lastTimeRewardApplicable() public view returns (uint256) {
    if (finishAt <= block.timestamp) return finishAt;
    else return block.timestamp;
  }

  function rewardPerToken() public view returns (uint256) {
    if (totalSupply == 0) return rewardPerTokenStored;

    return rewardPerTokenStored
      + (rewardRate * (lastTimeRewardApplicable() - updatedAt) * SCALE_FACTOR) / totalSupply;
  }

  function earned(address _beneficiary) public view returns (uint256) {
    return rewards[_beneficiary]
      + (earningPower[_beneficiary] * (rewardPerToken() - userRewardPerTokenPaid[_beneficiary]))
        / SCALE_FACTOR;
  }

  function stake(uint256 _amount, address _delegatee)
    external
    nonReentrant
    returns (DepositIdentifier _depositId)
  {
    _depositId = _stake(_amount, _delegatee, msg.sender);
  }

  function stake(uint256 _amount, address _delegatee, address _beneficiary)
    public
    nonReentrant
    returns (DepositIdentifier _depositId)
  {
    _depositId = _stake(_amount, _delegatee, _beneficiary);
  }

  function withdraw(DepositIdentifier _depositId, uint256 _amount) external nonReentrant {
    Deposit storage deposit = deposits[_depositId];
    if (msg.sender != deposit.owner) revert UniStaker__Unauthorized("not owner", msg.sender);

    _updateReward(deposit.beneficiary);

    deposit.balance -= _amount; // overflow prevents withdrawing more than balance
    totalSupply -= _amount;
    totalDeposits[msg.sender] -= _amount;
    earningPower[deposit.beneficiary] -= _amount;
    _stakeTokenSafeTransferFrom(address(surrogates[deposit.delegatee]), deposit.owner, _amount);
  }

  function notifyRewardsAmount(uint256 _amount) external {
    if (msg.sender != REWARDS_NOTIFIER) revert UniStaker__Unauthorized("not notifier", msg.sender);
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
  }

  function _fetchOrDeploySurrogate(address _delegatee)
    internal
    returns (DelegationSurrogate _surrogate)
  {
    _surrogate = surrogates[_delegatee];

    if (address(_surrogate) == address(0)) {
      _surrogate = new DelegationSurrogate(STAKE_TOKEN, _delegatee);
      surrogates[_delegatee] = _surrogate;
    }
  }

  function _stakeTokenSafeTransferFrom(address _from, address _to, uint256 _value) internal {
    SafeERC20.safeTransferFrom(IERC20(address(STAKE_TOKEN)), _from, _to, _value);
  }

  function _useDepositId() internal returns (DepositIdentifier _depositId) {
    _depositId = nextDepositId;
    nextDepositId = DepositIdentifier.wrap(DepositIdentifier.unwrap(_depositId) + 1);
  }

  function _stake(uint256 _amount, address _delegatee, address _beneficiary)
    internal
    returns (DepositIdentifier _depositId)
  {
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
  }

  // TODO: rename snapshotReward?
  // Extract into two methods global + user
  function _updateReward(address _beneficiary) internal {
    rewardPerTokenStored = rewardPerToken();
    updatedAt = lastTimeRewardApplicable();

    if (_beneficiary == address(0)) return;

    rewards[_beneficiary] = earned(_beneficiary);
    userRewardPerTokenPaid[_beneficiary] = rewardPerTokenStored;
  }
}
