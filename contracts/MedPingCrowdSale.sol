pragma solidity 0.8;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@chainlink/contracts/src/v0.6/interfaces/AggregatorV3Interface.sol";
import "./MedPingTeamMngt.sol";

contract MedPingCrowdSale  is ReentrancyGuard,MedPingTeamManagement{
    /**
    * @Legend: CrowdsalePeriodExtended = CPE
    * @Legend: CrowdsaleOperationFinished = COF
    */
    using SafeMath for uint256;
    IERC20 public _BUSDContract;
    AggregatorV3Interface internal BNBUSD;

    uint256 public _rate;
    uint256 public _tokensSold;
    uint256 public _weiRaisedBNB;
    uint256 public _weiRaisedBUSD;
    uint256  _tokensReamaining; 
    uint256 _crossDecimal = 10**8;
    
    bool private _finalized = false;
  
    
    // Crowdsale Stages
    enum CrowdsaleStage { PreSale,PrivateSale,PublicSale,Paused,Ended }
    // Default to presale stage
    CrowdsaleStage public stage = CrowdsaleStage.Paused;
    
    mapping(CrowdsaleStage=> mapping(address => uint256)) _contributions;
    mapping(CrowdsaleStage=> mapping(address => uint256)) _receiving;
    mapping(CrowdsaleStage=> uint256) public CrowdsaleStageBalance;
    
   
    
    /**
    * @dev EVENTS:
    */
    event COF();
    event CPE(uint256 oldEndTime, uint256 newEndTime);
    event BuyPing(
        address indexed _from,
        uint256 indexed _tokens,
        uint256  _value
    );
    
    /**
     * @dev Reverts if not in crowdsale time range.
     */
    modifier onlyWhileOpen {
        require(isOpen(), "Crowdsale: not open");
        _;
    }

    constructor(
                MedPingToken token,
                MedPingInvestorsVault vault,
                IERC20 _BUSD,
                uint256 startingTime,
                uint256 endingTime,
                address payable wallet,
                address payable DevMarketing,
                address payable TeamToken,
                address payable ListingLiquidity,
                address payable OperationsManagement
                )
    ReentrancyGuard()
    MedPingTeamManagement(DevMarketing,TeamToken,ListingLiquidity,OperationsManagement,token,vault)
    { 
        require(startingTime >= block.timestamp, "Crowdsale: start time is before current time");
        require(endingTime > startingTime, "Crowdsale: start time is invalid");
        admin =  payable (msg.sender);//assign an admin
        _tokenContract = token;//link to token contract 
        _BUSDContract = _BUSD; //link to token vault contract 
        _wallet = wallet;//token wallet 
        updateStage(4);//set default stage balance
        BNBUSD = AggregatorV3Interface(BNBUSD_Aggregator);
        _startTime = startingTime;//set periods management
        _endTime = endingTime;//set periods management
        _finalized = false;//set periods management
        
    }
    function participateBNB(uint80 _roundId) payable public onlyWhileOpen returns (bool){
        uint256 _numberOfTokens = _MedPingReceiving(msg.value,_roundId);
        _preValidateParticipation(msg.value, _numberOfTokens, msg.sender);
        //require that the transaction is successful 
        _processParticipationBNB(msg.sender, _numberOfTokens);
        _postParticipation(msg.sender,msg.value,_numberOfTokens);  

        emit BuyPing(msg.sender,_numberOfTokens,msg.value); 
        return true;
    }
    function participateBUSD(uint80 _roundId) public onlyWhileOpen returns(bool){
        require(_BUSDContract.allowance(msg.sender, address(this)) > 0);
        uint busdVal = _BUSDContract.allowance(msg.sender, address(this));
        uint bnbEquv = (busdVal.div(uint256(getBNBUSDPrice(_roundId)))).mul(_crossDecimal);
        uint256 _numberOfTokens = _MedPingReceiving(bnbEquv,_roundId);
        _preValidateParticipation(bnbEquv, _numberOfTokens, msg.sender);
        require(_BUSDContract.transferFrom(msg.sender, address(this), busdVal));
        _processParticipationBUSD(msg.sender, _numberOfTokens,busdVal);
        _postParticipation(msg.sender,bnbEquv,_numberOfTokens);
        emit BuyPing(msg.sender,_numberOfTokens,busdVal); 
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
    //sets the ICO Stage, rates  and the CrowdsaleStageBalance 
    function updateStage(uint _stage)public onlyOwner returns (bool){
       
         if(uint(CrowdsaleStage.PreSale) == _stage) {
          stage = CrowdsaleStage.PreSale;
          CrowdsaleStageBalance[stage]=12500000 * (10**18) ; //
          investorMinCap   = 0.1 * (10**18);
          investorMaxCap  = 1.5 * (10**18);
          _rate = 0.0095 * (10**8); //usd 
        }else if (uint(CrowdsaleStage.PrivateSale) == _stage) {
            emptyStageBalanceToBurnBucket();
         stage = CrowdsaleStage.PrivateSale;
          CrowdsaleStageBalance[stage]=37500000 * (10**18); //
          investorMinCap   = 0.2 * (10**18);
          investorMaxCap  = 5 * (10**18);
           _rate = 0.025 * (10**8); // usd
        }
        else if (uint(CrowdsaleStage.PublicSale) == _stage) {
            emptyStageBalanceToBurnBucket();
         stage = CrowdsaleStage.PublicSale;
          CrowdsaleStageBalance[stage]=20000000 * (10**18); //
          investorMinCap   = 0.1 * (10**18);
          investorMaxCap  = 5 * (10**18);
           _rate = 0.075 * (10**8); // usd
        }else if(uint(CrowdsaleStage.Paused) == _stage){
            stage = CrowdsaleStage.Paused;
            CrowdsaleStageBalance[stage]=0;
            _rate = 0; //0.00 eth
        }else if(uint(CrowdsaleStage.Ended) == _stage){
            emptyStageBalanceToBurnBucket();
            stage = CrowdsaleStage.Ended;
            CrowdsaleStageBalance[stage]=0;
            _rate = 0; //0.00 eth
        }
        return true;
    }
    function emptyStageBalanceToBurnBucket() internal {
        uint256 perviousBal = CrowdsaleStageBalance[stage];
        if(perviousBal > 0){
            
            require(_tokenContract.transfer(_tokenContract.getBurnBucket(), perviousBal),"crowdsale balance transfer failed");
        }
    }
    function getStageBalance() public view returns (uint256) {
        return CrowdsaleStageBalance[stage];
    }
    function getParticipantGivings(CrowdsaleStage _stage,address _participant) public view returns (uint256){
        return _contributions[_stage][_participant];
    }
    function getParticipantReceivings(CrowdsaleStage _stage,address _participant) public view returns (uint256){
        return _receiving[_stage][_participant];
    }
    function _updateParticipantBalance(address _participant, uint256 _giving,uint256 _numOfTokens) internal returns (bool){
        uint256 oldGivings = getParticipantGivings(stage,_participant);
        uint256 oldReceivings = getParticipantReceivings(stage,_participant);
        
        uint256 newGivings = oldGivings.add(_giving);
        uint256 newReceiving = oldReceivings.add(_numOfTokens);
        
        _contributions[stage][_participant] = newGivings;
        _receiving[stage][_participant] = newReceiving;
        return true;
    }
    function _isIndividualCapped(address _participant, uint256 _weiAmount)  internal view returns (bool){
        uint256 _oldGiving = getParticipantGivings(stage,_participant);
        uint256 _newGiving = _oldGiving.add(_weiAmount);
        require(_newGiving >= investorMinCap && _newGiving <= investorMaxCap);
        return true;
    }
    function _addToCrowdsaleStageBalance(uint256 amount)  internal{
        uint256 currentBal = getStageBalance();
        uint256 newBal = currentBal.add(amount);
        CrowdsaleStageBalance[stage]=newBal;
    }
    function _subFromCrowdsaleStageBalance(uint256 amount)  internal{
        uint256 currentBal = getStageBalance();
        uint256 newBal = currentBal.sub(amount);
        CrowdsaleStageBalance[stage]=newBal;
    }
    function _preValidateParticipation(uint256 _sentValue,uint256 _numberOfTokens, address _participant) internal view {
        //Require that contract has enough tokens 
        require(_tokenContract.balanceOf(address(this)) >= _numberOfTokens,'token requested not available');
        //require that participant giving is between the caped range per stage
        require(_isIndividualCapped(_participant,  _sentValue),'request not within the cap range');
    }
    function _processParticipationBNB(address recipient, uint256 amount) nonReentrant() internal{
        require( _forwardBNBFunds());
        require(_tokenContract.transfer(recipient, amount));
        _weiRaisedBNB += amount;
    }
    function _processParticipationBUSD(address recipient, uint256 amount,uint256 weiAmount) nonReentrant() internal{
        require( _forwardBUSDFunds(weiAmount));
        require(_tokenContract.transfer(recipient, amount));
        _weiRaisedBUSD += amount;
    }
    function _postParticipation(address _participant,uint256 amount , uint256 _numberOfTokens) nonReentrant() internal returns(bool){
        //record participant givings and receivings
        require(_updateParticipantBalance(_participant,amount,_numberOfTokens));
        //track number of tokens sold  and amount raised
        _tokensSold += _numberOfTokens;
        //subtract from crowdsale stage balance 
        _subFromCrowdsaleStageBalance(_numberOfTokens);
        //lock investments of initial investors 
       if(stage == CrowdsaleStage.PreSale){
            _tokenContract.addToLock(_numberOfTokens,0,_participant); 
        }
        if(stage == CrowdsaleStage.PrivateSale ){
            _tokenContract.addToLock(0,_numberOfTokens,_participant);
        }
        return true;
    }
    function releaseRistrictions () internal returns(bool) {
        require(_tokenContract.getFirstListingDate() != 1,"First listing date has to be set");
        _tokenContract.releaseTokenTransfer();
        return true;
    }
    function addFirstListingDate (uint256 _date) public onlyOwner() returns (bool){
        require(_tokenContract.setFirstListingDate(_date));
        return  true;
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
    /**
    * @dev forwards funds to the sale Wallet
    */
    function _forwardBNBFunds() internal returns (bool){
        _wallet.transfer(msg.value);
        return true;
    }
    /**
    * @dev forwards funds to the sale Wallet
    */
    function _forwardBUSDFunds(uint256 weiAmount) internal returns (bool){
        _BUSDContract.transfer(_wallet,weiAmount);
        return true;
    }

    function startTime() public view returns (uint256) {
        return _startTime;
    }
    function endTime() public view returns (uint256) {
        return _endTime;
    }
    function isOpen() public view returns (bool) {
       require(block.timestamp >= _startTime && block.timestamp <= _endTime ,"Crowdsale: not opened");
       require(stage != CrowdsaleStage.Paused && stage != CrowdsaleStage.Ended,"Crowdsale: not opened");
       return true;
    }
    function hasClosed() public view returns (bool) {
        return block.timestamp > _endTime;
    }
    function extendTime(uint256 newEndTime) public onlyOwner {
        require(!hasClosed(), "Crowdsale: close already");
        require(newEndTime > _endTime, "Crowdsale: new endtime must be after current endtime");
        _endTime = newEndTime;
        emit CPE(_endTime, newEndTime);
    }
    function setCaps(uint256 _softCap, uint256 _hardCap) public onlyOwner returns (bool){
        medPingSoftCap = _softCap;
        medPingHardCap =_hardCap;
        return true;
    }
    function getSoftCap() public view returns (uint256){
        return medPingSoftCap;
    }
    function getHardCap() public view returns (uint256){
        return medPingHardCap;
    }
    function getInvestorMinCap() public view returns (uint256){
        return investorMinCap;
    }
    function getInvestorMaxCap() public view returns (uint256){
        return investorMaxCap;
    }
    function lockTeamVault() public onlyOwner() returns (bool){
        require(hasClosed(), "Crowdsale: has not ended");
        lockVault();
        return true;
    }
    function isFinalized() public view returns (bool) {
        return _finalized;
    }
    
    function finalize() public onlyOwner{
        require(vaultIsLocked(), "Vault not locked");
        require(!isFinalized(), "Crowdsale: already finalized");
        require(updateStage(4),"Crowdsale: should be marked as ended");
        require(releaseRistrictions(),"Unable to release Ristrictions");
        _finalized = true;
        uint256 tsupply = _tokenContract.totalSupply();
        uint256 crowdsaleTk = (tsupply.mul(20*100)).div(1000); //balance of crowdsale contract
        uint256 crowdsaleBal = crowdsaleTk - _tokensSold;
        //transfer remaining tokens back to admin account then update the balance sheet
         require(_tokenContract.updatecrowdsaleBal(crowdsaleBal,tsupply),"crowdsale balance update failed");
        emit COF();
    }
    
}