// contracts/coin.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract KudiCoin is ERC20, Ownable {
    bool private _deductTax = false;
    address private _treasury;

    constructor(address treasury) ERC20("KudiCoin", "KDC") {
       _treasury = treasury;
       _mint(msg.sender, 500000 ether);
    }

    event TaxDeductionStatus(bool status);

    function transferToken(address to, uint256 amount) public {
      if (_deductTax) {
        uint tax = amount * 2/100;
        transfer(to, amount - tax);
        transfer(_treasury, tax);
      }
      else {
        transfer(to, amount);
      }
    }

    function toggleTaxDeduction() public onlyOwner {
      _deductTax = !_deductTax;

      emit TaxDeductionStatus(_deductTax);
    }

    function getTaxDeductionsStatus() public view returns(bool) {
        return _deductTax;
    }

    function getTreasuryBalance() public view onlyOwner returns(uint) {
      return balanceOf(_treasury);
    }
}
