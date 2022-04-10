require('dotenv').config();
const API_URL = process.env.API_URL;
const PUBLIC_KEY = process.env.PUBLIC_KEY;
const PRIVATE_KEY = process.env.PRIVATE_KEY;

const networkName = hre.network.name;
console.log(networkName);

const endpoint =
{
  "rinkeby": "0x79a63d6d8BBD5c6dfc774dA79bCcD948EAcb53FA",
  "bsc-testnet": "0x6Fcb97553D41516Cb228ac03FdC8B9a0a9df04A1",
  "fuji": "0x93f54D755A063cE7bB9e6Ac47Eccc8e33411d706",
  "mumbai": "0xf69186dfBa60DdB133E91E9A4B5673624293d8F8",
  "arbitrum-rinkeby": "0x4D747149A57923Beb89f22E6B7B97f7D8c087A00",
  "optimism-kovan": "0x72aB53a133b27Fa428ca7Dc263080807AfEc91b5",
  "fantom-testnet": "0x7dcAD72640F835B0FA36EFD3D6d3ec902C7E5acf"
};

const stf =
{
  "rinkeby": "0xd465e36e607d493cd4CC1e83bea275712BECd5E0",
  "mumbai": "0x200657E2f123761662567A1744f9ACAe50dF47E6",
  "polygon": "0x2C90719f25B10Fc5646c82DA3240C76Fa5BcCF34",
};

const appFactoryJSON = require("../artifacts/contracts/DAOFactory.sol/DAOFactory.json");
const c2factoryAddress = '0x4a27c059FD7E383854Ea7DE6Be9c390a795f6eE3';
const c2factoryAbi = [
  {
    anonymous: false,
    inputs: [
      {
        indexed: false,
        internalType: 'address',
        name: 'addr',
        type: 'address',
      },
      {
        indexed: false,
        internalType: 'uint256',
        name: 'salt',
        type: 'uint256',
      },
    ],
    name: 'Deployed',
    type: 'event',
  },
  {
    constant: false,
    inputs: [
      {
        internalType: 'bytes',
        name: 'code',
        type: 'bytes',
      },
      {
        internalType: 'uint256',
        name: 'salt',
        type: 'uint256',
      },
    ],
    name: 'deploy',
    outputs: [],
    payable: false,
    stateMutability: 'nonpayable',
    type: 'function',
  },
];

const tokenJSON = require("../artifacts/contracts/token/DAOToken.sol/DAOToken.json");
const appJSON = require("../artifacts/contracts/DAOSuperApp.sol/DAOSuperApp.json");
const govJSON = require("../artifacts/contracts/governance/Governor.sol/DAOGovernor.json");
const execJSON = require("../artifacts/contracts/DAOFactory.sol/DAOExecutor.json");
const receiverExecutorJSON = require("../artifacts/contracts/governance/ReceiverExecutor.sol/ReceiverExecutor.json");

const signer = new ethers.Wallet(PRIVATE_KEY, ethers.provider);

function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}


