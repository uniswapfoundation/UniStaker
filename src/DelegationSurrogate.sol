// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.23;

import {IERC20Delegates} from "src/interfaces/IERC20Delegates.sol";

contract DelegationSurrogate {
  constructor(IERC20Delegates _token, address _delegatee) {
    _token.delegate(_delegatee);
    _token.approve(msg.sender, type(uint256).max);
  }
}
