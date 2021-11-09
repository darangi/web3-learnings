//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "hardhat/console.sol";

interface NftMarketplace {
    function getPrice(uint256 nftId) external view returns (uint256);

    function buy(uint256 nftId) external;
}

contract Dao {
    uint256 private MEMBERSHIP_COST = 1 ether;
    uint256 private proposalId = 0;
    uint256 private VOTING_DEADLINE = 3 days;
    uint256 private totalMembers;

    struct Proposal {
      uint256 id;
      address proposer;

      address nftMarket;
      uint256 nftId;

      bool executed;
      bool failed;

      uint256 yays;
      uint256 nays;
      mapping(address => bool) hasVoted;

      uint256 createdAt;
    }

    enum VoteType {
      Yes,
      No
    }

    mapping(address => bool) private members;
    mapping(uint256 => Proposal) private proposals;
    mapping(address => address) private delegates;
    mapping(address => uint256) private votingPower;

    event MemberShipPurchased(address);
    event ProposalSubmitted(uint256);
    event Voted(uint256, VoteType);
    event ProposalStatus(string);
    event NFTpurchased(uint256, uint256);
    event VoteDelegated(address, address);

    modifier onlyMembers () {
      require(members[msg.sender], "You need to purchase a membership for 1 eth");

      _;
    }

    function delegate(address account) public onlyMembers{
      address old = delegates[msg.sender];
      votingPower[old]--;
      votingPower[account]++;
      delegates[msg.sender] = account;

      emit VoteDelegated(msg.sender, account);
    }

    function purchaseMemberShip(uint256 cost) public payable {
      require(cost == MEMBERSHIP_COST, "Memberhip costs 1eth");

      members[msg.sender] = true;
      votingPower[msg.sender]++;
      delegates[msg.sender] = msg.sender;
      totalMembers = totalMembers + 1;

      emit MemberShipPurchased(msg.sender);
    }

    function propose(address nftMarket, uint256 nftId) public onlyMembers returns (uint256) {
      Proposal storage proposal = proposals[++proposalId];
      proposal.id = proposalId;
      proposal.nftId = nftId;
      proposal.nftMarket = nftMarket;
      proposal.proposer = msg.sender;
      proposal.createdAt = block.timestamp;

      emit ProposalSubmitted(proposalId);

      return proposalId;
    }

    function vote(uint256 proposalId, VoteType vote) external onlyMembers {
      Proposal storage proposal = proposals[proposalId];
      require(proposal.id != 0, "Proposal not found");
      require(!proposal.hasVoted[msg.sender], "Member voted already");
      require(block.timestamp < proposal.createdAt + VOTING_DEADLINE, "Voting ended");

      uint256 weight = votingPower[msg.sender];

      if(vote == VoteType.Yes) {
        proposal.yays = proposal.yays + weight;
      }
      else {
        proposal.nays = proposal.nays + weight;
      }

      proposal.hasVoted[msg.sender] = true;

      emit Voted(proposalId, vote);
    }

    function execute(uint256 proposalId) external onlyMembers {
      Proposal storage proposal = proposals[proposalId];

      require(block.timestamp >= proposal.createdAt + VOTING_DEADLINE, "Still voting");
      require(!proposal.executed, "Proposal executed already");
      require(!proposal.failed, "Proposal has failed");

      // check if vote count safitisfys 25% quorom
      uint256 quorom = totalMembers * 25/100;
      uint256 totalVotes = proposal.yays + proposal.nays;
      require(totalVotes >= quorom, "quorom not safitisfied");

      if(proposal.yays > proposal.nays) {
        uint256 price = NftMarketplace(proposal.nftMarket).getPrice(proposal.nftId);

        require(address(this).balance >= price, "Insufficient funds");

        // execute proposal
        proposal.executed = true;
        NftMarketplace(proposal.nftMarket).buy(proposal.nftId);

        emit NFTpurchased(proposal.id, proposal.nftId);
      }
      else {
        proposal.failed = true;
      }

      emit ProposalStatus(proposal.failed ? "FAILED" : "EXECUTED");
    }
}
