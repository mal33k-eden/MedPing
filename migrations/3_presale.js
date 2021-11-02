const BigNumber = require('bignumber.js');
const preSaleInvestorsList = require("../provision/investorsList_1.js").investorsList1;
const MedPingToken = artifacts.require("MedPingToken");
const MedPingCrowdSale = artifacts.require("MedPingCrowdSale");
const MedPingInvestorsVault = artifacts.require("MedPingInvestorsVault");
const MedPingPreSale = artifacts.require("MedPingPreSale");
const { DateTime } = require("luxon");
 
//migrate --reset -f 3 --to 3

module.exports = async function (deployer,network,accounts) {
    //deploy token 
  var adapter = MedPingToken.interfaceAdapter;
  const web3 = adapter.web3;
  var addVcsBucket = accounts[4];
  var addBurnBucket = accounts[5]; 
 
  
  const token = await MedPingToken.deployed();
  const vault = await MedPingInvestorsVault.deployed();
  const crowdsale = await MedPingCrowdSale.deployed();
  const contractPreSale = await MedPingPreSale.deployed();    
 
  await token.setReleaser(crowdsale.address);
  await token.setPreSale(contractPreSale.address);
  await vault.setOperator(crowdsale.address);
  await vault.setPreSale(contractPreSale.address);
  await token.setBurner(addBurnBucket);
  await token.setVcsBucket(addVcsBucket);


  var investors = preSaleInvestorsList;
  for (let index = 0; index < investors.length; index++) {
    const element = investors[index];
    let val = web3.utils.toWei(BigNumber(element.amount).toString(),'ether');
    await contractPreSale.addInvestors(element.address, val);
  }

    return true;
  
}