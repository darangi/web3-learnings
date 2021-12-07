// contracts/router.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "hardhat/console.sol";

interface IKudiCoin is IERC20 {
  function transferToken(address to, uint256 amount) external returns(bool);
  function increaseAllowance(address _owner, address _spender, uint256 amount) external returns (bool);
}

interface ILiquidityPool  {
  function deposit(uint256 kdc, address account) external payable;
  function withdraw(address account) external;
  function swapForEth(address account, uint256 kdcAmount) external payable;
  function swapForKDC(address account) external payable;
  function getQuote(uint256 kdcAmount, uint256 ethAmount) external returns(uint256) ;
}

contract Router {
  IKudiCoin kdcContract;
  ILiquidityPool liquidityPoolContract;

  constructor(address _kdcContract, address _liquidityPoolContract) {
    kdcContract = IKudiCoin(_kdcContract);
    liquidityPoolContract = ILiquidityPool(_liquidityPoolContract);
  }

  function addLiquidity(uint256 _kdcAmount) external payable {
    require(kdcContract.balanceOf(msg.sender) > _kdcAmount, "INSUFFICIENT BALANCE");

    bool success = kdcContract.increaseAllowance(msg.sender, address(this), _kdcAmount);
    require(success, "ERROR ADDING LIQUIDITY");

    kdcContract.transferFrom(msg.sender, address(liquidityPoolContract), _kdcAmount);
    liquidityPoolContract.deposit{value: msg.value}(_kdcAmount, msg.sender);
  }

  function removeLiquidity() external {
    liquidityPoolContract.withdraw(msg.sender);
  }

  function getQuote(uint256 _kdcAmount, uint256 _eth) external returns (uint256) {
    uint256 conversion;

    if(_kdcAmount > 0) {
      conversion = liquidityPoolContract.getQuote(_kdcAmount, 0);
    }
    else {
      conversion = liquidityPoolContract.getQuote(0, _eth);
    }

    return conversion;
  }

  function trade(uint256 _kdcAmount) external payable {
    if(_kdcAmount > 0) {
      liquidityPoolContract.swapForEth(msg.sender, _kdcAmount);
    }
    else {
      liquidityPoolContract.swapForKDC{ value: msg.value }(msg.sender);
    }
  }

}
