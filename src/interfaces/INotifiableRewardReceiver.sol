// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.23;

/// @title INotifiableRewardReceiver
/// @author ScopeLift
/// @notice The communication interface between the V3FactoryOwner contract and the UniStaker
/// contract. In particular, the V3FactoryOwner only needs to know the latter implements the
/// specified method in order to forward payouts to the UniStaker contract. The UniStaker contract
/// receives the rewards and abstracts the distribution mechanics
interface INotifiableRewardReceiver {
  /// @notice Method called to notify a reward receiver it has received a reward.
  /// @param _amount The amount of reward.
  function notifyRewardAmount(uint256 _amount) external;
}
