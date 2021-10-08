const { expect } = require("chai");
const { ethers } = require("hardhat");

const toEther = (amount) => ethers.utils.parseEther(String(amount));

describe("Token contract", function() {
  let contract, owner, treasury;

  it("Deployment should assign the total supply of tokens to the owner", async function() {
    [owner, treasury] = await ethers.getSigners();
    const KudiCoin = await ethers.getContractFactory("KudiCoin");

    contract = await KudiCoin.deploy(treasury.address);

    const ownerBalance = await contract.balanceOf(owner.address);
    expect(await contract.totalSupply()).to.equal(ownerBalance);
  });

  it("Tax deduction should be turned on and off", async function() {
    expect(await contract.getTaxDeductionsStatus()).to.be.false;

    await contract.toggleTaxDeduction();

    expect(await contract.getTaxDeductionsStatus()).to.be.true;

    await contract.toggleTaxDeduction();

    expect(await contract.getTaxDeductionsStatus()).to.be.false;
  });

  it("Transfer token to an account without deducting tax", async function() {
    const amount = toEther(10000);
    const trx = await contract.transferToken(owner.address, amount);

    expect(trx).to.emit(contract, 'Transfer').withArgs(owner.address, owner.address, amount);
  })

  it("Transfer token to an account with the tax deducted", async function() {
    await contract.toggleTaxDeduction();

    const amount = toEther(10000);
    const transferredAmount = amount.div(100).mul(2);

    await contract.transferToken(owner.address, amount);

    const currentBalance = await contract.getTreasuryBalance();

    expect(transferredAmount.toString()).to.equal(currentBalance.toString());
  })
});
