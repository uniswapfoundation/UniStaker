// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.23;

import {DelegationSurrogate} from "unistaker/DelegationSurrogate.sol";
import {UniStaker} from "unistaker/UniStaker.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Delegates} from "unistaker/interfaces/IERC20Delegates.sol";

contract UniStakerHarness is UniStaker {
  constructor(IERC20 _rewardsToken, IERC20Delegates _stakeToken, address _admin)
    UniStaker(_rewardsToken, _stakeToken, _admin)
  {}

  function exposed_useDepositId() external returns (DepositIdentifier _depositId) {
    _depositId = _useDepositId();
  }

  function exposed_fetchOrDeploySurrogate(address delegatee)
    external
    returns (DelegationSurrogate _surrogate)
  {
    _surrogate = _fetchOrDeploySurrogate(delegatee);
  }
}
