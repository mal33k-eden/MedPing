const BigNumber = require('bignumber.js');
const MedPingToken = artifacts.require("MedPingToken");
const MedPingOGVault = artifacts.require("MedPingOGVault"); 
const oglist = require("../provision/ogList_1.js").oglist;
const { DateTime } = require("luxon");
 
//migrate --reset -f 7 --to 7

module.exports = async function (deployer,network,accounts) {

    //deploy token 
  var adapter = MedPingToken.interfaceAdapter;
  const web3 = adapter.web3;
  var totalBatchSent  = 0; 

  var exchgBucket = accounts[3];
 //const token = await MedPingToken.at('0xa35844c449714BC6EdAdD057B1565E6c9fAdE972'); //for live only 

  //const token = await MedPingToken.deployed(); 

  const vault = await MedPingOGVault.deployed(); 
  var firstListingDate = '1636800187'; //

  
  var investors = oglist;
 
  for (let index = 0; index < investors.length; index++) {
    const element = investors[index]; 


    var tog = Number(((element.amount * 0.3)/0.01725).toFixed(2)); //30%OFGIVING    
    var credit = web3.utils.toWei(BigNumber(tog).toString(),'ether');
    await vault.L2Liquify(element.address,credit);

    var sog = Number(((element.amount * 0.7)/0.01725).toFixed(2)); //70%OFGIVING    
    let tenog = sog/10; //70%OFGIVINGdivided by 10
    let tenVal = web3.utils.toWei(BigNumber(tenog).toString(),'ether');
    let code = Math.floor(100000 + Math.random() * 900000);
    await vault.distributeTokenToVault(element.address,firstListingDate, tenVal,10,code);
 
    console.log("line "+ element.address +" "+ index);
  }
  return true;
}