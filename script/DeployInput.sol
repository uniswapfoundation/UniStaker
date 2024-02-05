// SPDX-License-Identifier: AGPL-3.0-only
// slither-disable-start reentrancy-benign

pragma solidity 0.8.23;

contract DeployInput {
  address constant UNISWAP_GOVERNOR_TIMELOCK = 0x1a9C8182C09F50C8318d769245beA52c32BE35BC; // TODO
    // double check: currently the Uniswap timelock
  address constant UNISWAP_V3_OWNER_FACTORY_ADDRESS = 0x1F98431c8aD98523631AE4a59f267346ea31F984; // TODO
    // double check
  address constant PAYOUT_TOKEN_ADDRESS = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48; // TODO double
    // check: currently USDC
  address constant STAKE_TOKEN_ADDRESS = 0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984; // TODO double
    // check: currently the UNI token
  uint256 constant PAYOUT_AMOUNT = 500_000e6; // TODO double check: currently 50_000 USDC
}
