// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.23;

// This interface was created using cast interface. The contract can be found at
// https://etherscan.io/address/0x53a328f4086d7c0f1fa19e594c9b842125263026#code#F2#L182

interface GovernorBravoDelegate {
  type ProposalState is uint8;

  struct Receipt {
    bool hasVoted;
    uint8 support;
    uint96 votes;
  }

  event NewAdmin(address oldAdmin, address newAdmin);
  event NewImplementation(address oldImplementation, address newImplementation);
  event NewPendingAdmin(address oldPendingAdmin, address newPendingAdmin);
  event ProposalCanceled(uint256 id);
  event ProposalCreated(
    uint256 id,
    address proposer,
    address[] targets,
    uint256[] values,
    string[] signatures,
    bytes[] calldatas,
    uint256 startBlock,
    uint256 endBlock,
    string description
  );
  event ProposalExecuted(uint256 id);
  event ProposalQueued(uint256 id, uint256 eta);
  event ProposalThresholdSet(uint256 oldProposalThreshold, uint256 newProposalThreshold);
  event VoteCast(
    address indexed voter, uint256 proposalId, uint8 support, uint256 votes, string reason
  );
  event VotingDelaySet(uint256 oldVotingDelay, uint256 newVotingDelay);
  event VotingPeriodSet(uint256 oldVotingPeriod, uint256 newVotingPeriod);

  function BALLOT_TYPEHASH() external view returns (bytes32);
  function DOMAIN_TYPEHASH() external view returns (bytes32);
  function MAX_PROPOSAL_THRESHOLD() external view returns (uint256);
  function MAX_VOTING_DELAY() external view returns (uint256);
  function MAX_VOTING_PERIOD() external view returns (uint256);
  function MIN_PROPOSAL_THRESHOLD() external view returns (uint256);
  function MIN_VOTING_DELAY() external view returns (uint256);
  function MIN_VOTING_PERIOD() external view returns (uint256);
  function _acceptAdmin() external;
  function _initiate(uint256 proposalCount) external;
  function _setPendingAdmin(address newPendingAdmin) external;
  function _setProposalThreshold(uint256 newProposalThreshold) external;
  function _setVotingDelay(uint256 newVotingDelay) external;
  function _setVotingPeriod(uint256 newVotingPeriod) external;
  function admin() external view returns (address);
  function cancel(uint256 proposalId) external;
  function castVote(uint256 proposalId, uint8 support) external;
  function castVoteBySig(uint256 proposalId, uint8 support, uint8 v, bytes32 r, bytes32 s) external;
  function castVoteWithReason(uint256 proposalId, uint8 support, string memory reason) external;
  function execute(uint256 proposalId) external payable;
  function getActions(uint256 proposalId)
    external
    view
    returns (
      address[] memory targets,
      uint256[] memory values,
      string[] memory signatures,
      bytes[] memory calldatas
    );
  function getReceipt(uint256 proposalId, address voter) external view returns (Receipt memory);
  function implementation() external view returns (address);
  function initialProposalId() external view returns (uint256);
  function initialize(
    address timelock_,
    address uni_,
    uint256 votingPeriod_,
    uint256 votingDelay_,
    uint256 proposalThreshold_
  ) external;
  function latestProposalIds(address) external view returns (uint256);
  function name() external view returns (string memory);
  function pendingAdmin() external view returns (address);
  function proposalCount() external view returns (uint256);
  function proposalMaxOperations() external view returns (uint256);
  function proposalThreshold() external view returns (uint256);
  function proposals(uint256)
    external
    view
    returns (
      uint256 id,
      address proposer,
      uint256 eta,
      uint256 startBlock,
      uint256 endBlock,
      uint256 forVotes,
      uint256 againstVotes,
      uint256 abstainVotes,
      bool canceled,
      bool executed
    );
  function propose(
    address[] memory targets,
    uint256[] memory values,
    string[] memory signatures,
    bytes[] memory calldatas,
    string memory description
  ) external returns (uint256);
  function queue(uint256 proposalId) external;
  function quorumVotes() external view returns (uint256);
  function state(uint256 proposalId) external view returns (ProposalState);
  function timelock() external view returns (address);
  function uni() external view returns (address);
  function votingDelay() external view returns (uint256);
  function votingPeriod() external view returns (uint256);
}
