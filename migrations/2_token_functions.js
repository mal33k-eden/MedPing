const MedPingToken = artifacts.require("MedPingToken");
const MedPingCrowdSale = artifacts.require("MedPingCrowdSale");
const MedPingInvestorsVault = artifacts.require("MedPingInvestorsVault");
const MedPingPreSale = artifacts.require("MedPingPreSale");
const { DateTime } = require("luxon");
 

//migrate --reset -f 1 --to 1
module.exports = async function (deployer,network,accounts) {
  //deploy token 
  var adapter = MedPingToken.interfaceAdapter;
  const web3 = adapter.web3;
  
  const token = await MedPingToken.deployed();
  await token.setReleaser(accounts[0]);

  // var startTime = Math.trunc(DateTime.now().toLocal().plus({seconds:120}).toSeconds());
  // var endTime = Math.trunc(DateTime.now().toLocal().plus({ minutes:60}).toSeconds());
  var startTime = Math.trunc(DateTime.now().toLocal().plus({minutes:5}).toSeconds());
  var endTime = Math.trunc(DateTime.now().toLocal().plus({ hours:23}).toSeconds());
 
 
  //ADDRESSES
  var busdContract = '0xe9e7cea3dedca5984780bafc599bd69add087d56'; //change to live 0xe9e7cea3dedca5984780bafc599bd69add087d56
  var addDevMarketing = accounts[9];
  var addTeamToken = accounts[8];
  var addListingLiquidity = accounts[7];
  var addOperationsManagement = accounts[6];
  var wallet = accounts[2];
  var addVcsBucket = accounts[4];

  //deploy vault 
  await deployer.deploy(MedPingInvestorsVault,token.address);
  const vault = await MedPingInvestorsVault.deployed();

  //deploy crowdsaleContract 
  await deployer.deploy(
    MedPingCrowdSale,
    token.address,vault.address,busdContract,startTime,
    endTime, wallet,addDevMarketing,
    addTeamToken,addListingLiquidity,addOperationsManagement
  );

  //deploy presaleContract 
  await deployer.deploy(MedPingPreSale,token.address,addVcsBucket,vault.address);
  

  return true;
};


