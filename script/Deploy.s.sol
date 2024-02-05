// SPDX-License-Identifier: AGPL-3.0-only
// slither-disable-start reentrancy-benign

pragma solidity 0.8.23;

import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";
import {Script} from "forge-std/Script.sol";

import {DeployInput} from "script/DeployInput.sol";
import {UniStaker} from "src/UniStaker.sol";
import {V3FactoryOwner} from "src/V3FactoryOwner.sol";
import {IERC20Delegates} from "src/interfaces/IERC20Delegates.sol";
import {INotifiableRewardReceiver} from "src/interfaces/INotifiableRewardReceiver.sol";
import {IUniswapV3FactoryOwnerActions} from "src/interfaces/IUniswapV3FactoryOwnerActions.sol";

contract Deploy is Script, DeployInput {
  function run() public returns (V3FactoryOwner, UniStaker) {
    vm.startBroadcast(msg.sender);
    // Deploy the staking contract
    UniStaker uniStaker =
      new UniStaker(IERC20(PAYOUT_TOKEN_ADDRESS), IERC20Delegates(STAKE_TOKEN_ADDRESS), msg.sender);

    // Deploy a new owner for the V3 factory owner actions contract.
    // A separate par of the proposal will switch the owner of the
	// v3 factory owner actions contract contract to the v3 factory owner.
    V3FactoryOwner v3FactoryOwner = new V3FactoryOwner(
      UNISWAP_GOVERNOR_TIMELOCK,
      IUniswapV3FactoryOwnerActions(UNISWAP_V3_OWNER_FACTORY_ADDRESS),
      IERC20(PAYOUT_TOKEN_ADDRESS),
      PAYOUT_AMOUNT,
      INotifiableRewardReceiver(uniStaker)
    );

    // Set the v3FactoryOwner to be the rewards notifier
    uniStaker.setRewardsNotifier(address(v3FactoryOwner), true);

    // Change the Staking contract to be the governor timelock
    uniStaker.setAdmin(UNISWAP_GOVERNOR_TIMELOCK);
    vm.stopBroadcast();

    return (v3FactoryOwner, uniStaker);
  }
}
