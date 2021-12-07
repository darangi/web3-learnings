//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "hardhat/console.sol";

contract NFTMarketplace {
  mapping (uint => address) public tokens;
  uint price = 2 ether;

  function getPrice(uint nftId) external view returns (uint) {
    return price;
  }

  function buy(uint nftId) external payable {
    tokens[nftId] = msg.sender;
  }
}
