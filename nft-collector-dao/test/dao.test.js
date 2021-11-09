const { expect, assert } = require("chai");
const { ethers, network } = require("hardhat");

describe("Dao", async function() {
  const DAYS = 345600; //4 days in seconds

  let daoContract, marketPlaceContract, member, anotherMember, otherMembers, notAmember, proposalId = 1, proposal, voteType = {
    yes: 0,
    no: 1
  };;

  const toEther = (amount) => ethers.utils.parseEther(String(amount));

  //move block time forward or backwards
  const timeTravel = async (daysInSecs) => {
    await network.provider.send('evm_increaseTime', [daysInSecs])
    await network.provider.send('evm_mine')
  }

  const joinDAO = async () => {
    for (var member of otherMembers) {
      await daoContract.connect(member).purchaseMemberShip(toEther(1));
    }
  }

  const castVote = async (voteType) => {
    for (var member of otherMembers) {
      await daoContract.connect(member).vote(proposalId, voteType);
    }
  }

  before(async function() {
    [member, anotherMember, notAmember, ...otherMembers] = await ethers.getSigners();

    const Dao = await ethers.getContractFactory("Dao");
    daoContract = await Dao.deploy();


    const NFTmarketPlace = await ethers.getContractFactory("NFTMarketplace");
    marketPlaceContract = await NFTmarketPlace.deploy();
  });

  describe("Membership", () => {
    it("Should purchase membership for 1 eth", async function() {
      const cost = toEther(1);
      const trx = await daoContract.connect(member).purchaseMemberShip(cost);

      expect(trx).to.emit(daoContract, "MemberShipPurchased").withArgs(member.address);

      try {
        await daoContract.purchaseMemberShip(cost);

        assert.fail();
      }
      catch (ex) {
        expect(ex).to.not.be.null;
        expect(ex.message).to.contain("Already a member");
      }
    });

    it("Should throw an error when membership is purchased with less than 1 eth", async function() {
      try {
        const cost = toEther(0.8);
        await daoContract.purchaseMemberShip(cost);

        assert.fail();
      }
      catch (ex) {
        expect(ex).to.not.be.null;
        expect(ex.message).to.contain("Memberhip costs 1eth");
      }
    });
  })

  describe("Proposal", () => {
    it("Submit a proposal", async function() {
      proposal = {
        nftMarket: marketPlaceContract.address,
        nftId: 007,
      };

      try {
        await daoContract.connect(notAmember).propose(proposal.nftMarket, proposal.nftId);

        assert.fail();
      }
      catch (ex) {
        expect(ex).to.not.be.null;
        expect(ex.message).to.contain("You need to purchase a membership for 1 eth");
      }

      const trx = await daoContract.connect(member).propose(proposal.nftMarket, proposal.nftId);

      expect(trx).to.emit(daoContract, "ProposalSubmitted").withArgs(proposalId);
    })

    it("Prevents non-members from voting on a proposal", async function() {
      try {
        await daoContract.connect(notAmember).vote(proposalId, voteType.yes);

        assert.fail();
      }
      catch (ex) {
        expect(ex).to.not.be.null;
        expect(ex.message).to.contain("You need to purchase a membership for 1 eth");
      }
    })

    it("Prevents non existent proposals to be voted on", async function() {
      try {
        await daoContract.connect(member).vote(2000, voteType.yes);

        assert.fail();
      }
      catch (ex) {
        expect(ex).to.not.be.null;
        expect(ex.message).to.contain("Proposal not found");
      }
    })

    it("Prevents multiple votes by a member", async function() {
      try {
        await daoContract.connect(member).vote(proposalId, voteType.yes);
        await daoContract.connect(member).vote(proposalId, voteType.yes);

        assert.fail();
      }
      catch (ex) {
        expect(ex).to.not.be.null;
        expect(ex.message).to.contain("Member voted already");
      }
    })

    it("Prevents voting on a proposal that has expired", async function() {
      try {
        //4 days forward
        await timeTravel(DAYS);

        await daoContract.connect(anotherMember).purchaseMemberShip(toEther(1));
        await daoContract.connect(anotherMember).vote(proposalId, voteType.yes);

        assert.fail();
      }
      catch (ex) {
        expect(ex).to.not.be.null;
        expect(ex.message).to.contain("Voting ended");
      }
    })

    it("Delegate vote to another member", async function() {

      const trx = await daoContract.connect(member).delegate(anotherMember.address);

      expect(trx).to.emit(daoContract, "VoteDelegated").withArgs(member.address, anotherMember.address);
    })

    it("Allows a member to vote", async function() {
      // need to reset block time to current time since it moved by 4days in line 130
      await timeTravel(-DAYS);

      const trx = await daoContract.connect(anotherMember).vote(proposalId, voteType.yes);

      expect(trx).to.emit(daoContract, "Voted").withArgs(proposalId, voteType.yes);
    })

    it("Execute proposal only if deadline has reached", async function() {
      try {
        await daoContract.connect(member).execute(proposalId);

        assert.fail();
      }
      catch (ex) {
        expect(ex).to.not.be.null;
        expect(ex.message).to.contain("Still voting");
      }
    })

    it("Execute proposal only if quorom is satisfied", async function() {
      // add more members to the DAO
      await joinDAO();


      await timeTravel(DAYS);

      try {
        await daoContract.connect(member).execute(proposalId);
      }
      catch (ex) {
        expect(ex).to.not.be.null;
        expect(ex.message).to.contain("quorom not safitisfied");
      }

      //reset time to current time and cast member votes
      await timeTravel(-DAYS);
      await castVote(voteType.yes);

      await timeTravel(DAYS);
      const trx = await daoContract.connect(member).execute(proposalId);

      expect(trx).to.emit(daoContract, "NFTpurchased").withArgs(proposalId, proposal.nftId);
    })
  })
});
