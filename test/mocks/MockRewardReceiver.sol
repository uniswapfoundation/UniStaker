// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.23;

import {INotifiableRewardReceiver} from "src/interfaces/INotifiableRewardReceiver.sol";

contract MockRewardReceiver is INotifiableRewardReceiver {
  uint256 public lastParam__notifyRewardAmount_amount;

  function notifyRewardAmount(uint256 _amount) external {
    lastParam__notifyRewardAmount_amount = _amount;
  }
}
