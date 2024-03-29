// SPDX-License-Identifier: AGPL-3.0-only
// slither-disable-start reentrancy-benign

pragma solidity 0.8.23;

contract DeployInput {
  address constant UNISWAP_GOVERNOR = 0x0459f41c5f09BF678D9C07331894dE31d8C22255;
  address constant UNISWAP_GOVERNOR_TIMELOCK = 0x0459f41c5f09BF678D9C07331894dE31d8C22255;
  address constant UNISWAP_V3_FACTORY_ADDRESS = 0x0227628f3F023bb0B980b67D528571c95c6DaC1c;
  address constant PAYOUT_TOKEN_ADDRESS = 0x0fFac752CD6Da16896c6163b3Aba4C8CF483D624; // WETH
  uint256 constant PAYOUT_AMOUNT = 10e18; // 10 (WETH)
  address constant STAKE_TOKEN_ADDRESS = 0xC796953C443f542728EEdf33AAb32753d3f7A91a; // UNI
}
