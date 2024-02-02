// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.23;

import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {IGovernor} from "@openzeppelin/contracts/governance/IGovernor.sol";
import {Test} from "forge-std/Test.sol";

import {Deploy} from "script/Deploy.s.sol";
import {DeployInput} from "script/DeployInput.sol";
import {Propose} from "script/Propose.s.sol";
import {Constants} from "test/helpers/Constants.sol";
import {GovernorBravoDelegate} from "script/interfaces/GovernorBravoInterfaces.sol";
import {V3FactoryOwner} from "src/V3FactoryOwner.sol";
import {UniStaker} from "src/UniStaker.sol";

// 1. help vote on proposal and move it forward
abstract contract ProposalTest is Test, DeployInput, Constants {
  //----------------- State and Setup ----------- //
  uint256 uniswapProposalId;
  address[] delegates;
  UniStaker uniStaker;
  V3FactoryOwner v3FactoryOwner;
  GovernorBravoDelegate governor = GovernorBravoDelegate(UNISWAP_GOVERNOR_ADDRESS);

  function setUp() public virtual {
    //initialProposalCount = governor.proposalCount();

    uint256 _forkBlock = 17_927_962;
    vm.createSelectFork(vm.rpcUrl("mainnet"), _forkBlock);

    address[] memory _delegates = new address[](6);
    // Taken from https://www.tally.xyz/gov/pooltogether/delegates?sort=voting_power_desc.
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

    Propose _proposeScript = new Propose();
    // We override the deployer to use an alternate delegate, because in this context,
    // lonser.eth already has a live proposal
    //_proposeScript.overrideProposerForTests(0xFFb032E27b70DfAD518753BAAa77040F64df9840);
    //
    // Pass in deployed factory owner
    Deploy _deployScript = new Deploy();
    _deployScript.setUp();
    (v3FactoryOwner, uniStaker) = _deployScript.run();
    uniswapProposalId = _proposeScript.run(address(v3FactoryOwner));
  }
  //--------------- HELPERS ---------------//

  function _uniswapProposalStartBlock() internal view returns (uint256) {
    (,,, uint256 _startBlock,,,,,,) = governor.proposals(uniswapProposalId);
    return _startBlock;
  }

  function _uniswapProposalEndBlock() internal view returns (uint256) {
    (,,,, uint256 _endBlock,,,,,) = governor.proposals(uniswapProposalId);
    return _endBlock;
  }

  function _uniswapProposalEta() internal view returns (uint256) {
    (,, uint256 _eta,,,,,,,) = governor.proposals(uniswapProposalId);
    return _eta;
  }

  function _jumpToActiveUniswapProposal() internal {
    vm.roll(_uniswapProposalStartBlock() + 1);
  }

  function _jumpToUniswapVoteComplete() internal {
    vm.roll(_uniswapProposalEndBlock() + 1);
  }

  function _jumpPastProposalEta() internal {
    vm.roll(block.number + 1); // move up one block so we're not in the same block as when queued
    vm.warp(_uniswapProposalEta() + 1); // jump past the eta timestamp
  }

  function _delegatesVoteOnUniswapProposal(bool _support) internal {
    for (uint256 _index = 0; _index < delegates.length; _index++) {
      vm.prank(delegates[_index]);
      governor.castVote(uniswapProposalId, 1);
    }
  }

  function _passUniswapProposal() internal {
    _jumpToActiveUniswapProposal();
    _delegatesVoteOnUniswapProposal(true);
    _jumpToUniswapVoteComplete();
  }

  function _defeatUniswapProposal() internal {
    _jumpToActiveUniswapProposal();
    _delegatesVoteOnUniswapProposal(false);
    _jumpToUniswapVoteComplete();
  }

  function _passAndQueueUniswapProposal() internal {
    _passUniswapProposal();
    governor.queue(uniswapProposalId);
  }

  function _executeProposal() internal {
    _jumpPastProposalEta();
    governor.execute(uniswapProposalId);
  }

  function assertEq(IGovernor.ProposalState _actual, IGovernor.ProposalState _expected) internal {
    assertEq(uint8(_actual), uint8(_expected));
  }
}
