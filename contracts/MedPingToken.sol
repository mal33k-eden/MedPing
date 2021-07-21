pragma solidity 0.8 ;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract MedPingToken is ERC20,Ownable{

    using SafeMath for uint256;
    uint256 tSupply = 200 * 10**6 * (10 ** uint256(decimals()));
    /** If false we are are in transfer lock up period.*/
    bool public released = false;
    /**Only the crowdsale address can make transfer during the lock up period */
    address public crowdsale;
    uint256 firstListingDate;
    struct lockAllowance{
        uint256 total; uint256 allowance; uint256 spent; uint lockStage;
    }
    mapping(address => lockAllowance) lockAllowances;
    mapping(address => bool) public earlyInvestors;
    

    /** Limit token transfer until the lockup period is over.*/
    modifier canTransfer() {
        if(!released) {
            require(crowdsale == msg.sender,"you are not permitted to make transactions");
        }
        _;
    }
    modifier onlyCrowdSale() {
        require(crowdsale == msg.sender,"you are not permitted to make transactions");
        _;
    }
    modifier investorChecks(uint256 _value){
        if(firstListingDate + 30 days < block.timestamp ){
            if(earlyInvestors[msg.sender]){
                updateLockAllownces();
                lockAllowance storage lock = lockAllowances[msg.sender];
                require(lock.spent <= _value);
                updateLockSpent(_value);
            }
        }
        _;
    }
    
    constructor() ERC20("Medping", "PING"){
        _mint(msg.sender, tSupply);
    }
    /** Allow only the crowdsale address to relase the tokens into the wild */
    function releaseTokenTransfer() onlyCrowdSale() public {
            released = true;       
    }
    /**Set the crowdsale address. **/
    function setReleaser(address _crowdsale) onlyOwner() public {
        crowdsale = _crowdsale;
    }
     /** lock early investments per business logic.*/
    function addToLock(uint256 _total,address _investor)public onlyCrowdSale(){
        if(!earlyInvestors[_investor]){
            lockAllowance memory lock;
            lock.total = _total;
            lock.allowance = 0;
            lock.spent = 0;
            lockAllowances[_investor] = lock;
            earlyInvestors[_investor]=true;
        }else{
            updateLockTotal(_total);
        }
        
    }
     /** update investments lock total.*/
    function updateLockTotal(uint256 _total) internal returns(bool){
        lockAllowance storage lock = lockAllowances[msg.sender];
        lock.spent = lock.total + _total;
        //emit LogVaultWithdrawal(msg.sender, amount);
        return true;
    }
     /** update lock quota.*/
    function updateLockSpent(uint256 _spent) internal returns(bool){
        lockAllowance storage lock = lockAllowances[msg.sender];
        lock.spent = lock.spent + _spent;
        //emit LogVaultWithdrawal(msg.sender, amount);
        return true;
    }

     /** update lock box.*/
    function updateLockAllownces() internal returns (bool){
        lockAllowance storage lock = lockAllowances[msg.sender];
        if(firstListingDate + 7 days >= block.timestamp && firstListingDate + 13 days <= block.timestamp){
            if(lock.lockStage < 1){
                lock.allowance = (lock.total.mul(50 *100)).div(10000);
                lock.lockStage = 1;
            }
            //first allowance 
        }else if(firstListingDate + 14 days >= block.timestamp && firstListingDate + 29 days <= block.timestamp){
            //second allowance
            if(lock.lockStage == 1){
                lock.allowance = (lock.total.mul(70 *100)).div(10000);
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