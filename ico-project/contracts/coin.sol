// contracts/coin.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "hardhat/console.sol";

contract KudiCoin is ERC20, Ownable {
    bool private _deductTax = false;
    address public _treasury;

    constructor(address treasury) ERC20("KudiCoin", "KDC") {
       _treasury = treasury;
       _mint(address(this), 500000 ether);
    }

    event TaxDeductionStatus(bool status);

    function transferToken(address to, uint256 amount) public returns(bool) {
      if (_deductTax) {
        uint tax = amount * 2/100;
        _transfer(address(this), to, amount - tax);
        _transfer(address(this), _treasury, tax);
      }
      else {
        _transfer(address(this), to, amount);
      }

      return true;
    }

    function increaseAllowance(address _owner, address _spender, uint256 _amount) external returns (bool) {
        _approve(_owner, _spender, allowance(_owner, _spender) + _amount);

        return true;
    }

    function taxDeductionOn() public onlyOwner {
      _deductTax = true;

      emit TaxDeductionStatus(_deductTax);
    }

    function taxDeductionFalse() public onlyOwner {
      _deductTax = false;

      emit TaxDeductionStatus(_deductTax);
    }

    function getTaxDeductionsStatus() public view returns(bool) {
        return _deductTax;
    }

    function getTreasuryBalance() public view onlyOwner returns(uint) {
      return balanceOf(_treasury);
    }
}
