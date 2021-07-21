//const { BN} = require('@openzeppelin/test-helpers');
const MedPingToken = artifacts.require("MedPingToken");
const MedPingCrowdSale = artifacts.require("MedPingCrowdSale");
const MedPingInvestorsVault = artifacts.require("MedPingInvestorsVault");
const { DateTime } = require("luxon");


module.exports = async function (deployer,network,accounts) {
  await deployer.deploy(MedPingToken);
  const token = await MedPingToken.deployed();
  var wallet = accounts[4];
  var crowdsaleSupply =  "70000000000000000000000000";
  var lockedFunds     =  "110000000000000000000000000";
  var startTime = Math.trunc(DateTime.now().toLocal().plus({minutes:10}).toSeconds());
  //var endTime = Math.trunc(DateTime.now().toLocal().plus({ months: 3 ,hours:23,minutes:60,seconds:60}).toSeconds());
  var endTime = Math.trunc(DateTime.now().toLocal().plus({ days: 5}).toSeconds());
  var DevMarketing = accounts[9];
  var TeamToken = accounts[8];
  var ListingLiquidity = accounts[7];
  var OperationsManagement = accounts[6];
  var softCap = 69063; //usd from spreadsheet
  var hardCap = 1690630; //usd from spreadsheet
  var busdContract = '0xeD24FC36d5Ee211Ea25A80239Fb8C4Cfd80f12Ee';

  await token.setReleaser(accounts[0]);
  await deployer.deploy(MedPingInvestorsVault,token.address);
  const vault = await MedPingInvestorsVault.deployed();
  await token.transfer(vault.address,lockedFunds);

  await deployer.deploy(
    MedPingCrowdSale,
    token.address,vault.address,busdContract,startTime,
    endTime, wallet,DevMarketing,
    TeamToken,ListingLiquidity,OperationsManagement
  );

  const crowdsale = await MedPingCrowdSale.deployed();
  await crowdsale.setCaps(softCap,hardCap);
  await token.transfer(crowdsale.address,crowdsaleSupply);
  await token.setReleaser(crowdsale.address);

  await vault.setOperator(crowdsale.address);

  return true;
};


