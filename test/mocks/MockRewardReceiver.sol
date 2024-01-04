// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.23;

import {INotifiableRewardReceiver} from "src/interfaces/INotifiableRewardReceiver.sol";

contract MockRewardReceiver is INotifiableRewardReceiver {
  uint256 public lastParam__notifyRewardsAmount_amount;

  function notifyRewardsAmount(uint256 _amount) external {
    lastParam__notifyRewardsAmount_amount = _amount;
  }
}
