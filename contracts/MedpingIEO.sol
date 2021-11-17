// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@chainlink/contracts/src/v0.6/interfaces/AggregatorV3Interface.sol";
import "./MedPingToken.sol"; 
contract MedPingIEO is ReentrancyGuard, Ownable{

    using SafeMath for uint256;
    IERC20 public _BUSDContract;
    AggregatorV3Interface internal BNBUSD;
    MedPingToken  _tokenContract; 
    uint256  investorMinCap;
    uint256  investorMaxCap;

    uint256 public _rate;
    
    uint256 public _weiRaised;
    uint256  _tokensReamaining; 
    uint256 _crossDecimal = 10**8;
    address payable  _wallet;
    address   _vcsBucket;

    bool _finalized;
     
    uint256 public _tokensSold;
    mapping(address => uint256) _contributions;
    mapping(address => uint256) _receiving;

    event BuyPing(
        address indexed _from,
        uint256 indexed _tokens,
        uint256  _value
    );
    modifier onlyWhenOpen {
        require(IEOIsOpen(), "IEO SALE: not open");
        _;
    }
    // Sale Stages
    enum CStage {Sale,Paused,Ended }
    // Default to presale stage
    CStage public stage = CStage.Sale;
    constructor(
                address payable wallet,
                MedPingToken token, 
                address _aggregator,
                address vcsBucket
                )
    Ownable()
    ReentrancyGuard(){

        _wallet = wallet;
        _tokenContract = token;//link to token contract   
        _rate = 0.0750 * (10**8); // usd
        BNBUSD = AggregatorV3Interface(_aggregator);
        investorMinCap   = 0.1 * (10**18);
        investorMaxCap  = 2 * (10**18);
        updateStage(1);
        _vcsBucket = vcsBucket;

    }


//add a modifier for only when stage is sale
    function participateBNB(uint80 _roundId) payable public  onlyWhenOpen() returns (bool){
        uint256 _numberOfTokens = _MedPingReceiving(msg.value,_roundId);
        _preValidateParticipation(msg.value, _numberOfTokens, msg.sender);
        //require that the transaction is successful 
        _processBNB(msg.sender, _numberOfTokens);
        _postParticipation(msg.sender,msg.value,_numberOfTokens);  

        emit BuyPing(msg.sender,_numberOfTokens,msg.value); 
        return true;
    }
    function _MedPingReceiving(uint256 _weiSent, uint80 _roundId) internal view returns (uint256 ){
        int _channelRate = 0;
        _channelRate  =  getBNBUSDPrice(_roundId);
        int _MedRate = int(_rate)/(_channelRate/int(_crossDecimal));
        uint256 _weiMedRate =  uint256((_MedRate * 10 **18 )/int(_crossDecimal));
        uint256 tempR = _weiSent.div(_weiMedRate);
        return tempR * 10 ** 18;
    }
    /**
     * Returns the BNBUSD latest price
     */
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
    function _isIndividualCapped(address _participant, uint256 _weiAmount)  internal view returns (bool){
        uint256 _oldGiving = _contributions[_participant];
        uint256 _newGiving = _oldGiving.add(_weiAmount);
        require(_newGiving >= investorMinCap && _newGiving <= investorMaxCap);
        return true;
    }
    function _preValidateParticipation(uint256 _sentValue,uint256 _numberOfTokens, address _participant) internal view {
        //Require that contract has enough tokens 
        require(_tokenContract.balanceOf(address(this)) >= _numberOfTokens,'token requested not available');
        //require that participant giving is between the caped range per stage
        require(_isIndividualCapped(_participant,  _sentValue),'request not within the cap range');
    }
    function IEOIsOpen() public view  returns(bool){
        if (uint(stage) == 0) {
            return true;
        } 
        return false;
    }
    
    function _processBNB(address recipient, uint256 amount) nonReentrant() internal{
        require( _forwardFunds());
        require(_tokenContract.transfer(recipient, amount));
        _weiRaised += amount;
    }
    function _postParticipation(address _participant,uint256 amount , uint256 _numberOfTokens) nonReentrant() internal returns(bool){
        //record participant givings and receivings
        require(_updateParticipantBalance(_participant,amount,_numberOfTokens),"CUSTOMER PROFILE UPDATE UNSUCCESSFUL");
        //track number of tokens sold  and amount raised
        _tokensSold += _numberOfTokens;
        return true;
    }
    function _updateParticipantBalance(address _participant, uint256 _giving,uint256 _numOfTokens) internal returns (bool){
        uint256 _oldGiving = _contributions[_participant];
        uint256 oldReceivings = _receiving[_participant];
         
        uint256 newGiving = _oldGiving.add(_giving);
        uint256 newReceiving = oldReceivings.add(_numOfTokens);
        
        _contributions[_participant] = newGiving;
        _receiving[_participant] = newReceiving;
        return true;
    }
    function _forwardFunds() internal returns (bool){
       _wallet.transfer(msg.value);
        return true;
    }

    function updateStage(uint _stage)public onlyOwner returns (bool){
       
        if (uint(CStage.Sale) == _stage) {
            // emptyStageBalanceToBurnBucket();
          stage = CStage.Sale;
          investorMinCap   = 0.1 * (10**18);
          investorMaxCap  = 5 * (10**18);
           _rate = 0.075 * (10**8); // usd
        }else if(uint(CStage.Paused) == _stage){
            stage = CStage.Paused;
            _rate = 0; //0.00 eth
        }else if(uint(CStage.Ended) == _stage){ 
            stage = CStage.Ended; 
            _rate = 0; //0.00 eth
        }
        return true;
    }
    function isFinalized() public view returns (bool) {
        return _finalized;
    }
    
    function finalize() public onlyOwner{
         
        require(!isFinalized(), "IEO: already finalized");
        require(updateStage(2),"IEO: should be marked as ended");
        _finalized = true;
        uint256 IEOBal = _tokenContract.balanceOf(address(this));
        //transfer remaining tokens back to admin account then update the balance sheet
        require(_tokenContract.transfer(_vcsBucket, IEOBal),"IEO balance update failed");
        
    }

}