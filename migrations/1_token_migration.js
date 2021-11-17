const MedPingToken = artifacts.require("MedPingToken");
const MedPingCrowdSale = artifacts.require("MedPingCrowdSale");
const MedPingInvestorsVault = artifacts.require("MedPingInvestorsVault");
const MedPingPreSale = artifacts.require("MedPingPreSale");
const { DateTime } = require("luxon");
 

//migrate --reset -f 1 --to 1
module.exports = async function (deployer,network,accounts) {
  //deploy MPG token 

  await deployer.deploy(MedPingToken);
  const token = await MedPingToken.deployed();

  return true;
};


