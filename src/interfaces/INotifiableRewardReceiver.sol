// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.23;

/// @title INotifiableRewardReceiver
/// @author ScopeLift
/// @notice The communication interface between the V3FactoryOwner contract and the UniStaker
/// contract. In particular, the V3FactoryOwner only needs to know the latter implements the
/// specified method in order to forward payouts to the UniStaker contract. The UniStaker contract
/// receives the rewards and abstracts the distribution mechanics
interface INotifiableRewardReceiver {
  /// @notice Called by an authorized rewards notifier to alert the staking contract that a new
  /// reward has been transferred to it. It is assumed that the reward has already been transferred
  /// to this staking contract before the rewards notifier calls this method.
  /// @param _amount Quantity of reward tokens the staking contract is being notified of.
  /// @dev It is critical that only well behaved contracts are approved by the admin to call this
  /// method, for two reasons.
  ///
  /// 1. A misbehaving contract could grief stakers by frequently notifying this contract of tiny
  /// rewards, thereby continuously stretching out the time duration over which real rewards are
  /// distributed. It is required that reward notifiers supply reasonable rewards at reasonable
  /// intervals.
  ///
  /// 2. A misbehaving contract could falsely notify this contract of rewards that were not actually
  /// distributed, creating a shortfall for those claiming their rewards after others. It is
  /// required that a notifier contract always transfers the `_amount` to this contract before
  /// calling this method.
  function notifyRewardAmount(uint256 _amount) external;
}
