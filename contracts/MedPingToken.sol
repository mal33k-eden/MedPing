pragma solidity 0.8 ;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract MedPingToken is ERC20,Ownable{

    using SafeMath for uint256;
    uint256 tSupply = 200 * 10**6 * (10 ** uint256(decimals()));
    /** If false we are are in transfer lock up period.*/
    bool public released = false;
    address public crowdsale; //crowdsale address
    uint256 firstListingDate; //date for first exchange listing
    struct lockAllowance{
        uint256 total; uint256 allowance; uint256 spent; uint lockStage;
    }
    mapping(address => lockAllowance) lockAllowances; //early investors allowance profile
    mapping(address => bool) public earlyInvestors;//list of early investors

    /** MODIFIER: Limits token transfer until the lockup period is over.*/
    modifier canTransfer() {
        if(!released) {
            require(crowdsale == msg.sender,"you are not permitted to make transactions");
        }
        _;
    }
    /** MODIFIER: Limits actions to only crowdsale.*/
    modifier onlyCrowdSale() {
        require(crowdsale == msg.sender,"you are not permitted to make transactions");
        _;
    }
    /** MODIFIER: Limits and manages early investors transfer.*/
    modifier investorChecks(uint256 _value){
        if(firstListingDate + 30 days < block.timestamp ){ //before the 30days of the first listing date
            if(earlyInvestors[msg.sender]){
                updateLockAllownces(); //provision allowance and update stage
                lockAllowance storage lock = lockAllowances[msg.sender]; 
                require(lock.spent <= _value); //validate spending amount
                updateLockSpent(_value); //update lock spent 
            }
        }
        _;
    }
    
    constructor() ERC20("Medping", "PING"){
        _mint(msg.sender, tSupply);
    }
    /** Allows only the crowdsale address to relase the tokens into the wild */
    function releaseTokenTransfer() onlyCrowdSale() public {
            released = true;       
    }
    /**Set the crowdsale address. **/
    function setReleaser(address _crowdsale) onlyOwner() public {
        crowdsale = _crowdsale;
    }
     /** lock early investments per tokenomics.*/
    function addToLock(uint256 _total,address _investor) public onlyCrowdSale(){
        //check if the early investor's address is not registered
        if(!earlyInvestors[_investor]){
            lockAllowance memory lock;
            lock.total = _total;
            lock.allowance = 0;
            lock.spent = 0;
            lockAllowances[_investor] = lock;
            earlyInvestors[_investor]=true;
        }else{
            updateLockTotal(_total,_investor);
        }
    }
     /** update investments lock total.*/
    function updateLockTotal(uint256 _total, address _investor) internal returns(bool){
        lockAllowance storage lock = lockAllowances[_investor];
        lock.spent = lock.total + _total;
        return true;
    }
     /** update lock quota.*/
    function updateLockSpent(uint256 _spent) internal returns(bool){
        lockAllowance storage lock = lockAllowances[msg.sender];
        lock.spent = lock.spent + _spent;
        return true;
    }

     /** update allowance box.*/
    function updateLockAllownces() internal returns (bool){
        lockAllowance storage lock = lockAllowances[msg.sender];
        if(firstListingDate + 7 days >= block.timestamp && firstListingDate + 13 days <= block.timestamp){
            if(lock.lockStage < 1){//first allowance 
                lock.allowance = (lock.total.mul(50 *100)).div(10000); //provision allowance = 50% of investments
                lock.lockStage = 1;
            }
            
        }else if(firstListingDate + 14 days >= block.timestamp && firstListingDate + 29 days <= block.timestamp){
            
            if(lock.lockStage == 1){//second allowance
                lock.allowance = (lock.total.mul(70 *100)).div(10000); //provision allowance = 70% of remaining investments
                lock.lockStage = 2;
            }
        }
        
        return true; 
    }
    function setFirstListingDate(uint256 _date) public onlyOwner() returns(bool){
        firstListingDate = _date;
        return true; 
    } 
    function getFirstListingDate() public view returns(uint256){
        return firstListingDate;
    }
    function transfer(address _to, uint256 _value) canTransfer() investorChecks(_value) public override returns (bool success) {
        super.transfer(_to,_value);
        return true;
    }
}