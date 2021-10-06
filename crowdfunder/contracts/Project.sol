pragma solidity ^0.4.17;

contract Project {
  address public creator;
  mapping(address => uint) userContributions;
  mapping(address => string) userTier;
  uint public minimumContribution = 0.01 ether;
  uint public targetAmount = 3 ether;
  uint public totalAmount;
  bool public failed;
  bool public funded;
  uint public deadline;

  struct Contribution {
    uint amount;
    address contributor;
  }

  Contribution[] public contributions;

  constructor() public{
    creator = msg.sender;
    deadline = now + 30 days;
  }

  function contribute() public payable {
    require(!failed);
    require(!funded);
    require(msg.value >= minimumContribution);

    if(now < deadline && !funded) {
      failed = true;
    }
    else {
      Contribution memory contribution = Contribution({
          amount: msg.value,
          contributor: msg.sender
        });

      contributions.push(contribution);
      userContributions[msg.sender] += msg.value;
      setUserTier();

      totalAmount += msg.value;
      if (totalAmount > targetAmount) {
        funded = true;
      }
    }
  }

  function cancel() public {
    require(msg.sender == creator);
    require(now > deadline);

    failed = true;
  }

  function withdraw(uint amount) public {
    if (creator == msg.sender && funded) {
      require(totalAmount > amount);

      creator.transfer(amount);
      totalAmount = totalAmount - amount;
    }
    else if(failed) {
      msg.sender.transfer(userContributions[msg.sender]);
      resetTier();
    }
  }

  function resetTier() private {
      userTier[msg.sender] = '';
  }

  function setUserTier() private {
    if (userContributions[msg.sender] >= 1 ether) {
      userTier[msg.sender] = 'gold';
    }
    else if (userContributions[msg.sender] >= 0.25 ether) {
      userTier[msg.sender] = 'silver';
    }
    else {
      userTier[msg.sender] = 'bronze';
    }
  }

  function getUserTier(address user) public view returns (string) {
    return userTier[user];
  }

}
