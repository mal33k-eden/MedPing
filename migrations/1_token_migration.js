//const { BN} = require('@openzeppelin/test-helpers');
const MedPingToken = artifacts.require("MedPingToken");
const MedPingCrowdSale = artifacts.require("MedPingCrowdSale");
const MedPingInvestorsVault = artifacts.require("MedPingInvestorsVault");
const { DateTime } = require("luxon");


module.exports = async function (deployer,network,accounts) {
    
  //deploy token 
  await deployer.deploy(MedPingToken);
  const token = await MedPingToken.deployed();
  var wallet = accounts[4];
  var crowdsaleSupply =  "70000000000000000000000000";
  var lockedFunds     =  "110000000000000000000000000";
  var BurnBucketFunds     =  "10000000000000000000000000";
  var startTime = Math.trunc(DateTime.now().toLocal().plus({minutes:3}).toSeconds());
  //var endTime = Math.trunc(DateTime.now().toLocal().plus({ months: 3 ,hours:23,minutes:60,seconds:60}).toSeconds());
  var endTime = Math.trunc(DateTime.now().toLocal().plus({ minutes: 14}).toSeconds());
  
  var softCap = 69063; //usd from spreadsheet
  var hardCap = 1690630; //usd from spreadsheet
  var busdContract = '0xeD24FC36d5Ee211Ea25A80239Fb8C4Cfd80f12Ee'; //change to live
  var DevMarketing = accounts[9];
  var TeamToken = accounts[8];
  var ListingLiquidity = accounts[7];
  var OperationsManagement = accounts[6];
  var BurnBucket = accounts[5];

  await token.setReleaser(accounts[0]);
  await token.setBurner(BurnBucket);
  //deploy vault 
  await deployer.deploy(MedPingInvestorsVault,token.address);
  const vault = await MedPingInvestorsVault.deployed();
  await token.transfer(vault.address,lockedFunds);
  await token.transfer(BurnBucket,BurnBucketFunds);

  await deployer.deploy(
    MedPingCrowdSale,
    token.address,vault.address,busdContract,startTime,
    endTime, wallet,DevMarketing,
    TeamToken,ListingLiquidity,OperationsManagement
  );

  const crowdsale = await MedPingCrowdSale.deployed();           
  await crowdsale.setCaps(softCap,hardCap);
  await crowdsale.setTeamMembersLock(DevMarketing,5,1,5,20,8976,1);
  await crowdsale.setTeamMembersLock(TeamToken,18,3,10,30,7654,3);
  await crowdsale.setTeamMembersLock(ListingLiquidity,27,1,1,100,6609,1);
  await crowdsale.setTeamMembersLock(OperationsManagement,5,1,5,20,7654,1);
  await token.transfer(crowdsale.address,crowdsaleSupply);
  await token.setReleaser(crowdsale.address);

  await vault.setOperator(crowdsale.address);

  return true;
};


