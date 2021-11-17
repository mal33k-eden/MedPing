const BigNumber = require('bignumber.js');
const MedPingToken = artifacts.require("MedPingToken");
const MedPingOGVault = artifacts.require("MedPingOGVault"); 
const oglist = require("../provision/ogList_1.js").oglist;
const { DateTime } = require("luxon");
 
//migrate --reset -f 6 --to 6

module.exports = async function (deployer,network,accounts) {

    //deploy token 
  var adapter = MedPingToken.interfaceAdapter;
  const web3 = adapter.web3; 

  var exchgBucket = accounts[3];
  
  const token = await MedPingToken.at('0xa35844c449714bc6edadd057b1565e6c9fade972'); //for live only 

  //const token = await MedPingToken.deployed(); 
  
  await deployer.deploy(MedPingOGVault,token.address);
  const vault = await  MedPingOGVault.deployed(); 
  console.log("deployed");

  await token.whiteListAddress(vault.address);
  console.log("whitelisted");
  var ogSupply = "7000000000000000000000000"
  await token.transfer(vault.address,ogSupply, {from:exchgBucket});

  console.log("finish");
  return true;
}