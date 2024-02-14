// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.23;

import {Script} from "forge-std/Script.sol";

import {DeployInput} from "script/DeployInput.sol";
import {GovernorBravoDelegate} from "script/interfaces/GovernorBravoInterfaces.sol";
import {ProposeProtocolFeesBase} from "script/ProposeProtocolFeesBase.s.sol";

contract ProposeProtocolFeesBatch1 is ProposeProtocolFeesBase {
  // TODO Double check these are the right pools
  address constant WBTC_WETH_3000_POOL = 0xCBCdF9626bC03E24f779434178A73a0B4bad62eD;
  address constant DAI_WETH_3000_POOL = 0xC2e9F25Be6257c210d7Adf0D4Cd6E3E881ba25f8;
  address constant DAI_USDC_100_POOL = 0x5777d92f208679DB4b9778590Fa3CAB3aC9e2168;

  /// @return An array of pools and new fee values to set
  function getPoolFeeSettings() internal pure override returns (PoolFeeSettings[] memory) {
    PoolFeeSettings[] memory poolFeeSettings = new PoolFeeSettings[](3);
    poolFeeSettings[0] = PoolFeeSettings(WBTC_WETH_3000_POOL, 10, 10);
    poolFeeSettings[1] = PoolFeeSettings(DAI_WETH_3000_POOL, 10, 10);
    poolFeeSettings[2] = PoolFeeSettings(DAI_USDC_100_POOL, 10, 10);
    return poolFeeSettings;
  }
}
