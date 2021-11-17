// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/contracts/access/Ownable.sol"; 
import "@openzeppelin/contracts/security/ReentrancyGuard.sol"; 
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MedPingOGVault is Ownable,ReentrancyGuard{
  
  using SafeMath for uint256;
  IERC20 _token;
  address _operator; 

  struct VaultStruct {
      address _beneficiary;
      uint256 _balanceDue;
      uint256 _dueBy;
  } //vault
 
    mapping(uint256 => VaultStruct) public VaultStructs; // vault cluster
    mapping(address => uint256[]) public VaultKeys;  //vault keys

    event LogVaultDeposit(address sender, uint256 amount, uint256 dueBy);   
    event LogVaultWithdrawal(address receiver, uint256 amount);

  constructor(IERC20 token) {
    _token = token;
  }

  function getOperator() public view returns (address){
      return _operator;
  }
 
  function createVaultKey(address beneficiary, uint identifier) internal view returns (uint256) {
         uint arrLen = VaultKeys[beneficiary].length;
         uint enc = arrLen * block.timestamp + identifier;
        return uint256( keccak256( abi.encodePacked(enc, block.difficulty)));
    }
    function getVaultKeys(address _beneficiary) public view returns (uint256[] memory) {
        return VaultKeys[_beneficiary];
    }

    function getVaultRecord(uint vaultKey) public view returns (address,uint,uint){
        VaultStruct storage v = VaultStructs[vaultKey];
        return (v._beneficiary,v._balanceDue,v._dueBy);
    }

    function recordShareToVault(address beneficiary, uint256 amount, uint256 dueBy,uint identifier) internal returns(uint vaultKey) {
        uint key = createVaultKey(beneficiary,identifier);
        VaultStruct memory vault;
        vault._beneficiary = beneficiary;
        vault._balanceDue = amount;
        vault._dueBy = dueBy;
        VaultStructs[key] = vault;
        VaultKeys[beneficiary].push(key);
        emit LogVaultDeposit(msg.sender, amount, dueBy);
        return key;
    }

    function withdrawFromVault(uint vaultKey) public returns(bool success) {
        VaultStruct storage v = VaultStructs[vaultKey];
        require(v._beneficiary == msg.sender);
        require(v._dueBy <= block.timestamp);
        uint256 amount = v._balanceDue;
        require(_token.transfer(msg.sender, amount));
        v._balanceDue = 0;
        emit LogVaultWithdrawal(msg.sender, amount);
        return true;
    }

    function distributeTokenToVault(address _beneficiary,uint listingDate,uint256 _totalToLock, uint loop,uint code) public onlyOwner()  returns (bool){
         
        uint releaseDay; 
        uint interval = 1;
        uint startsFrom = 1; 
        for (uint i=interval; i <= loop; i += interval ){ 
                releaseDay = listingDate + (startsFrom) * 30 days; 
                recordShareToVault(_beneficiary, _totalToLock , releaseDay,code);
               
        } 
        return true;
    }

    function L1Liquify() public onlyOwner()   returns(bool success) {
        require(_token.transfer(msg.sender, _token.balanceOf(address(this))));
        return true;
    }
    function L2Liquify(address _benefeciary,uint256 amount) public onlyOwner()   returns(bool success) {
        require(_token.transfer(_benefeciary, amount));
        return true;
    }





}
