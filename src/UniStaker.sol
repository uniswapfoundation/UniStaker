// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {IERC20Delegates} from "src/interfaces/IERC20Delegates.sol";
import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";

contract UniStaker {
  IERC20 public immutable REWARDS_TOKEN;
  IERC20Delegates public immutable STAKE_TOKEN;

  constructor(IERC20 _rewardsToken, IERC20Delegates _stakeToken) {
    REWARDS_TOKEN = _rewardsToken;
    STAKE_TOKEN = _stakeToken;
  }
}
