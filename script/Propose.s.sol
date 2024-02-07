// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.23;

import {Script} from "forge-std/Script.sol";

import {DeployInput} from "script/DeployInput.sol";
import {GovernorBravoDelegate} from "script/interfaces/GovernorBravoInterfaces.sol";

contract Propose is Script, DeployInput {
  GovernorBravoDelegate constant GOVERNOR =
    GovernorBravoDelegate(0x408ED6354d4973f66138C91495F2f2FCbd8724C3); // Mainnet governor
  // TODO placeholder delegate: jessewldn
  address PROPOSER = 0xe7925D190aea9279400cD9a005E33CEB9389Cc2b;

  function propose(address _v3FactoryOwner) internal returns (uint256 _proposalId) {
    address[] memory _targets = new address[](4);
    uint256[] memory _values = new uint256[](4);
    string[] memory _signatures = new string[](4);
    bytes[] memory _calldatas = new bytes[](4);

    _targets[0] = UNISWAP_V3_FACTORY_ADDRESS;
    _values[0] = 0;
    _signatures[0] = "setOwner(address)";
    _calldatas[0] = abi.encode(address(_v3FactoryOwner));

    _targets[1] = _v3FactoryOwner;
    _values[1] = 0;
    _signatures[1] = "setFeeProtocol(address,uint8,uint8)";
    // TODO: placeholder fees
    // wbtc-weth 0.3%
    _calldatas[1] = abi.encode(WBTC_WETH_3000_POOL, uint8(10), uint8(10));

    _targets[2] = _v3FactoryOwner;
    _values[2] = 0;
    _signatures[2] = "setFeeProtocol(address,uint8,uint8)";
    // TODO: placeholder fees
    // dai-weth 0.3%
    _calldatas[2] = abi.encode(DAI_WETH_3000_POOL, 10, 10);

    _targets[3] = _v3FactoryOwner;
    _values[3] = 0;
    _signatures[3] = "setFeeProtocol(address,uint8,uint8)";
    // TODO: placeholder fees
    // dai-usdc 0.01%
    _calldatas[3] = abi.encode(DAI_USDC_100_POOL, 10, 10);

    return GOVERNOR.propose(
      _targets,
      _values,
      _signatures,
      _calldatas,
      "Change Uniswap V3 factory owner and set pool protocol fees"
    );
  }

  /// @dev After the UniStaker and V3FactoryOwner contracts are deployed a delegate should run this
  /// script to create a proposal to change the Uniswap v3 factory owner and enable protocol fees
  /// for select pools.
  function run(address v3FactoryOwner) public returns (uint256 _proposalId) {
    // The expectation is the key loaded here corresponds to the address of the `proposer` above.
    // When running as a script, broadcast will fail if the key is not correct.
    uint256 _proposerKey = vm.envOr(
      "PROPOSER_PRIVATE_KEY",
      uint256(0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d)
    );
    vm.rememberKey(_proposerKey);

    vm.startBroadcast(PROPOSER);
    _proposalId = propose(v3FactoryOwner);
    vm.stopBroadcast();
    return _proposalId;
  }
}
