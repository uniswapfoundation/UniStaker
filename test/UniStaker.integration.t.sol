// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.23;

import {Vm, Test, console2} from "forge-std/Test.sol";
import {Deploy} from "script/Deploy.s.sol";
import {DeployInput} from "script/DeployInput.s.sol";

contract DeployScriptTest is Test, DeployInput {
  function setUp() public {
    vm.createSelectFork(vm.rpcUrl("mainnet"));
  }

  function testFork_DeployStakingContracts() public {
    Deploy _deployScript = new Deploy();
	// Assert values are correct
    //(V3FactoryOwner v3FactoryOwner, UniStaker uniStaker) =_deployScript.run();
    _deployScript.run();
  }
}
