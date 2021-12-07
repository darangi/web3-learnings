// contracts/coin.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./libraries/Math.sol";
import "./lpt.sol";
import "./coin.sol";

interface IKudiCoin is IERC20 {
  function transferToken(address to, uint256 amount) external returns(bool);
  function increaseAllowance(address _owner, address _spender, uint256 amount) external returns (bool);

}


contract Liquidity is LPT {
    IKudiCoin kdcContract;
    uint256 ethReserve;
    uint256 kdcReserve;

    event LiquidityAdded(address, uint256);
    event LiquidityWithdrawn(address, uint256);
    event TokensSwapped(address);

    constructor(address _kdcContractAddress) {
      kdcContract = IKudiCoin(_kdcContractAddress);
    }

    function deposit(uint256 kdc, address account) external payable {
      uint256 liquidity;

      if(totalSupply() == 0) {
        liquidity = Math.sqrt(kdc * msg.value);
      }
      else {
        liquidity = Math.min(msg.value * totalSupply() / ethReserve, kdc * totalSupply() / kdcReserve );
      }

      mint(account, liquidity);

      emit LiquidityAdded(account, liquidity);

      _update();
    }

    function getTokenBalance() public view returns(uint){
      return balanceOf(msg.sender);
    }

    function withdraw(address account) external {
      uint256 liquidity = balanceOf(account);

      require(liquidity > 0, "No liquidity found");

      uint256 eth = ethReserve / (totalSupply() / liquidity);
      uint256 kdc =  kdcReserve / (totalSupply() / liquidity);

      burn(account, liquidity);

      (bool ethSent,) = account.call{value: eth}("");

      bool kdcSent = kdcContract.transfer(account,  kdc);

      require(kdcSent, "withdrawal failed");

      emit LiquidityWithdrawn(account, liquidity);

      _update();
    }

    function getQuote(uint256 kdcAmount, uint256 ethAmount) public returns(uint256) {
      uint256 product = ethReserve * kdcReserve;
      uint256 amountToTransfer;

      if(kdcAmount == 0) {
        uint ethAdded = ethReserve + ethAmount;
        amountToTransfer = kdcReserve - (product / ethAdded);
      }
      else if(ethAmount == 0) {
        uint kdcAdded = kdcReserve + kdcAmount;
        amountToTransfer = ethReserve - (product / kdcAdded);
      }
      else {
        revert("Specify token to get quote");
      }

      return amountToTransfer;
    }

    function swapForEth(address account, uint256 kdcAmount) external payable {
        uint256 tradingFee;
        uint256 amountToTransfer;

        amountToTransfer = getQuote(kdcAmount, 0);
        tradingFee = amountToTransfer / 100;

        (bool sent,) = account.call{value: amountToTransfer - tradingFee}("");
        require(sent, "SWAP FAILED");
        emit TokensSwapped(account);

        _update();
    }

    function swapForKDC(address account) external payable {
        uint256 tradingFee;
        uint256 amountToTransfer;

        amountToTransfer = getQuote(0, msg.value);
        tradingFee = amountToTransfer / 100;

        bool sent = kdcContract.transferToken(account, amountToTransfer - tradingFee);
        console.log(amountToTransfer - tradingFee, tradingFee);
        require(sent, "SWAP FAILED");
        emit TokensSwapped(account);

        _update();
    }

    function _update() private {
      // something about overflow that I don't understand in uniswaps contract, will figure it out later;
      kdcReserve = kdcContract.balanceOf(address(this));
      ethReserve = address(this).balance;

      // console.log(kdcReserve, ethReserve);
    }

}
