// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.23;

import {Script} from "forge-std/Script.sol";

import {DeployInput} from "script/DeployInput.sol";
import {GovernorBravoDelegate} from "script/interfaces/GovernorBravoInterfaces.sol";

contract ProposeSetProtocolFeeOnPools is Script, DeployInput {
  GovernorBravoDelegate constant GOVERNOR = GovernorBravoDelegate(UNISWAP_GOVERNOR);
  // The default proposer is uf.eek.eth.
  address _proposer =
    vm.envOr("PROPOSER_ADDRESS", address(0x0459f41c5f09BF678D9C07331894dE31d8C22255));

  address[] public targets;
  uint256[] public values;
  string[] public signatures;
  bytes[] public calldatas;

  function pushFeeSettingToProposalCalldata(
    address _v3FactoryOwner,
    address _pool,
    uint8 _feeProtocol0,
    uint8 _feeProtocol1
  ) internal {
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

  /// @param _newV3FactoryOwner The new factory owner which should have be the recently deployed.
  /// @dev This script set protocol fees for whatever pools and fees are configured. This script
  /// should only be run after `UniStaker` and the `V3FactoryOwner` are deployed, and after the
  /// `V3FactoryOwner` becomes the owner of ther Uniswap v3 factory.
  function run(address _newV3FactoryOwner) public returns (uint256 _proposalId) {
    // The expectation is the key loaded here corresponds to the address of the `proposer` above.
    // When running as a script, broadcast will fail if the key is not correct.
    uint256 _proposerKey = vm.envUint("PROPOSER_PRIVATE_KEY");
    vm.rememberKey(_proposerKey);

    vm.startBroadcast(_proposer);
    // These are example pools to modify and the below `addPool` lines should be modified
    // if different values are needed.
    pushFeeSettingToProposalCalldata(_newV3FactoryOwner, WBTC_WETH_3000_POOL, 10, 10);
    pushFeeSettingToProposalCalldata(_newV3FactoryOwner, DAI_WETH_3000_POOL, 10, 10);
    pushFeeSettingToProposalCalldata(_newV3FactoryOwner, DAI_USDC_100_POOL, 10, 10);

    _proposalId = propose();
    vm.stopBroadcast();
    return _proposalId;
  }
}
