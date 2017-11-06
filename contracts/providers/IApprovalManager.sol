pragma solidity ^0.4.11;


contract IApprovalManager {
    
    //function setParent()
    function allowance(address owner, address spender) public constant returns (uint256, address);
    function approve(
        address provider, 
        address spender, 
        uint256 value, 
        bytes payload) public returns (bool);
    function removeApproval(address provider, address spender) returns (bool);
    function confirmTransfer(
        address provider, 
        address owner, 
        address spender, 
        uint256 value) returns (bool);

}