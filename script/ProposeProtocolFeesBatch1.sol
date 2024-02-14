// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.23;

import {Script} from "forge-std/Script.sol";

import {DeployInput} from "script/DeployInput.sol";
import {GovernorBravoDelegate} from "script/interfaces/GovernorBravoInterfaces.sol";
import {ProposeProtocolFeesBase} from "script/ProposeProtocolFeesBase.s.sol";

contract ProposeProtocolFeesBatch1 is ProposeProtocolFeesBase {
  /// @return An array of pools and new fee values to set
  function getPoolFeeSettings() internal pure override returns (PoolFeeSettings[] memory) {
    PoolFeeSettings[] memory poolFeeSettings = new PoolFeeSettings[](3);
    poolFeeSettings[0] = PoolFeeSettings(WBTC_WETH_3000_POOL, 10, 10);
    poolFeeSettings[1] = PoolFeeSettings(DAI_WETH_3000_POOL, 10, 10);
    poolFeeSettings[2] = PoolFeeSettings(DAI_USDC_100_POOL, 10, 10);
    return poolFeeSettings;
  }
}
