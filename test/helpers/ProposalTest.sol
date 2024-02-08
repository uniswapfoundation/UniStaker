// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.23;

import {Test} from "forge-std/Test.sol";

import {Deploy} from "script/Deploy.s.sol";
import {DeployInput} from "script/DeployInput.sol";
import {ProposeFactorySetOwner} from "script/ProposeFactorySetOwner.s.sol";
import {ProposeSetProtocolFee} from "script/ProposeSetProtocolFee.s.sol";
import {Constants} from "test/helpers/Constants.sol";
import {GovernorBravoDelegate} from "script/interfaces/GovernorBravoInterfaces.sol";
import {V3FactoryOwner} from "src/V3FactoryOwner.sol";
import {UniStaker} from "src/UniStaker.sol";

abstract contract ProposalTest is Test, DeployInput, Constants {
  //----------------- State and Setup ----------- //
  uint256 setOwnerProposalId;
  uint256 setFeeProposalId;
  address[] delegates;
  UniStaker uniStaker;
  V3FactoryOwner v3FactoryOwner;
  GovernorBravoDelegate governor = GovernorBravoDelegate(UNISWAP_GOVERNOR_ADDRESS);

  function setUp() public virtual {
    vm.createSelectFork(vm.rpcUrl("mainnet"));

    address[] memory _delegates = new address[](6);
    // Taken from https://www.tally.xyz/gov/uniswap/delegates.
    // If you update these delegates (including updating order in the array),
    // make sure to update any tests that reference specific delegates. The last delegate is the
    // proposer and lower in the voting power than the above link.
    _delegates[0] = 0x76f54Eeb0D33a2A2c5CCb72FE12542A56f35d67C;
    _delegates[1] = 0x8E4ED221fa034245F14205f781E0b13C5bd6a42E;
    _delegates[2] = 0xe7925D190aea9279400cD9a005E33CEB9389Cc2b;
    _delegates[3] = 0x1d8F369F05343F5A642a78BD65fF0da136016452;
    _delegates[4] = 0xe02457a1459b6C49469Bf658d4Fe345C636326bF;
    _delegates[5] = 0x8962285fAac45a7CBc75380c484523Bb7c32d429;
    for (uint256 i; i < _delegates.length; i++) {
      address _delegate = _delegates[i];
      delegates.push(_delegate);
    }

    ProposeFactorySetOwner _proposeOwnerScript = new ProposeFactorySetOwner();
    ProposeSetProtocolFee _proposeFeeScript = new ProposeSetProtocolFee();
    Deploy _deployScript = new Deploy();

    _deployScript.setUp();

    (v3FactoryOwner, uniStaker) = _deployScript.run();
    setOwnerProposalId = _proposeOwnerScript.run(address(v3FactoryOwner));

    // TODO: Placeholder pools for after launch
    _proposeFeeScript.addPool(address(v3FactoryOwner), WBTC_WETH_3000_POOL, 10, 10);
    _proposeFeeScript.addPool(address(v3FactoryOwner), DAI_WETH_3000_POOL, 10, 10);
    _proposeFeeScript.addPool(address(v3FactoryOwner), DAI_USDC_100_POOL, 10, 10);

    setFeeProposalId = _proposeFeeScript.run();
  }
  //--------------- HELPERS ---------------//

  function _proposalStartBlock(uint256 _proposalId) internal view returns (uint256) {
    (,,, uint256 _startBlock,,,,,,) = governor.proposals(_proposalId);
    return _startBlock;
  }

  function _proposalEndBlock(uint256 _proposalId) internal view returns (uint256) {
    (,,,, uint256 _endBlock,,,,,) = governor.proposals(_proposalId);
    return _endBlock;
  }

  function _proposalEta(uint256 _proposalId) internal view returns (uint256) {
    (,, uint256 _eta,,,,,,,) = governor.proposals(_proposalId);
    return _eta;
  }

  function _jumpToActiveProposal(uint256 _proposalId) internal {
    vm.roll(_proposalStartBlock(_proposalId) + 1);
  }

  function _jumpToVoteComplete(uint256 _proposalId) internal {
    vm.roll(_proposalEndBlock(_proposalId) + 1);
  }

  function _jumpPastProposalEta(uint256 _proposalId) internal {
    vm.roll(block.number + 1); // move up one block so we're not in the same block as when queued
    vm.warp(_proposalEta(_proposalId) + 1); // jump past the eta timestamp
  }

  function _delegatesVoteOnUniswapProposal(uint256 _proposalId, uint8 _support) internal {
    for (uint256 _index = 0; _index < delegates.length; _index++) {
      vm.prank(delegates[_index]);
      governor.castVote(_proposalId, _support);
    }
  }

  function _passProposals() internal {
    _jumpToActiveProposal(setFeeProposalId);
    _delegatesVoteOnUniswapProposal(setOwnerProposalId, 1);
    _delegatesVoteOnUniswapProposal(setFeeProposalId, 1);
    _jumpToVoteComplete(setFeeProposalId);
  }

  function _defeatUniswapProposal() internal {
    _jumpToActiveProposal(setFeeProposalId);
    _delegatesVoteOnUniswapProposal(setOwnerProposalId, 0);
    _delegatesVoteOnUniswapProposal(setFeeProposalId, 0);
    _jumpToVoteComplete(setFeeProposalId);
  }

  function _passAndQueueProposals() internal {
    _passProposals();
    governor.queue(setOwnerProposalId);
    governor.queue(setFeeProposalId);
  }

  function _executeProposal(uint256 _proposalId) internal {
    _jumpPastProposalEta(_proposalId);
    governor.execute(_proposalId);
  }
}
