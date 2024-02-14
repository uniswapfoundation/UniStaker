// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.23;

import {Script} from "forge-std/Script.sol";

import {DeployInput} from "script/DeployInput.sol";
import {GovernorBravoDelegate} from "script/interfaces/GovernorBravoInterfaces.sol";
import {ProposeSetProtocolFeeOnPools} from "script/ProposeSetProtocolFeeOnPools.s.sol";

contract ProposeNewFeesOnWbtcWethDaiWethAndDaiUsdcPools is ProposeSetProtocolFeeOnPools {
  PoolFeeSettings[] public poolFeeSettings;

  function getPoolFeeSettings() internal override returns (PoolFeeSettings[] memory) {
    poolFeeSettings.push(PoolFeeSettings(WBTC_WETH_3000_POOL, 10, 10));
    poolFeeSettings.push(PoolFeeSettings(DAI_WETH_3000_POOL, 10, 10));
    poolFeeSettings.push(PoolFeeSettings(DAI_USDC_100_POOL, 10, 10));
    return poolFeeSettings;
  }
}
