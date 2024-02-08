// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.23;

import {Script} from "forge-std/Script.sol";

import {DeployInput} from "script/DeployInput.sol";
import {GovernorBravoDelegate} from "script/interfaces/GovernorBravoInterfaces.sol";

contract ProposeSetProtocolFee is Script, DeployInput {
  GovernorBravoDelegate constant GOVERNOR = GovernorBravoDelegate(UNISWAP_GOVERNOR);
  // TODO placeholder delegate: robert leshner
  // For testing purposes this should be different from other scripts
  address PROPOSER =
    vm.envOr("PROPOSER_ADDRESS", address(0x88FB3D509fC49B515BFEb04e23f53ba339563981));

  address[] public targets;
  uint256[] public values;
  string[] public signatures;
  bytes[] public calldatas;

  function addPool(address _v3FactoryOwner, address _pool, uint8 _feeProtocol0, uint8 _feeProtocol1)
    external
  {
    targets.push(_v3FactoryOwner);
    values.push(0);
    signatures.push("setFeeProtocol(address,uint8,uint8)");
    calldatas.push(abi.encode(_pool, _feeProtocol0, _feeProtocol1));
  }

  function propose() internal returns (uint256 _proposalId) {
    return GOVERNOR.propose(
      targets,
      values,
      signatures,
      calldatas,
      "Change Uniswap V3 factory owner and set pool protocol fees"
    );
  }

  /// @dev This script set protocol fees for whatever pools and fees are configured. This script
  /// should only be run after `UniStaker` and the `V3FactoryOwner` are deployed, and after the
  /// `V3FactoryOwner` becomes the owner of ther Uniswap v3 factory.
  function run() public returns (uint256 _proposalId) {
    // The expectation is the key loaded here corresponds to the address of the `proposer` above.
    // When running as a script, broadcast will fail if the key is not correct.
    uint256 _proposerKey = vm.envOr(
      "PROPOSER_PRIVATE_KEY",
      uint256(0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d)
    );
    vm.rememberKey(_proposerKey);

    vm.startBroadcast(PROPOSER);
    // TODO: should I put an example here? Or would we expect them to compose the pools in a
    // separate script
    _proposalId = propose();
    vm.stopBroadcast();
    return _proposalId;
  }
}