async function main(stf) {

    const c2factory = new ethers.Contract(c2factoryAddress, c2factoryAbi, signer);
    var filter = await c2factory.filters.Deployed();
    
    var salt;

    if (true) {

      const tokenContract = await ethers.getContractFactory("DAOToken");
      const token = await tokenContract.deploy();
      await token.deployTransaction.wait();
      console.log("token deployed to address:", token.address);
      //return;
      const appContract = await ethers.getContractFactory("DAOSuperApp");
      const app = await appContract.deploy();
      await app.deployTransaction.wait();
      console.log("app deployed to address:", app.address);
      const govContract = await ethers.getContractFactory("DAOGovernor");
      const gov = await govContract.deploy();
      await gov.deployTransaction.wait();
      console.log("gov deployed to address:", gov.address);
      const execContract = await ethers.getContractFactory("DAOExecutor");
      const exec = await execContract.deploy();
      await exec.deployTransaction.wait();
      console.log("exec deployed to address:", exec.address);
      //return;

    }

    //const appFactoryContract = await ethers.getContractFactory("DAOFactory");
    //const appFactory = await appFactoryContract.deploy();
    //console.log("appFactory deployed to address:", appFactory.address);
    //return;

    var c = {};
    var result;

    var v = "v0.4";
    const tokenSalt = ethers.utils.id("TOKEN"+v);
    const appSalt = ethers.utils.id("APP"+v);
    const govSalt = ethers.utils.id("GOV"+v);
    const execSalt = ethers.utils.id("EXEC"+v);
    const factorySalt = ethers.utils.id("FACTORY"+v);

    c2factory.on(filter, async (address, salt, event) => { 
      //console.log("tokenSalt", tokenSalt);
      //console.log("salt", salt);
      //console.log("salt as hex", salt.toHexString() );
      if ( salt.toHexString() == appSalt ) {
        console.log("app impl created at " + address);
        c.app = address;
      } else if ( salt.toHexString() == tokenSalt ) {
        console.log("token impl created at " + address);
        c.token = address;
      } else if ( salt.toHexString() == govSalt ) {
        console.log("gov impl created at " + address);
        c.gov = address;
      } else if ( salt.toHexString() == execSalt ) {
        console.log("exec impl created at " + address);
        c.exec = address;
      } else if ( salt.toHexString() == factorySalt ) {
        console.log("app factory created at " + address);
        var appFactoryAddress = address;
        let daoFactory = new ethers.Contract(
          appFactoryAddress,
          appFactoryJSON.abi,
          signer
        );
        const init = await daoFactory.initialize(
          stf,
          c.app,
          c.token,
          c.gov,
          c.exec
        );
        await init.wait(5);
      }
    });

    //const gasOptions = {"maxPriorityFeePerGas": "45000000000", "maxFeePerGas": "45000000016" };
    const gasOptions = {};

    result = await c2factory.deploy(tokenJSON.bytecode, tokenSalt, gasOptions);
    //console.log(result);
    await result.wait();

    result = await c2factory.deploy(appJSON.bytecode, appSalt, gasOptions);
    await result.wait();

    result = await c2factory.deploy(govJSON.bytecode, govSalt, gasOptions);
    await result.wait();

    result = await c2factory.deploy(execJSON.bytecode, execSalt, gasOptions);
    await result.wait();
    
    result = await c2factory.deploy(appFactoryJSON.bytecode, factorySalt, gasOptions);
    await sleep(60000);
    await result.wait();
 }

 async function recExec() {

  const c2factory = new ethers.Contract(c2factoryAddress, c2factoryAbi, signer);
  var filter = await c2factory.filters.Deployed();
  
  var salt;

  if (true) {
    const recContract = await ethers.getContractFactory("ReceiverExecutor");
    const receiver = await recContract.deploy();
    await receiver.deployTransaction.wait();
    console.log("ReceiverExecutor deployed to address:", receiver.address);
    //return;
  }

  var c = {};
  var result;

  var v = "v0.22";
  const receiverSalt = ethers.utils.id("RECEIVER"+v);

  c2factory.on(filter, async (address, salt, event) => { 
    //console.log("tokenSalt", tokenSalt);
    //console.log("salt", salt);
    //console.log("salt as hex", salt.toHexString() );

    console.log("receiver executor created at " + address);
    var receiverExecutorAddress = address;
    let receiverExecutor = new ethers.Contract(
      receiverExecutorAddress,
      receiverExecutorJSON.abi,
      signer
    );
    console.log(endpoint[networkName]);
    const init = await receiverExecutor.initialize(
      endpoint[networkName]
    );
    console.log(init);
    await init.wait(5);
  });

  //const gasOptions = {"maxPriorityFeePerGas": "45000000000", "maxFeePerGas": "45000000016" };
  const gasOptions = {};
  
  result = await c2factory.deploy(receiverExecutorJSON.bytecode, receiverSalt, gasOptions);
  await sleep(60000);
  await result.wait();
}
 
main(stf[networkName])
//recExec()
   .then(() => process.exit(0))
   .catch(error => {
     console.error(error);
     process.exit(1);
   });

// npx hardhat run scripts/deploy.js --network localhost
// npx hardhat verify --network rinkeby 0x9fbddEae7a5FD0528bf729F3997692f9b45D2236
// npx hardhat node --fork https://eth-rinkeby.alchemyapi.io/v2/n_mDCfTpJ8I959arPP7PwiOptjubLm57 --fork-block-number 9734005