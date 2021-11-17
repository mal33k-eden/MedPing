const BigNumber = require('bignumber.js');
const MedPingToken = artifacts.require("MedPingToken");
const MedPingCrowdSale = artifacts.require("MedPingCrowdSale");
const MedPingIEO = artifacts.require("MedPingIEO");
const { DateTime } = require("luxon");
 
//migrate --reset -f 4 --to 4

module.exports = async function (deployer,network,accounts) {

    //deploy token 
  var adapter = MedPingToken.interfaceAdapter;
  const web3 = adapter.web3;

  
  //0xe9e7cea3dedca5984780bafc599bd69add087d56
  // var busdContract = '0xeD24FC36d5Ee211Ea25A80239Fb8C4Cfd80f12Ee'; 
  // var BNBUSD_Aggregator = "0x0567F2323251f0Aab15c8dFb1967E4e8A7D42aeE";
  // var addVcsBucket = accounts[4];
  // const token = await MedPingToken.at('0xa35844c449714BC6EdAdD057B1565E6c9fAdE972');
  // //const crowdsale = await MedPingCrowdSale.deployed();   
  
  // //deploy presaleContract 
  // await deployer.deploy(MedPingIEO,accounts[2],token.address,BNBUSD_Aggregator,addVcsBucket);
  // const IEO = await MedPingIEO.deployed();   
  // await token.whiteListAddress(IEO.address);
  // return true;
  
}