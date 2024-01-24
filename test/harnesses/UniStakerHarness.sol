// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.23;

import {DelegationSurrogate} from "src/DelegationSurrogate.sol";
import {UniStaker} from "src/UniStaker.sol";

import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin/token/ERC20/utils/SafeERC20.sol";
import {IERC20Delegates} from "src/interfaces/IERC20Delegates.sol";

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
