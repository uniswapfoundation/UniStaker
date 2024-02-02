// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.23;

import {IUniswapV3PoolOwnerActions} from "src/interfaces/IUniswapV3PoolOwnerActions.sol";

interface IUniswapPool is IUniswapV3PoolOwnerActions {
  function slot0()
    external
    view
    returns (
      uint160 sqrtPriceX96,
      int24 tick,
      uint16 observationIndex,
      uint16 observationCardinality,
      uint16 observationCardinalityNext,
      uint8 feeProtocol,
      bool unlocked
    );

  /// @notice Swap token0 for token1, or token1 for token0
  /// @dev The caller of this method receives a callback in the form of
  /// IUniswapV3SwapCallback#uniswapV3SwapCallback
  /// @param recipient The address to receive the output of the swap
  /// @param zeroForOne The direction of the swap, true for token0 to token1, false for token1 to
  /// token0
  /// @param amountSpecified The amount of the swap, which implicitly configures the swap as exact
  /// input (positive), or exact output (negative)
  /// @param sqrtPriceLimitX96 The Q64.96 sqrt price limit. If zero for one, the price cannot be
  /// less than this
  /// value after the swap. If one for zero, the price cannot be greater than this value after the
  /// swap
  /// @param data Any data to be passed through to the callback
  /// @return amount0 The delta of the balance of token0 of the pool, exact when negative, minimum
  /// when positive
  /// @return amount1 The delta of the balance of token1 of the pool, exact when negative, minimum
  /// when positive
  function swap(
    address recipient,
    bool zeroForOne,
    int256 amountSpecified,
    uint160 sqrtPriceLimitX96,
    bytes calldata data
  ) external returns (int256 amount0, int256 amount1);

  /// @notice The amounts of token0 and token1 that are owed to the protocol
  /// @dev Protocol fees will never exceed uint128 max in either token
  function protocolFees() external view returns (uint128 token0, uint128 token1);
}
