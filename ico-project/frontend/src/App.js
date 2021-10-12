import { useEffect, useState } from "react";
import { ethers } from "ethers";
import logo from './logo.svg';
import './App.css';

// import abi from './ico.abi.js';

const contractAddress = ''
const abi = [
  {
    "inputs": [
      {
        "internalType": "address",
        "name": "treasury",
        "type": "address"
      }
    ],
    "stateMutability": "nonpayable",
    "type": "constructor"
  },
  {
    "anonymous": false,
    "inputs": [
      {
        "indexed": false,
        "internalType": "uint256",
        "name": "amount",
        "type": "uint256"
      }
    ],
    "name": "Contributed",
    "type": "event"
  },
  {
    "anonymous": false,
    "inputs": [
      {
        "indexed": false,
        "internalType": "address",
        "name": "investor",
        "type": "address"
      }
    ],
    "name": "InvestorWhiteListed",
    "type": "event"
  },
  {
    "anonymous": false,
    "inputs": [
      {
        "indexed": true,
        "internalType": "address",
        "name": "previousOwner",
        "type": "address"
      },
      {
        "indexed": true,
        "internalType": "address",
        "name": "newOwner",
        "type": "address"
      }
    ],
    "name": "OwnershipTransferred",
    "type": "event"
  },
  {
    "anonymous": false,
    "inputs": [
      {
        "indexed": false,
        "internalType": "enum Ico.Phase",
        "name": "phase",
        "type": "uint8"
      }
    ],
    "name": "PhaseMoved",
    "type": "event"
  },
  {
    "anonymous": false,
    "inputs": [
      {
        "indexed": false,
        "internalType": "uint256",
        "name": "amount",
        "type": "uint256"
      }
    ],
    "name": "TokensReleased",
    "type": "event"
  },
  {
    "inputs": [
      {
        "internalType": "uint256",
        "name": "amount",
        "type": "uint256"
      }
    ],
    "name": "contribute",
    "outputs": [],
    "stateMutability": "payable",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "getCurrentPhase",
    "outputs": [
      {
        "internalType": "enum Ico.Phase",
        "name": "",
        "type": "uint8"
      }
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "getFundingStatus",
    "outputs": [
      {
        "internalType": "bool",
        "name": "",
        "type": "bool"
      }
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "getIndividualContribution",
    "outputs": [
      {
        "internalType": "uint256",
        "name": "",
        "type": "uint256"
      }
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [
      {
        "internalType": "enum Ico.Phase",
        "name": "phase",
        "type": "uint8"
      }
    ],
    "name": "getPhaseContribution",
    "outputs": [
      {
        "internalType": "uint256",
        "name": "",
        "type": "uint256"
      }
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "getTokenBalance",
    "outputs": [
      {
        "internalType": "uint256",
        "name": "",
        "type": "uint256"
      }
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "getTotalContributions",
    "outputs": [
      {
        "internalType": "uint256",
        "name": "",
        "type": "uint256"
      }
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [
      {
        "internalType": "enum Ico.Phase",
        "name": "nextPhase",
        "type": "uint8"
      }
    ],
    "name": "movePhase",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "owner",
    "outputs": [
      {
        "internalType": "address",
        "name": "",
        "type": "address"
      }
    ],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "pauseFunding",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "renounceOwnership",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "resumeFunding",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [
      {
        "internalType": "enum Ico.Phase",
        "name": "phase",
        "type": "uint8"
      }
    ],
    "name": "setPhase",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [
      {
        "internalType": "address",
        "name": "newOwner",
        "type": "address"
      }
    ],
    "name": "transferOwnership",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [
      {
        "internalType": "address",
        "name": "investor",
        "type": "address"
      }
    ],
    "name": "whiteListInvestor",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [],
    "name": "withdraw",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  }
];

let contract;

function App() {
  const [phases] = useState({
    0: 'Seed',
    1: 'General',
    2: 'Open'
  });

  const [totalContributions, setTotalContributions] = useState(0);
  const [myContributions, setMyContributions] = useState(0);
  const [individualLimit, setIndividualLimit] = useState(0);
  const [phaseGoal, setPhaseGoal] = useState(0);
  const [tokens, setTokens] = useState(0);
  const [currentPhase, setCurrentPhase] = useState(0);
  const [address, setAddress] = useState();

  const [amount, setAmount] = useState(0);

  useEffect(() => {
    connectToMetamask();
  }, [])

  const formatError = (error) => error.data ? error.data.message : error.message;

  const whiteListAddress = async (e) => {
    e.preventDefault();
    try {
      console.log(ethers.utils.formatEther(amount));
      await contract.whiteListAddress(address);
      alert('Whitelisted!');
      e.reset();
    }
    catch (ex) {
      alert(formatError(ex));
    }
  }
  async function connectToMetamask() {
    try {
      const provider = new ethers.providers.Web3Provider(window.ethereum);
      contract = new ethers.Contract(contractAddress, abi, provider.getSigner());

      const signerAddress = await provider.getSigner().getAddress();
      console.log("Signed in", signerAddress);
      go();
    }
    catch (err) {
      console.log("Not signed in", err.message)
    }
  }

  const go = () => {
    myTokens();
    getCurrentPhase()
    fetchContributions();
    registerListeners();
  }

  const getCurrentPhase = async () => {
    try {
      setCurrentPhase(await contract.getCurrentPhase());
    }
    catch (ex) {
      console.log(formatError(ex));
    }
  }
  const fetchContributions = async () => {
    try {
      const myContributions = await contract.getIndividualContribution();
      setMyContributions(ethers.utils.formatEther(myContributions));

      const contributions = await contract.getTotalContributions();
      setTotalContributions(ethers.utils.formatEther(contributions));
    }
    catch (ex) {
      alert(formatError(ex));
    }
  }

  const registerListeners = () => {
    contract.on('Contributed', () => {
      fetchContributions();
      getCurrentPhase();

    });

    contract.on('TokensReleased', () => {
      myTokens();
      fetchContributions();
    });
  }

  const myTokens = async () => {
    setTokens((await contract.getTokenBalance()).toString());
  }

  const withdraw = async () => {
    try {
      await contract.withdraw();
      alert('Tokens withdrawn!');
    }
    catch (ex) {
      alert(formatError(ex));
    }
  }

  const depositEther = async (e) => {
    e.preventDefault();
    try {
      await contract.contribute(amount);
      alert('Contributed!');
    }
    catch (ex) {
      alert(formatError(ex));
    }
  }

  //TODO
  // display current phase goal and max individual limit for phase goal

  return (
    <div className="App">
      <div>
        <h1>Kudi coin ico</h1>
        <hr />
        <p>Current phase: <b>{phases[currentPhase]}</b>, {" "} Max individual contribution: <b>{individualLimit}</b>, {" "} Max contribution for current phase: <b>{phaseGoal}</b></p>
        <hr />
        <p className="deposit-stats">
          <span className="total">Total contribution: {totalContributions} ether</span>
          ,{" "}
          <span className="mine">My contribution: {myContributions} ether</span>
          ,{" "}
          <span className="mine">My Tokens: {tokens}</span>
        </p>  <hr />
        {currentPhase != 2 && <form className="deposit-form" onSubmit={depositEther}>
          <label>Deposit Ether</label>
          <input type="number" onChange={(e) => setAmount(e.target.value)} placeholder="Amount" />
          {amount > 0 && <button type="submit">Deposit</button>}
        </form>}
        {currentPhase != 2 && <hr />}
        {currentPhase == 2 && myContributions > 0 && <button onClick={withdraw}>Withdraw Token</button>}
      </div>
    </div >
  );
}

export default App;
