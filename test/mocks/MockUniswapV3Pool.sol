// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.23;

import {IUniswapV3PoolOwnerActions} from "src/interfaces/IUniswapV3PoolOwnerActions.sol";

contract MockUniswapV3Pool is IUniswapV3PoolOwnerActions {
  uint8 public lastParam__setFeeProtocol_feeProtocol0;
  uint8 public lastParam__setFeeProtocol_feeProtocol1;

  address public lastParam__collectProtocol_recipient;
  uint128 public lastParam__collectProtocol_amount0Requested;
  uint128 public lastParam__collectProtocol_amount1Requested;

  bool shouldReturnZeroFeesCollected = false;

  function setFeeProtocol(uint8 feeProtocol0, uint8 feeProtocol1) external {
    lastParam__setFeeProtocol_feeProtocol0 = feeProtocol0;
    lastParam__setFeeProtocol_feeProtocol1 = feeProtocol1;
  }

  function setReturnZeroFees(bool _should) external {
    shouldReturnZeroFeesCollected = _should;
  }

  function collectProtocol(address recipient, uint128 amount0Requested, uint128 amount1Requested)
    external
    returns (uint128 amount0, uint128 amount1)
  {
    lastParam__collectProtocol_recipient = recipient;
    lastParam__collectProtocol_amount0Requested = amount0Requested;
    lastParam__collectProtocol_amount1Requested = amount1Requested;
    if (shouldReturnZeroFeesCollected) return (0, 0);
    return (amount0Requested, amount1Requested);
  }
}
