// SPDX-License-Identifier: MIT
pragma solidity ^0.8 ;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./MedPingLockBox.sol"; 

contract MedPingToken is ERC20,MedPingLockBox{
    using SafeMath for uint256;
    uint256 tSupply = 200 * 10**6 * (10 ** uint256(decimals()));

    constructor() ERC20("MedPing", "MPG"){
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