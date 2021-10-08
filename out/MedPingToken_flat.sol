pragma solidity 0.8 ;








contract MedPingLockBox is Ownable{
    
    using SafeMath for uint256;
    address crowdsale;
    address payable burnBucket;
    uint256 crowdsaleBal; // token remaining after crowdsale 
    uint256 burnBucketBal;
    uint256 lockStageGlobal;
    mapping(uint256 => mapping(address=>bool)) provisionsTrack;
    /** If false we are are in transfer lock up period.*/
    bool public released = false;
    uint256 firstListingDate = 1; //date for first exchange listing
    
    struct lockAllowance{uint256 presale_total; uint256 privatesale_total; uint256 allowance; uint256 spent; uint lockStage;}   
    mapping(address => lockAllowance) lockAllowances; //early investors allowance profile
    mapping(address => bool) earlyInvestors;//list of early investors

    uint256 [] provisionDates;
    uint256 [] burnDates;
    mapping(uint256=>bool) burnDateStatus;

    /** MODIFIER: Limits actions to only crowdsale.*/
    modifier onlyCrowdSale() {
        require(crowdsale == msg.sender,"you are not permitted to make transactions");
        _;
    }
    /** MODIFIER: Limits actions to only burner.*/
    modifier onlyBurner() {
        require(burnBucket == msg.sender,"you are not permitted to make transactions");
        _;
    }
    /** MODIFIER: Limits token transfer until the lockup period is over.*/
    modifier canTransfer() {
        if(!released) {
            require(crowdsale == msg.sender,"you are not permitted to make transactions");
        }
        _;
    }
    /** MODIFIER: Limits and manages early investors transfer.
    *check if is early investor and if within the 30days constraint
    */
    modifier investorChecks(uint256 _value,address _sender){
        if(isEarlyInvestor(_sender)){
            if((firstListingDate + (13 * 30 days)) > block.timestamp){ //is investor and within 13 months constraint 
                 lockAllowance storage lock = lockAllowances[_sender]; 
                 if(!isAllowanceProvisioned(_sender,lockStageGlobal)){
                    provisionLockAllownces(_sender,lock.lockStage); 
                 }
                 require(lock.allowance >= _value,"allocation lower than amount you want to spend"); //validate spending amount
                 require(updateLockAllownces(_value,_sender)); //update lock spent 
            }
        }
        _;
    }
    constructor()
    Ownable() {
    }
    /** Allows only the crowdsale address to relase the tokens into the wild */
    function releaseTokenTransfer() onlyCrowdSale() public {
            released = true;       
    }
    /**Set the crowdsale address. **/
    function setReleaser(address _crowdsale) onlyOwner() public { /**Set the crowdsale address. **/
        crowdsale = _crowdsale;
    }
    /**Set the burnBucket address. **/
    function setBurner(address payable _burnBucket) onlyOwner() public { /**Set the crowdsale address. **/
        burnBucket = _burnBucket;
    }
    function setFirstListingDate(uint256 _date) public onlyCrowdSale() returns(bool){
        firstListingDate = _date; 
        uint firstReleaseDate = _date + (3 * 30 days); //3months after the listing date
        provisionDates.push(firstReleaseDate);
        for (uint256 index = 1; index <= 10; index++) { //remaining released monthly after the first release
            uint nextReleaseDate = firstReleaseDate +(index * 30 days);
            provisionDates.push(nextReleaseDate);
            
             uint _burndate = firstReleaseDate + (index *(3 * 30 days));
            burnDates.push(_burndate);
            burnDateStatus[_burndate] = false;
        }
        return true; 
    }
    /** lock early investments per tokenomics.*/
    function addToLock(uint256 _presale_total,uint256 _privatesale_total, address _investor) public onlyCrowdSale(){
        //check if the early investor's address is not registered
        if(!earlyInvestors[_investor]){
            lockAllowance memory lock;
            lock.presale_total = _presale_total;
            lock.privatesale_total = _privatesale_total;
            lock.allowance = 0;
            lock.spent = 0;
            lockAllowances[_investor] = lock;
            earlyInvestors[_investor]=true;
        }else{
            lockAllowance storage lock = lockAllowances[_investor];
            lock.presale_total +=  _presale_total;
            lock.privatesale_total +=  _privatesale_total;
        }
    }
    function investorAllowance(address investor) public view returns (uint256 presale_total, uint256 privatesale_total,uint256 allowance,uint256 spent, uint lockStage){
        lockAllowance storage l =  lockAllowances[investor];
        return (l.presale_total,l.privatesale_total,l.allowance,l.spent,l.lockStage);
    }
     /** update allowance box.*/
    function updateLockAllownces(uint256 _spending, address _sender) internal returns (bool){
        lockAllowance storage lock = lockAllowances[_sender];
        lock.allowance -= _spending;
        lock.spent += _spending;
        return true; 
    }
     /** provision allowance box.*/
    function provisionLockAllownces(address _beneficiary,uint _lockStage) internal  returns (bool){
        require(block.timestamp >= provisionDates[0]);
        lockAllowance storage lock = lockAllowances[_beneficiary];
        uint256 presaleInital = lock.presale_total;
        uint256 privatesaleInital = lock.privatesale_total;
        require(_lockStage <= 10);
        require(lock.lockStage  == _lockStage);
        if(lock.lockStage < 1){//first allowance provision
            if(presaleInital > 0){
                presaleInital = (lock.presale_total.mul(20 *100)).div(10000);
                lock.allowance += presaleInital;
            }
            if(privatesaleInital > 0){
               privatesaleInital = (lock.privatesale_total.mul(30 *100)).div(10000);
               lock.allowance += privatesaleInital;
            }
                lock.presale_total -= presaleInital;
                lock.privatesale_total -= privatesaleInital;
                lock.lockStage = 1;
                provisionsTrack[lockStageGlobal][_beneficiary] = true;
        }else if(lock.lockStage >= 1){//following allowance provision
                if(presaleInital > 0){
                    presaleInital = (lock.presale_total.mul(10 *100)).div(10000);
                    lock.allowance += presaleInital;
                }
                if(privatesaleInital > 0){
                    privatesaleInital = (lock.privatesale_total.mul(10 *100)).div(10000);
                    lock.allowance += privatesaleInital; 
                }
                lock.lockStage += 1;
                provisionsTrack[lockStageGlobal][_beneficiary] = true;
        }
        return true; 
    }
    function isAllowanceProvisioned(address _beneficiary,uint _lockStageGlobal) public view returns (bool){
         return provisionsTrack[_lockStageGlobal][_beneficiary];
    }
    function updateLockStage() onlyBurner() public returns (bool){
         lockStageGlobal +=1;
         return true;
    }
    /** update token remaining after crowdsale .*/
    function updatecrowdsaleBal(uint256 _amount,uint256 _tSupply) public onlyCrowdSale() returns(bool success) {
        crowdsaleBal    += _amount;
        burnBucketBal   = (_tSupply.mul(5 *100)).div(10000) + crowdsaleBal; // 5% of total supply + crowdsale bal
        return true;
    }
    function isEarlyInvestor(address investor) public view returns(bool){
        if(earlyInvestors[investor]){
            return true; 
        }
        return false;
    }
    function getFirstListingDate() public view returns(uint256){
        return firstListingDate;
    }
    function getProvisionDates() public view returns (uint256 [] memory){
        return provisionDates;
    }
    function getCrowdsaleBal()  public view returns(uint256) {
        return crowdsaleBal;
    }
    function getBurnBucketBal()  public view returns(uint256) {
        return burnBucketBal;
    }
    function getBurnBucket()  public view returns(address payable) {
        return burnBucket;
    }
    function tokenBurnDates() public view returns (uint256 [] memory){
        return burnDates;
    }
    function isTokenBurntOnDate(uint256 _date) public view returns (bool){
        return burnDateStatus[_date];
    }
} 
contract MedPingToken is ERC20,Ownable,MedPingLockBox{

    /// @notice Contract ownership will be renouced after all the lock and burn is fullfilled. 
    using SafeMath for uint256;
    uint256 tSupply = 200 * 10**6 * (10 ** uint256(decimals()));

    constructor() ERC20("Medping", "PING"){
        _mint(msg.sender, tSupply);
    }
    
    
    function transfer(address _to, uint256 _value) canTransfer() investorChecks(_value,msg.sender) public override returns (bool success) {
        super.transfer(_to,_value);
        return true;
    }

    function transferFrom(address _from, address _to, uint256 _value) canTransfer() investorChecks(_value,_from) public override returns (bool success) {
       super.transferFrom(_from, _to, _value);
        return true;
    }

    function burnPING(uint256 _date) public onlyBurner() returns(bool success){
        require(!isTokenBurntOnDate(_date));
        require(released);
        uint256 totalToBurn = (burnBucketBal.mul(10 *100)).div(10000); //burn 10 % of burnbucket quaterly
        _burn(msg.sender, totalToBurn);
        burnDateStatus[_date] = true;
        return true;
    }
}


