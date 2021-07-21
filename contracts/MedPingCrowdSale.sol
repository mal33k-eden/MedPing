pragma solidity 0.8;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./MedPingToken.sol"; 
import "./MedPingInvestorsVault.sol"; 
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@chainlink/contracts/src/v0.6/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract MedPingCrowdSale  is Ownable, ReentrancyGuard{
    /**
    * @Legend: CrowdsalePeriodExtended = CPE
    * @Legend: CrowdsaleOperationFinished = COF
    */
    using SafeMath for uint256;
    address payable admin;
    MedPingToken public _tokenContract;
    MedPingInvestorsVault public _vaultContract;
    IERC20 public _BUSDContract;
    uint256 public _rate;
    uint256 public _tokensSold;
    uint256 public _weiRaised;
    uint256  _tokensReamaining; 
    address payable  _wallet;
    uint256 _crossDecimal = 10**8; 

    uint256 _startTime;
    uint256 _endTime;
    bool private _finalized;
    event COF();
    event CPE(uint256 oldEndTime, uint256 newEndTime);
    // Crowdsale Stages
    enum CrowdsaleStage { PreSale,PrivateSale,PublicSale,Paused,Ended }
    // Default to presale stage
    CrowdsaleStage public stage = CrowdsaleStage.Paused;
    // Track investor contributions
    uint256  investorMinCap;
    uint256  investorMaxCap;
    uint256  medPingHardCap;
    uint256  medPingSoftCap;

    mapping(CrowdsaleStage=> mapping(address => uint256)) _contributions;
    mapping(CrowdsaleStage=> mapping(address => uint256)) _receiving;
    mapping(CrowdsaleStage=> uint256) public CrowdsaleStageBalance;

    uint numParticipants;

    AggregatorV3Interface internal BNBUSD;

    address BNBUSD_Aggregator = 0x2514895c72f50D8bd4B4F9b1110F0D6bD2c97526;

    address payable _DevMarketing;
    address payable _TeamToken;
    address payable _ListingLiquidity;
    address payable _OperationsManagement;

    uint256 public _DevMarketingPercentage = 5;
    uint256 public _TeamTokenPercentage = 18;
    uint256 public _ListingLiquidityPercentage = 27;
    uint256 public _OperationsManagementPercentage =5;

    uint256 public _DevMarketing_percentPerReleaseInterval = 5;
    uint256 public _TeamToken_percentPerReleaseInterval = 10;
    uint256 public _ListingLiquidity_percentPerReleaseInterval = 1;
    uint256 public _OperationsManagement_percentPerReleaseInterval =5;

    uint256 public _DevMarketing_ReleaseInterval = 1; //monthly 
    uint256 public _TeamToken_ReleaseInterval = 3; //every 3 month
    uint256 public _ListingLiquidity_ReleaseInterval = 1; //monthly
    uint256 public _OperationsManagement_ReleaseInterval =1;

    uint256 public _DevMarketing_TotalDur = 20; //held for 20 month space
    uint256 public _TeamToken_TotalDur = 30;
    uint256 public _ListingLiquidity_TotalDur = 27;
    uint256 public _OperationsManagement_TotalDur =20;

    uint256 public _DevMarketing_ID = 8976; 
    uint256 public _TeamToken_ID = 7654;
    uint256 public _ListingLiquidity_ID = 6609;
    uint256 public _OperationsManagement_ID =7654;

    /**
     * @dev Reverts if not in crowdsale time range.
     */
    modifier onlyWhileOpen {
        require(isOpen(), "Crowdsale: not open");
        _;
    }

    event BuyPing(
        address indexed _from,
        uint256 indexed _tokens,
        uint256  _value
    );


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
    Ownable() ReentrancyGuard()
    {
        // 
        require(startingTime >= block.timestamp, "Crowdsale: start time is before current time");
        //
        require(endingTime > startingTime, "Crowdsale: start time is invalid");
        //assign an admin
        admin =  payable (msg.sender);
        //link to token contract 
        _tokenContract = token;
        //link to token contract 
        _vaultContract = vault;
        _BUSDContract = _BUSD;
        //token wallet 
        _wallet = wallet;
        //set default stage balance 
        updateStage(4);
        
        BNBUSD = AggregatorV3Interface(BNBUSD_Aggregator);
         //set periods manaagement
        _startTime = startingTime;
        _endTime = endingTime;
        _finalized = false;

        //set tokenomics
        _DevMarketing = DevMarketing;
        _TeamToken = TeamToken;
        _ListingLiquidity = ListingLiquidity;
        _OperationsManagement = OperationsManagement;
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
    function updateStage(uint _stage)public onlyOwner returns (bool success){

         if(uint(CrowdsaleStage.PreSale) == _stage) {
          stage = CrowdsaleStage.PreSale;
          CrowdsaleStageBalance[stage]=12500000 * (10**18) ; //
          investorMinCap   = 0.1 * (10**18);
          investorMaxCap  = 1.5 * (10**18);
          _rate = 0.0095 * (10**8); //usd 
        }else if (uint(CrowdsaleStage.PrivateSale) == _stage) {
         stage = CrowdsaleStage.PrivateSale;
          CrowdsaleStageBalance[stage]=37500000 * (10**18); //
          investorMinCap   = 0.2 * (10**18);
          investorMaxCap  = 5 * (10**18);
           _rate = 0.025 * (10**8); // usd
        }
        else if (uint(CrowdsaleStage.PublicSale) == _stage) {
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
            stage = CrowdsaleStage.Ended;
            CrowdsaleStageBalance[stage]=0;
            _rate = 0; //0.00 eth
        }
        return true;
    }
    function getStageBalance() public view returns (uint256) {
        return CrowdsaleStageBalance[stage];
    }
    function getParticipantGivings(address _participant) public view returns (uint256){
        return _contributions[stage][_participant];
    }
    function getParticipantReceivings(address _participant) public view returns (uint256){
        return _receiving[stage][_participant];
    }
    function _updateParticipantBalance(address _participant, uint256 _giving,uint256 _numOfTokens) internal{
        uint256 oldGivings = getParticipantGivings(_participant);
        uint256 oldReceivings = getParticipantReceivings(_participant);
        
        uint256 newGivings = oldGivings.add(_giving);
        uint256 newReceiving = oldReceivings.add(_numOfTokens);
        
        _contributions[stage][_participant] = newGivings;
        _receiving[stage][_participant] = newReceiving;
    }
    function _isIndividualCapped(address _participant, uint256 _weiAmount)  internal view returns (bool){
        uint256 _oldGiving = getParticipantGivings(_participant);
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
    }
    function _processParticipationBUSD(address recipient, uint256 amount,uint256 weiAmount) nonReentrant() internal{
        require( _forwardBUSDFunds(weiAmount));
        require(_tokenContract.transfer(recipient, amount));
    }
    function _postParticipation(address _participant,uint256 amount , uint256 _numberOfTokens) nonReentrant() internal returns(bool){
        //record participant givings and receivings
        _updateParticipantBalance(_participant,amount,_numberOfTokens);
        //track number of tokens sold  and amount raised
        _tokensSold += _numberOfTokens;
        _weiRaised += amount;
        //subtract from crowdsale stage balance 
        _subFromCrowdsaleStageBalance(_numberOfTokens);
        //lock investments of initial investors 
       if(stage == CrowdsaleStage.PreSale || stage == CrowdsaleStage.PrivateSale ){
            _tokenContract.addToLock(_numberOfTokens, _participant);
        }
        return true;
    }
    function releaseRistrictions () public onlyOwner() {
        require(isFinalized(),"Crowdsale is not finanlized");
        _tokenContract.releaseTokenTransfer();
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
    function _extendTime(uint256 newEndTime) public onlyOwner {
        require(!hasClosed(), "Crowdsale: close already");
        require(newEndTime > _endTime, "Crowdsale: new endtime must be after current endtime");

        emit CPE(_endTime, newEndTime);
        _endTime = newEndTime;

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
    function isFinalized() public view returns (bool) {
        return _finalized;
    }
    function finalize() public onlyOwner{
        require(!_finalized, "Crowdsale: already finalized");
        require(hasClosed(), "Crowdsale: has not ended");
        uint totalSup = 100000000;

        _finalized = true;

        //Dev&Marketing
        uint devmarketTotal = (totalSup * (_DevMarketingPercentage * 100) ) /10000; 
        EffectDistributionAndLockRelease(_DevMarketing, devmarketTotal, _DevMarketing_TotalDur, _DevMarketing_ReleaseInterval, _DevMarketing_percentPerReleaseInterval,_DevMarketing_ID);

        //Founder 1
        uint teamTokenTotal = (totalSup * (_TeamTokenPercentage * 100) ) /10000; 
        EffectDistributionAndLockRelease(_TeamToken, teamTokenTotal, _TeamToken_TotalDur, _TeamToken_ReleaseInterval, _TeamToken_percentPerReleaseInterval,_TeamToken_ID);

        //Listing & Liquidity
        uint listingLiquidityTotal = (totalSup * (_ListingLiquidityPercentage * 100) ) /10000; 
        EffectDistributionAndLockRelease(_ListingLiquidity, listingLiquidityTotal, _ListingLiquidity_TotalDur, _ListingLiquidity_ReleaseInterval, _ListingLiquidity_percentPerReleaseInterval,_ListingLiquidity_ID);

        //Operations & Management
        uint operationsManagementTotal = (totalSup * (_OperationsManagementPercentage * 100) ) /10000;
        EffectDistributionAndLockRelease(_OperationsManagement, operationsManagementTotal, _OperationsManagement_TotalDur, _OperationsManagement_ReleaseInterval, _OperationsManagement_percentPerReleaseInterval,_OperationsManagement_ID);

        emit COF();
    }
    function EffectDistributionAndLockRelease(address _beneficiary, uint _totalValue,uint  _totalDur, uint _releaseInterval, uint _percentPerReleaseInterval,uint identifier) internal returns (bool){

            uint intervalValue;
            uint releaseDay;
            uint totalValue = _totalValue;
            uint totalDur = _totalDur;
            uint interval = _releaseInterval; 
            uint percentPerInterval = _percentPerReleaseInterval;
            intervalValue = (totalValue * (percentPerInterval * 100) ) /10000;
            intervalValue = (totalValue * (percentPerInterval * 100) ) /10000;
            for (interval; interval <= totalDur; interval ++ ) {  //for loop example
                releaseDay = block.timestamp + interval * 1 days; //CHANGE BACK TO 30 DAYS
                _vaultContract.recordShareToVault(_beneficiary, intervalValue * (10 **18) , releaseDay,identifier);
            }
        return true;
    }
}