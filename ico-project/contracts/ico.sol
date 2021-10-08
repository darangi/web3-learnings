//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";

import "./coin.sol";

contract Ico is Ownable {
    bool private icoPaused = false;

    KudiCoin private token;

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

    constructor(address treasury) {
      token = new KudiCoin(treasury);

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

    modifier canContribute(uint amount) {
      if (currentPhase != Phase.open && individualContributions[msg.sender][currentPhase] + amount > individualLimit[currentPhase]) {
        revert("INDIVIDUAL_LIMIT_EXCEEDED");
      }
      _;
    }

    function whiteListInvestor(address investor) public onlyOwner {
      require(!whiteListedInvestors[investor], "WHITE_LISTED_ALREADY");

      whiteListedInvestors[investor] = true;

      emit InvestorWhiteListed(investor);
    }

    function withdraw() public {
      require(currentPhase == Phase.open, "ERROR: cannot withdraw tokens");
      require(totalIndividualContributions[msg.sender] > 0, "ERROR: you do not have any contributions");

      uint tokens = totalIndividualContributions[msg.sender] * 5 / 1 ether;
      token.transferToken(address(msg.sender), tokens);
      totalIndividualContributions[msg.sender] = 0;

      emit TokensReleased(tokens);
    }

    function pauseFunding() public onlyOwner {
        icoPaused = true;
    }

    function resumeFunding() public onlyOwner {
        icoPaused = false;
    }

    function getTokenBalance() public view returns (uint) {
        return token.balanceOf(msg.sender);
    }

    function getFundingStatus() public view onlyOwner returns (bool) {
        return icoPaused;
    }

    function contribute(uint256 amount) public payable icoActive isWhiteListed canContribute(amount) {
      totalContributions += amount;
      individualContributions[msg.sender][currentPhase] += amount;
      totalIndividualContributions[msg.sender] += amount;
      phaseContributions[currentPhase] += amount;

      if (totalContributions == goal) {
        icoPaused = true;
      }

      if (phaseGoal[Phase.seed] == phaseContributions[currentPhase]) {
        currentPhase = Phase.general;
      }

      if (phaseGoal[Phase.general] == phaseContributions[currentPhase] + phaseContributions[Phase.seed]) {
        currentPhase = Phase.open;
      }

      emit Contributed(amount);
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

    function getPhaseContribution(Phase phase) public view returns(uint) {
      return phase == Phase.general ? (phaseContributions[Phase.general] + phaseContributions[Phase.seed]) : phaseContributions[phase];
    }
}
