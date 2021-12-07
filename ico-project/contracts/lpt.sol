// contracts/coin.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "hardhat/console.sol";

contract LPT is ERC20, Ownable {
    constructor() ERC20("Liquidity Pool Token", "LPT"){}

    function mint(address account, uint256 amount) public {
      _mint(account, amount);
    }

    function burn(address account, uint256 amount) public {
      _burn(account, amount);
    }
}
