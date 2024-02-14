// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.23;

import {Script} from "forge-std/Script.sol";

import {DeployInput} from "script/DeployInput.sol";
import {GovernorBravoDelegate} from "script/interfaces/GovernorBravoInterfaces.sol";

/// @dev A new proposal script that updates a pool's fee settings should inherit this abstract script and implement `getPoolFeeSettings`.
abstract contract ProposeProtocolFeesBase is Script, DeployInput {
  GovernorBravoDelegate constant GOVERNOR = GovernorBravoDelegate(UNISWAP_GOVERNOR);
  // The default proposer is uf.eek.eth.
  address _proposer =
    vm.envOr("PROPOSER_ADDRESS", address(0x0459f41c5f09BF678D9C07331894dE31d8C22255));

  /// @dev The targets for the proposal which should be the `V3FactoryOwner`.
  address[] public targets;
  /// @dev The values to pass into the proposal which should all be 0.
  uint256[] public values;
  /// @dev The function signatures that will be called when a proposal is executed. All of the signatures should be `setFeeProtocol(address,uint8,uint8)`.
  string[] public signatures;
  /// @dev The calldata for all of function calls in the proposal. These should match the `PoolFeeSettings` defined in `getPoolFeeSettings`.
  bytes[] public calldatas;

  /// @dev A struct to represent all of the information needed to update a pool's fees. Such as the target pool and the new fees for each token in the pool.
  struct PoolFeeSettings {
    address pool;
    uint8 feeProtocol0;
    uint8 feeProtocol1;
  }

  /// @dev A utility function that updates the targets, values, signatures, and calldatas for a proposal that will only update protocol fees for a list of pools. 
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

  /// @return A list of pool settings used to update protocol fees for each pool.
  /// @dev A new `ProposeProtocolFees` script should extend this base script and only implement this function to return a list of pools to be updated with their new settings. This function will return the appropriate pool settings in the `run` method and add them to the proposal that will be proposed.
  function getPoolFeeSettings() internal pure virtual returns (PoolFeeSettings[] memory);

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
  /// @dev This script sets protocol fees for whatever pools and fees are configured. This script
  /// should only be run after `UniStaker` and the `V3FactoryOwner` are deployed, and after the
  /// `V3FactoryOwner` becomes the owner of ther Uniswap v3 factory.
  function run(address _newV3FactoryOwner) public returns (uint256 _proposalId) {
    // The expectation is the key loaded here corresponds to the address of the `proposer` above.
    // When running as a script, broadcast will fail if the key is not correct.
    uint256 _proposerKey = vm.envUint("PROPOSER_PRIVATE_KEY");
    vm.rememberKey(_proposerKey);

    vm.startBroadcast(_proposer);
    PoolFeeSettings[] memory poolFeeSettings = getPoolFeeSettings();
    for (uint256 i = 0; i < poolFeeSettings.length; i++) {
      pushFeeSettingToProposalCalldata(
        _newV3FactoryOwner,
        poolFeeSettings[i].pool,
        poolFeeSettings[i].feeProtocol0,
        poolFeeSettings[i].feeProtocol1
      );
    }

    _proposalId = propose();
    vm.stopBroadcast();
    return _proposalId;
  }
}
