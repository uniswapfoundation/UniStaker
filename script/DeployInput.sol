// SPDX-License-Identifier: AGPL-3.0-only
// slither-disable-start reentrancy-benign

pragma solidity 0.8.23;

contract DeployInput {
  address constant UNISWAP_GOVERNOR = 0x0459f41c5f09BF678D9C07331894dE31d8C22255;
  address constant UNISWAP_GOVERNOR_TIMELOCK = 0x0459f41c5f09BF678D9C07331894dE31d8C22255;
  address constant UNISWAP_V3_FACTORY_ADDRESS = 0x4752ba5DBc23f44D87826276BF6Fd6b1C372aD24;
  address constant PAYOUT_TOKEN_ADDRESS = 0x2B9c54C1AA3d4365369db7412202F06aD47f1dF1; // WETH
  uint256 constant PAYOUT_AMOUNT = 10e18; // 10 (WETH)
  address constant STAKE_TOKEN_ADDRESS = 0xeC4f972a3585B4C72f095D3fD2E6385AFa41BaE8; // UNI
}
