// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.23;

import {Script} from "forge-std/Script.sol";

import {DeployInput} from "script/DeployInput.sol";
import {GovernorBravoDelegate} from "script/interfaces/GovernorBravoInterfaces.sol";
import {ProposeSetProtocolFeeOnPools} from "script/ProposeSetProtocolFeeOnPools.s.sol";

contract ProposeSetProtocolFeeOnFirstPools is ProposeSetProtocolFeeOnPools {
  PoolFees[] public poolFeesArray;

  function newPoolFeeSettings() internal override returns (PoolFees[] memory) {
    poolFeesArray.push(PoolFees(WBTC_WETH_3000_POOL, 10, 10));
    poolFeesArray.push(PoolFees(DAI_WETH_3000_POOL, 10, 10));
    poolFeesArray.push(PoolFees(DAI_USDC_100_POOL, 10, 10));
    return poolFeesArray;
  }
}
