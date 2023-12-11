// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.23;

import {DelegationSurrogate} from "src/DelegationSurrogate.sol";
import {IERC20Delegates} from "src/interfaces/IERC20Delegates.sol";
import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "openzeppelin/utils/ReentrancyGuard.sol";

contract UniStaker is ReentrancyGuard {
  type DepositIdentifier is uint256;

  struct Deposit {
    uint256 balance;
    address owner;
    address delegatee;
  }

  IERC20 public immutable REWARDS_TOKEN;
  IERC20Delegates public immutable STAKE_TOKEN;

  DepositIdentifier private nextDepositId;

  uint256 public totalSupply;

  mapping(address depositor => uint256 amount) public totalDeposits;

  mapping(DepositIdentifier depositId => Deposit deposit) public deposits;

  mapping(address delegatee => DelegationSurrogate surrogate) public surrogates;

  constructor(IERC20 _rewardsToken, IERC20Delegates _stakeToken) {
    REWARDS_TOKEN = _rewardsToken;
    STAKE_TOKEN = _stakeToken;
  }

  function stake(uint256 _amount, address _delegatee)
    external
    nonReentrant
    returns (DepositIdentifier _depositId)
  {
    DelegationSurrogate _surrogate = _fetchOrDeploySurrogate(_delegatee);
    _stakeTokenSafeTransferFrom(msg.sender, address(_surrogate), _amount);
    _depositId = _useDepositId();

    totalSupply += _amount;
    totalDeposits[msg.sender] += _amount;
    deposits[_depositId] = Deposit({balance: _amount, owner: msg.sender, delegatee: _delegatee});
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
}
