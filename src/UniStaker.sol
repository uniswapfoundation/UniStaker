// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {DelegationSurrogate} from "src/DelegationSurrogate.sol";
import {IERC20Delegates} from "src/interfaces/IERC20Delegates.sol";
import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "openzeppelin/utils/ReentrancyGuard.sol";

contract UniStaker is ReentrancyGuard {
  type DepositIdentifier is uint256;

  error UniStaker__Unauthorized(bytes32 reason, address caller);

  struct Deposit {
    uint256 balance;
    address owner;
    address delegatee;
    address beneficiary;
  }

  IERC20 public immutable REWARDS_TOKEN;
  IERC20Delegates public immutable STAKE_TOKEN;
  uint256 private SCALE_FACTOR = 1e18;

  DepositIdentifier private nextDepositId = DepositIdentifier.wrap(1);

  uint256 public totalSupply;

  mapping(address depositor => uint256 amount) public totalDeposits;

  mapping(address beneficiary => uint256 amount) public earningPower;

  mapping(DepositIdentifier depositId => Deposit deposit) public deposits;

  mapping(address delegatee => DelegationSurrogate surrogate) public surrogates;

  uint256 public rewardDuration;
  uint256 public finishAt;
  uint256 public updatedAt;
  uint256 public rewardRate;
  uint256 public rewardPerTokenStored;
  mapping(address account => uint256) public userRewardPerTokenPaid;
  mapping(address account => uint256 amount) public rewards;

  constructor(IERC20 _rewardsToken, IERC20Delegates _stakeToken) {
    REWARDS_TOKEN = _rewardsToken;
    STAKE_TOKEN = _stakeToken;
  }

  function lastTimeRewardApplicable() public view returns (uint256) {
    if (finishAt <= block.timestamp) {
      return finishAt;
    } else {
      return block.timestamp;
    }
  }

  function rewardPerToken() public view returns (uint256) {
    if (totalSupply == 0) {
      return rewardPerTokenStored;
    }

    return rewardPerTokenStored + (rewardRate * (lastTimeRewardApplicable() - updatedAt) * SCALE_FACTOR) / totalSupply;
  }

  function earned(address _account) public view returns (uint256) {
    return rewards[_account] + (earningPower[_account] * (rewardPerToken() - userRewardPerTokenPaid[_account])) / SCALE_FACTOR;
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

    deposit.balance -= _amount; // overflow prevents withdrawing more than balance
    totalSupply -= _amount;
    totalDeposits[msg.sender] -= _amount;
    earningPower[deposit.beneficiary] -= _amount;
    _stakeTokenSafeTransferFrom(address(surrogates[deposit.delegatee]), deposit.owner, _amount);
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

  function _updateReward(address _account) internal {
    rewardPerTokenStored = rewardPerToken();
    updatedAt = lastTimeRewardApplicable();

    if (_account == address(0)) return;

    rewards[_account] = earned(_account);
    userRewardPerTokenPaid[_account] = rewardPerTokenStored;
  }
}
