// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.23;

import {IUniswapV3FactoryOwnerActions} from "src/interfaces/IUniswapV3FactoryOwnerActions.sol";

contract MockUniswapV3Factory is IUniswapV3FactoryOwnerActions {
  address public lastParam__setOwner_owner;

  uint24 public lastParam__enableFeeAmount_fee;
  int24 public lastParam__enableFeeAmount_tickSpacing;

  function owner() external view returns (address) {
    return lastParam__setOwner_owner;
  }

  function setOwner(address _owner) external {
    lastParam__setOwner_owner = _owner;
  }

  function enableFeeAmount(uint24 fee, int24 tickSpacing) external {
    lastParam__enableFeeAmount_fee = fee;
    lastParam__enableFeeAmount_tickSpacing = tickSpacing;
  }
}
