const { expect, assert } = require("chai");
const { ethers } = require("hardhat");

const toEther = (amount) => ethers.utils.parseEther(String(amount));

const Phase = {
  seed: 0,
  general: 1,
  open: 2,
}

describe("ICO contract", function() {
  let contract, owner, treasury, investor, anotherInvestor, accounts, liquidityPool;

  before(async function() {
    [owner, treasury, investor, anotherInvestor, ...accounts] = await ethers.getSigners();
    const Ico = await ethers.getContractFactory("Ico");
    contract = await Ico.deploy(treasury.address);

    const Liquidity = await ethers.getContractFactory("Liquidity");
    liquidityPool = await Liquidity.deploy(contract.address);
  })

  it("Should have a default phase as seed", async function() {
    expect(await contract.getCurrentPhase()).to.equal(Phase.seed);
  });

  it("Should throw an error when a non-whitlested investore tries to contribute", async function() {
    try {
      const amount = toEther(1500);
      await contract.connect(investor).contribute({ value: amount });

      assert.fail();
    }
    catch (ex) {
      expect(ex).to.not.be.null;
      expect(ex.message).to.contain("NOT_WHITELISTED");
    }
  })

  it("Should whitelist an investor", async function() {
    const trx = await contract.whiteListInvestor(investor.address);

    expect(trx).to.emit(contract, "InvestorWhiteListed").withArgs(investor.address);
  })

  it("Should allow funding to be paused/resumed", async function() {
    await contract.pauseFunding();
    let status = await contract.getFundingStatus();

    expect(status).to.be.true;

    await contract.resumeFunding();
    status = await contract.getFundingStatus();

    expect(status).to.be.false;
  })

  it("only allow owner to pause funding", async function() {
    try {
      await contract.connect(accounts[0]).pauseFunding();
      assert.fail();
    }
    catch (ex) {
      expect(ex.message).to.contain("caller is not the owner");
      expect(ex).to.not.be.null;
    }
  })

  it("only allow owner to resume funding", async function() {
    try {
      await contract.connect(accounts[0]).resumeFunding();
      assert.fail();
    }
    catch (ex) {
      expect(ex.message).to.contain("caller is not the owner");
      expect(ex).to.not.be.null;
    }
  })

  it("Should allow a whitelisted investor contribute", async function() {
    const amount = toEther(1500)
    const trx = await contract.connect(investor).contribute({ value: amount });

    const contributions = await contract.getTotalContributions();

    expect(amount.toString()).equal(contributions.toString());
    expect(trx).to.emit(contract, "Contributed").withArgs(amount)
  })

  it("Seed phase individual contribution should not exceed 1500 ether", async function() {
    try {
      await contract.whiteListInvestor(anotherInvestor.address);

      await contract.connect(anotherInvestor).contribute({ value: toEther(500) });
      await contract.connect(anotherInvestor).contribute({ value: toEther(500) });
      await contract.connect(anotherInvestor).contribute({ value: toEther(500) });
      await contract.connect(anotherInvestor).contribute({ value: toEther(500) });

      assert.fail();
    }
    catch (ex) {
      expect(ex).to.not.be.null;
      expect(ex.message).to.contain("INDIVIDUAL_LIMIT_EXCEEDED");
    }
  })

  it("General phase individual contribution should not exceed 1000 ether", async function() {
    try {
      await contract.movePhase(Phase.general);

      await contract.connect(investor).contribute({ value: toEther(1000) });
      await contract.connect(investor).contribute({ value: toEther(500) });
      assert.fail();
    }
    catch (ex) {
      expect(ex).to.not.be.null;
      expect(ex.message).to.contain("INDIVIDUAL_LIMIT_EXCEEDED");
    }
  })

  it("Should move to the general phase from seed phase", async function() {
    try {
      await contract.setPhase(Phase.seed);
      //use fresh accounts for contriubtions, it will definetly exceed the current contributions 1500 * about 16 accounts
      //and will throw an error
      for (const account of accounts) {
        await contract.whiteListInvestor(account.address);
        await contract.connect(account).contribute({ value: toEther(1500) });
      }

    }
    catch (ex) {
      expect(await contract.getCurrentPhase()).to.equal(Phase.general);
    }
  })

  it("Should move to the open phase from general phase", async function() {
    try {
      //it will definetly exceed the current contributions 1000 * about 16 accounts
      //and will throw an error
      for (const account of accounts.reverse()) {
        await contract.connect(account).contribute({ value: toEther(1000) });
      }

    }
    catch (ex) {
      expect(await contract.getCurrentPhase()).to.equal(Phase.open);
    }
  })

  it("Investor should withdraw their tokens", async function() {
    const trx = await contract.connect(investor).withdrawTokens();
    const balance = await contract.connect(investor).getTokenBalance();

    expect(trx).to.emit(contract, "TokensReleased").withArgs(balance.toString());
  })

  describe("Router + Liquidity pool", () => {
    before(async () => {
      Router = await ethers.getContractFactory("Router");
      router = await Router.deploy(contract.address, liquidityPool.address);
    })

    it("Move invested funds to liquidity pool", async function() {
      expect((await liquidityPool.balanceOf(liquidityPool.address))).to.equal(0);

      await contract.moveInvestedEthToLiquidityPool(liquidityPool.address);
      const balance = await liquidityPool.balanceOf(liquidityPool.address);

      expect(+balance.toString()).to.be.greaterThan(0);
    })

    it("Add liquidity", async function() {
      let balance = await liquidityPool.connect(investor).getTokenBalance();
      expect(+balance.toString()).to.equal(0);

      router.connect(investor).addLiquidity(toEther(10), { value: toEther(2) });

      balance = await liquidityPool.connect(investor).getTokenBalance();
      expect(+balance.toString()).to.be.greaterThan(0);
    })

    it("Swaps eth for KudiCoin", async () => {
      let currentBalance = await contract.connect(investor).getTokenBalance();

      await router.connect(investor).trade(0, { value: toEther(3) });

      let newBalance = await contract.connect(investor).getTokenBalance();

      expect(+newBalance.toString()).to.be.greaterThan(+currentBalance.toString());
    })

    it("Swaps KudiCoin for eth", async () => {
      let currentBalance = await ethers.provider.getBalance(investor.address);

      await router.connect(investor).trade(toEther(12));

      let newBalance = await ethers.provider.getBalance(investor.address);

      expect(+newBalance.toString()).to.be.greaterThan(+currentBalance.toString());
    })

    it("Remove liquidity", async function() {
      let balance = await liquidityPool.connect(investor).getTokenBalance();
      expect(+balance.toString()).to.be.greaterThan(0);

      router.connect(investor).removeLiquidity();

      balance = await liquidityPool.connect(investor).getTokenBalance();
      expect(+balance.toString()).to.be.eq(0);
    })

    // it("Accepts trade with a 1% fee and it gets shared by the liquidity providers", async () => {
    //   await router.connect(anotherInvestor).trade(0, { value: toEther(3) });
    //
    //   let currentKdcBalance = await contract.connect(investor).getTokenBalance();
    //   let currentEthBalance = await ethers.provider.getBalance(investor.address);
    //
    //   await router.connect(investor).removeLiquidity();
    //
    //   let newKdcBalance = await contract.connect(investor).getTokenBalance();
    //   let newEthBalance = await ethers.provider.getBalance(investor.address);
    // })
  })

})
