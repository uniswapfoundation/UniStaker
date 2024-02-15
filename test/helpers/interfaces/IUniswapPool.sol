// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.23;

interface IUniswapPool {
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
}
