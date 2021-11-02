// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import "./MedPingToken.sol"; 
import "@openzeppelin/contracts/access/Ownable.sol";
import "./MedPingInvestorsVault.sol"; 
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@chainlink/contracts/src/v0.6/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract MedPingPreSale is Ownable,ReentrancyGuard{
    using SafeMath for uint256;
    MedPingToken _token;
    MedPingInvestorsVault  _vaultContract;
    address payable _vcsBucket;
    mapping(address=>uint256) investors;
    mapping(address=>uint256) amaWinners;
    uint256 _rate;
    AggregatorV3Interface internal BNBUSD;
    address BNBUSD_Aggregator = 0x2514895c72f50D8bd4B4F9b1110F0D6bD2c97526;
    uint256 _crossDecimal = 10**8;

    event VaultCreated(
        uint256 indexed _vaultKey,
        address indexed _beneficiary,
        uint256  releaseDay,
        uint256 amount
    );

    constructor(MedPingToken token, address payable vcsbucket, MedPingInvestorsVault vault) Ownable()ReentrancyGuard() {
        _token = token;
        _vcsBucket = vcsbucket;
        _vaultContract = vault;//link to token vault contract 
        BNBUSD = AggregatorV3Interface(BNBUSD_Aggregator);
          _rate = 0.0095  * (10 ** 8);
    }

    function addAMAWinner(address _winner, uint256 amount) public  returns(bool){
        amaWinners[_winner] = amount;
        //lock investments of initial investors 
        //_token.addToLockPresale(amount, 0, _winner);
        return true;
    }
    function addInvestors(address _investor, uint256 amount) public  returns(bool){
        investors[_investor] = amount;
        _token.addToLockPresale(amount,0, _investor);
         //lock investments of initial investors 
        return true;
    }
    function approveInvestorForCollection(uint _type,uint80 _roundId) public nonReentrant() returns(bool){
        (
            uint256 busdSent,
            uint bnbVal,
            uint256 mpgToken
        ) = getCollection(_type,_roundId);
        require(investors[msg.sender]> 0,"you are not qualified for this collection");
        _token.transfer(msg.sender, mpgToken);
        investors[msg.sender] = 0;
        return true;
    }
    function approveWinnerForCollection(uint _type,uint80 _roundId) public nonReentrant() returns(bool){
        (
            uint256 busdSent,
            uint bnbVal,
            uint256 mpgToken
        ) = getCollection(_type,_roundId);
        require(amaWinners[msg.sender]> 0,"you are not qualified for this collection");
        _token.transfer(msg.sender, mpgToken);
        amaWinners[msg.sender] = 0;
        return true;
    }
    function getCollection(uint _type,uint80 _roundId) public view returns(uint256 busdSent,uint bnbVal,uint256 mpgToken){
        require(_rate > 0,"rate not set by admin, try again later");
        uint busdVal = 0;
        if (_type == 0) {
            busdVal = amaWinners[msg.sender];
        } else {
            busdVal =  investors[msg.sender];
        }
        int bnb = getBNBUSDPrice(_roundId);
        uint bnbEquv = (busdVal.div(uint256(bnb))).mul(_crossDecimal);
        uint256 numberOfTokens = _MedPingReceiving(bnbEquv,bnb);
        return (busdVal, bnbEquv, numberOfTokens);
    }
    function _MedPingReceiving(uint256 _weiSent,int bnb) internal view returns (uint256 ){
        int _MedRate = int(_rate)/(bnb/int(_crossDecimal));
        uint256 _weiMedRate =  uint256((_MedRate * 10 **18 )/int(_crossDecimal));
        uint256 tempR = _weiSent.div(_weiMedRate);
        return tempR * 10 ** 18;
    }
   
    function getBNBUSDPrice(uint80 roundId) public view returns (int) {
        (
            uint80 id, 
            int price,
            uint startedAt,
            uint timeStamp,
        ) = BNBUSD.getRoundData(roundId);
         require(timeStamp > 0, "Round not complete");
         require(block.timestamp <= timeStamp + 1 days);
        return price;
    }
    function setRate(uint256 rate)public onlyOwner() returns (bool){
         _rate =rate ;
        return true;
    }
    function getRate() public view returns (uint256){
        return _rate;
    }
    function calculatePercent(uint numerator, uint denominator) internal  pure returns (uint){
        return (denominator * (numerator * 100) ) /10000;
    }
    function _distributeVcsTokenToVault(address _beneficiary,uint listingDate,uint _totalToLock) internal  returns (bool){
        uint releaseDay;
        uint amountDue    = calculatePercent(5,_totalToLock); //5% pf the amount remaining
        uint interval = 1;
        uint startsFrom = 1;
        uint hold = 20;
        for (uint i=interval; i <= hold; i += interval ){ 
                releaseDay = listingDate + (startsFrom + i) * 30 days; 
                uint key = _vaultContract.recordShareToVault(_beneficiary, amountDue , releaseDay,9384);
                emit VaultCreated(key,_beneficiary, releaseDay,amountDue);
        }
        return true;
    }

    function closeCollection() public onlyOwner() returns(bool){
        uint256 flistingDate = _token.getFirstListingDate();
        require(flistingDate != 1,"First listing date for token has to be set");

        uint256 thirtyofbal = calculatePercent(30,_token.balanceOf(address(this))); //send 30% of bal
        _token.transfer(_vcsBucket, thirtyofbal);
        uint256 bal = _token.balanceOf(address(this));
        _token.transfer(address(_vaultContract), bal);
        _distributeVcsTokenToVault(_vcsBucket,_token.getFirstListingDate(),bal);
        return true;
    }

}