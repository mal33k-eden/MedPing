
const MedPingToken = artifacts.require("MedPingToken");
const MedPingCrowdSale = artifacts.require("MedPingCrowdSale");
const MedPingInvestorsVault = artifacts.require("MedPingInvestorsVault");
const MedPingPreSale = artifacts.require("MedPingPreSale");

//migrate --reset -f 2 --to 2

module.exports = async function (deployer,network,accounts) {
    //deploy token 
  var adapter = MedPingToken.interfaceAdapter;
  const web3 = adapter.web3;
   
  const token = await MedPingToken.deployed();
  const vault = await MedPingInvestorsVault.deployed();
  const crowdsale = await MedPingCrowdSale.deployed();  
  const contractPreSale = await MedPingPreSale.deployed(); 

  var softCap = 69063; //usd from spreadsheet
  var hardCap = 1690630; //usd from spreadsheet
  //SUPPLIES
  var supplyTeamToken   =  "110000000000000000000000000"; // FOR MPG TEAM
  var supplyBurnBucket  =  "10000000000000000000000000";
  var supplyCrowdSale   =  "27500000000000000000000000"; 
  var supplyExchange    =  "30000000000000000000000000";
  var supplyPreSale     =  "12500000000000000000000000";
  //ADDRESSES
  var addDevMarketing = accounts[9];
  var addTeamToken = accounts[8];
  var addListingLiquidity = accounts[7];
  var addOperationsManagement = accounts[6];
  var addBurnBucket = accounts[5]; 
  var addExchangeBK = accounts[3];


    await crowdsale.setCaps(softCap,hardCap);
    await crowdsale.setTeamMembersLock(addDevMarketing,5,1,5,20,8976,1);
    await crowdsale.setTeamMembersLock(addTeamToken,18,3,10,30,7654,3);
    await crowdsale.setTeamMembersLock(addListingLiquidity,27,1,1,100,6609,1);
    await crowdsale.setTeamMembersLock(addOperationsManagement,5,1,5,20,7654,1);

    await token.whiteListAddress(contractPreSale.address);
    await token.whiteListAddress(accounts[0]);
    await token.whiteListAddress(addExchangeBK);
    await token.whiteListAddress(addBurnBucket);
    await token.whiteListAddress(crowdsale.address);


    await token.transfer(crowdsale.address,supplyCrowdSale);
    await token.transfer(vault.address,supplyTeamToken);
    await token.transfer(contractPreSale.address,supplyPreSale);
    await token.transfer(addBurnBucket,supplyBurnBucket);
    await token.transfer(addExchangeBK,supplyExchange);
    

    
    return true;
  
}