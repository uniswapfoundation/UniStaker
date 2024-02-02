// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.23;

import {ISwapRouter} from "v3-periphery/interfaces/ISwapRouter.sol";

contract Constants {
  address constant UNISWAP_GOVERNOR_ADDRESS = 0x408ED6354d4973f66138C91495F2f2FCbd8724C3;
  address constant WBTC_WETH_3000_POOL = 0xCBCdF9626bC03E24f779434178A73a0B4bad62eD;
  address constant DAI_WETH_3000_POOL = 0xC2e9F25Be6257c210d7Adf0D4Cd6E3E881ba25f8;
  address constant DAI_USDC_100_POOL = 0x5777d92f208679DB4b9778590Fa3CAB3aC9e2168;

  address constant WETH_ADDRESS = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2; // use deposit
  address constant DAI_ADDRESS = 0x6B175474E89094C44Da98b954EedeAC495271d0F; // mint with auth
  address constant USDC_ADDRESS = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48; //  mint only minters
  ISwapRouter constant UNISWAP_V3_SWAP_ROUTER =
    ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);
}
