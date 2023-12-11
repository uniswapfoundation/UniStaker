// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {DelegationSurrogate} from "src/DelegationSurrogate.sol";
import {IERC20Delegates} from "src/interfaces/IERC20Delegates.sol";
import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "openzeppelin/utils/ReentrancyGuard.sol";

contract UniStaker is ReentrancyGuard {
  IERC20 public immutable REWARDS_TOKEN;
  IERC20Delegates public immutable STAKE_TOKEN;

  mapping(address delegatee => DelegationSurrogate surrogate) public surrogates;

  constructor(IERC20 _rewardsToken, IERC20Delegates _stakeToken) {
    REWARDS_TOKEN = _rewardsToken;
    STAKE_TOKEN = _stakeToken;
  }

  function stake(uint256 _amount, address _delegatee)
    public
    nonReentrant
    returns (uint256 _depositId)
  {
    DelegationSurrogate _surrogate = _fetchOrDeploySurrogate(_delegatee);
    _stakeTokenSafeTransferFrom(msg.sender, address(_surrogate), _amount);
    _depositId = 1;
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
}
