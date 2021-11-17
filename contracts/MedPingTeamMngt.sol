// SPDX-License-Identifier: MIT
pragma solidity ^0.8; 
import "./MedPingToken.sol"; 
import "./MedPingInvestorsVault.sol"; 
import "@openzeppelin/contracts/access/Ownable.sol";
contract MedPingTeamManagement is Ownable{
    uint  totalSup;
    MedPingInvestorsVault  _vaultContract;
    MedPingToken  _tokenContract;
    // Track investor contributions
    uint256  investorMinCap;
    uint256  investorMaxCap;
    uint256  medPingHardCap;
    uint256  medPingSoftCap;
    uint numParticipants;
    uint256 _startTime;
    uint256 _endTime;
      bool private _vaultLocked= false;
     /**
     * @dev ADDRESSES.
     */
    //address BNBUSD_Aggregator = 0x2514895c72f50D8bd4B4F9b1110F0D6bD2c97526;
    address payable admin;
    address payable  _wallet;
    address  public _DevMarketing;
    address  public _TeamToken;
    address  public _ListingLiquidity;
    address  public _OperationsManagement;

    struct TeamMembersLock{
        uint256 _percent;
        uint256 _releasePercent;
        uint256 _releaseInterval;
        uint256 _releaseStarts;
        uint256 _holdDuration;
        uint256 _vaultKeyId;
    }
    mapping(address => TeamMembersLock) private  TeamMembersLockandEarlyInvestorsProfile;

    event VaultCreated(
        uint256 indexed _vaultKey,
        address indexed _beneficiary,
        uint256  releaseDay,
        uint256 amount
    );
    constructor (address payable DevMarketing,
                address payable TeamToken,
                address payable ListingLiquidity,
                address payable OperationsManagement,
                MedPingToken token,
                MedPingInvestorsVault vault
                )Ownable(){
        //set tokenomics
        _DevMarketing = DevMarketing;
        _TeamToken = TeamToken;
        _ListingLiquidity = ListingLiquidity;
        _OperationsManagement = OperationsManagement;
        _vaultContract = vault;//link to token vault contract 
        _tokenContract = token; //link to token contract et
        totalSup = _tokenContract.totalSupply();
    }

    function vaultIsLocked() public view returns (bool) {
        return _vaultLocked;
    }
    function calculatePercent(uint numerator, uint denominator) internal  pure returns (uint){
        return (denominator * (numerator * 100) ) /10000;
    }
    function setTeamMembersLock(address _beneficiary, uint percent,uint releaseInterval,  uint releasePercent, uint holdDuration, uint vaultKeyId,uint releaseStarts ) public onlyOwner returns (bool){
        TeamMembersLock memory lock;
        lock._percent = percent;
        lock._releasePercent = releasePercent;
        lock._releaseInterval = releaseInterval;
        lock._releaseStarts = releaseStarts;
        lock._holdDuration = holdDuration;
        lock._vaultKeyId = vaultKeyId;
        TeamMembersLockandEarlyInvestorsProfile[_beneficiary] = lock;
        return true;
    }
    function getTeamMembersLock(address _beneficiary) public view returns (uint256 percent,uint256 holdDuration,uint256 interval,uint256 releaserpercent,uint256 vualtKeyId,uint256 releaseStarts){
        TeamMembersLock storage lock = TeamMembersLockandEarlyInvestorsProfile[_beneficiary];
        return (lock._percent,lock._holdDuration,lock._releaseInterval,lock._releasePercent,lock._vaultKeyId,lock._releaseStarts);
    }
    function distributeToVault(address _beneficiary,uint listingDate) internal  returns (bool){
        uint releaseDay;
        TeamMembersLock storage lock = TeamMembersLockandEarlyInvestorsProfile[_beneficiary];
        uint totalFunds    = calculatePercent(lock._percent, totalSup);
        uint amountDue     = calculatePercent(lock._releasePercent, totalFunds);
        uint interval = lock._releaseInterval;
        uint startsFrom = lock._releaseStarts;
        uint hold = lock._holdDuration;
        for (uint i=interval; i <= hold; i += interval ){ 
                releaseDay = listingDate + (startsFrom + i) * 30 days; 
                uint key = _vaultContract.recordShareToVault(_beneficiary, amountDue , releaseDay,lock._vaultKeyId);
                emit VaultCreated(key,_beneficiary, releaseDay,amountDue);
        }
        return true;
    }
    function lockVault() internal {
        uint256 flistingDate = _tokenContract.getFirstListingDate();
        require(flistingDate != 1,"First listing date for token has to be set");
        require(!_vaultLocked, "vault already locked");
        //Dev&Marketing
        require(distributeToVault(_DevMarketing,flistingDate));
        // Team Token
        require(distributeToVault(_TeamToken,flistingDate));
        //Listing & Liquidity
        require(distributeToVault(_ListingLiquidity,flistingDate));
        //Operations & Management
        require(distributeToVault(_OperationsManagement,flistingDate));
         _vaultLocked = true;
    }

}