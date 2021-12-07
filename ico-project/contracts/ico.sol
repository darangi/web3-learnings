//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "hardhat/console.sol";

import "./coin.sol";
import "./liquidity-pool.sol";

interface ILiquidityPool {
    function deposit(uint256 kdc, address account) external payable;
}

contract Ico is KudiCoin {

    bool private icoPaused = false;

    enum Phase {
      seed,
      general,
      open
    }

    Phase private currentPhase = Phase.seed;

    uint goal = 30000 ether;
    uint totalContributions;

    mapping(address => bool) private whiteListedInvestors;
    mapping(address => uint) private totalIndividualContributions;
    mapping(address => mapping(Phase => uint)) private individualContributions;
    mapping(Phase => uint) private phaseContributions;
    mapping(Phase => uint) private phaseGoal;
    mapping(Phase => uint) private individualLimit;

    event InvestorWhiteListed(address investor);
    event Contributed(uint amount);
    event PhaseMoved(Phase phase);
    event TokensReleased(uint amount);

    constructor(address treasury) KudiCoin(treasury) {
      phaseGoal[Phase.seed] = 15000 ether;
      phaseGoal[Phase.general] = 30000 ether;
      individualLimit[Phase.seed] = 1500 ether;
      individualLimit[Phase.general] = 1000 ether;
    }

    modifier onlyFoward(Phase nextPhase) {
      Phase newPhase;
      if (currentPhase == Phase.seed) newPhase = Phase.general;
      else if (currentPhase == Phase.general) newPhase = Phase.open;

      require(newPhase == nextPhase, "WRONG_PHASE");
      _;
    }

    modifier isWhiteListed() {
      if (currentPhase == Phase.seed && !whiteListedInvestors[msg.sender]) {
        revert("NOT_WHITELISTED");
      }
      _;
    }

    modifier icoActive() {
      require(icoPaused == false, "ICO_PAUSED");
      _;
    }

    modifier canContribute() {
      if (currentPhase != Phase.open && individualContributions[msg.sender][currentPhase] + msg.value > individualLimit[currentPhase]) {
        revert("INDIVIDUAL_LIMIT_EXCEEDED");
      }
      _;
    }

    modifier isWithinPhaseLimit() {
      if (currentPhase != Phase.open && getPhaseContribution(currentPhase) + msg.value > phaseGoal[currentPhase]) {
        revert("PHASE_GOAL_LIMIT_EXCEEDED");
      }
      _;
    }

    function whiteListInvestor(address investor) public onlyOwner {
      require(!whiteListedInvestors[investor], "WHITE_LISTED_ALREADY");

      whiteListedInvestors[investor] = true;

      emit InvestorWhiteListed(investor);
    }

    function moveInvestedEthToLiquidityPool(address liquidityPool) external onlyOwner {
      //deposit KudiCoin tokens in the liquidityPool at a 5:1 ratio
      totalContributions = 10 ether;
      uint256 tokens = totalContributions * 5;

      transferToken(liquidityPool, tokens);

      ILiquidityPool(liquidityPool).deposit{value: totalContributions}(tokens, liquidityPool);
    }

    function withdrawTokens() public {
      require(currentPhase == Phase.open, "ERROR: cannot withdraw tokens");
      require(totalIndividualContributions[msg.sender] > 0, "ERROR: you do not have any contributions");

      uint tokens = totalIndividualContributions[msg.sender] * 5;
      totalIndividualContributions[msg.sender] = 0;
      transferToken(address(msg.sender), tokens);

      emit TokensReleased(tokens);
    }

    function pauseFunding() public onlyOwner {
        icoPaused = true;
    }

    function resumeFunding() public onlyOwner {
        icoPaused = false;
    }

    function getTokenBalance() public view returns (uint) {
        return balanceOf(msg.sender);
    }

    function getFundingStatus() public view onlyOwner returns (bool) {
        return icoPaused;
    }

    function contribute() external payable icoActive isWhiteListed canContribute isWithinPhaseLimit {
      totalContributions += msg.value;
      individualContributions[msg.sender][currentPhase] += msg.value;
      totalIndividualContributions[msg.sender] += msg.value;
      phaseContributions[currentPhase] += msg.value;

      if (totalContributions == goal) {
        icoPaused = true;
      }

      if (phaseGoal[Phase.seed] == getPhaseContribution(currentPhase)) {
        currentPhase = Phase.general;
      }

      if (phaseGoal[Phase.general] == getPhaseContribution(currentPhase)) {
        currentPhase = Phase.open;
        emit PhaseMoved(Phase.open);
      }

      emit Contributed(msg.value);
    }

    function movePhase(Phase nextPhase) public onlyOwner onlyFoward(nextPhase) {
      currentPhase = nextPhase;

      emit PhaseMoved(nextPhase);
    }

    function setPhase(Phase phase) public onlyOwner {
      currentPhase = phase;
    }

    function getCurrentPhase() public view returns(Phase) {
      return currentPhase;
    }

    function getTotalContributions() public view returns(uint) {
      return totalContributions;
    }

    function getIndividualContribution() public view returns(uint) {
      return totalIndividualContributions[msg.sender];
    }

    function getPhaseContribution(Phase phase) public view returns(uint) {
      return phase == Phase.general ? (phaseContributions[Phase.general] + phaseContributions[Phase.seed]) : phaseContributions[phase];
    }
}
