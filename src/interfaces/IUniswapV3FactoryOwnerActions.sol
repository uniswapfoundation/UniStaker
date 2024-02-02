// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.23;

/// @title The interface for the Uniswap V3 Factory
/// @notice The Uniswap V3 Factory facilitates creation of Uniswap V3 pools and control over the
/// protocol fees
/// @dev Stripped down and renamed from:
/// https://github.com/Uniswap/v3-core/blob/d8b1c635c275d2a9450bd6a78f3fa2484fef73eb/contracts/interfaces/IUniswapV3Factory.sol
interface IUniswapV3FactoryOwnerActions {
  /// @notice Returns the current owner of the factory
  /// @dev Can be changed by the current owner via setOwner
  /// @return The address of the factory owner
  function owner() external view returns (address);

  /// @notice Updates the owner of the factory
  /// @dev Must be called by the current owner
  /// @param _owner The new owner of the factory
  function setOwner(address _owner) external;

  /// @notice Enables a fee amount with the given tickSpacing
  /// @dev Fee amounts may never be removed once enabled
  /// @param fee The fee amount to enable, denominated in hundredths of a bip (i.e. 1e-6)
  /// @param tickSpacing The spacing between ticks to be enforced for all pools created with the
  /// given fee amount
  function enableFeeAmount(uint24 fee, int24 tickSpacing) external;
}
