// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.23;

import {Vm, Test, console2} from "forge-std/Test.sol";
import {Deploy} from "script/Deploy.s.sol";
import {DeployInput} from "script/DeployInput.sol";

import {V3FactoryOwner} from "src/V3FactoryOwner.sol";
import {UniStaker} from "src/UniStaker.sol";

contract DeployScriptTest is Test, DeployInput {
  function setUp() public {
    vm.createSelectFork(vm.rpcUrl("mainnet"));
  }

  function testFork_DeployStakingContracts() public {
    Deploy _deployScript = new Deploy();
    _deployScript.setUp();
    (V3FactoryOwner v3FactoryOwner, UniStaker uniStaker) = _deployScript.run();

    assertEq(v3FactoryOwner.admin(), UNISWAP_GOVERNOR_TIMELOCK);
    assertEq(address(v3FactoryOwner.FACTORY()), address(UNISWAP_V3_FACTORY_ADDRESS));
    assertEq(address(v3FactoryOwner.PAYOUT_TOKEN()), PAYOUT_TOKEN_ADDRESS);
    assertEq(v3FactoryOwner.payoutAmount(), PAYOUT_AMOUNT);
    assertEq(address(v3FactoryOwner.REWARD_RECEIVER()), address(uniStaker));

    assertEq(address(uniStaker.REWARD_TOKEN()), PAYOUT_TOKEN_ADDRESS);
    assertEq(address(uniStaker.STAKE_TOKEN()), STAKE_TOKEN_ADDRESS);
    assertEq(uniStaker.admin(), UNISWAP_GOVERNOR_TIMELOCK);
    assertTrue(uniStaker.isRewardNotifier(address(v3FactoryOwner)));
  }
}
