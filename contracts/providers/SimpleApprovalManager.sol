pragma solidity ^0.4.11;

import "../ownership/Ownable.sol";
import "./IApprovalManager.sol";
import "../math/SafeMath.sol";


contract SimpleApprovalManager is Ownable, IApprovalManager {

    using SafeMath for uint256;
    mapping (address => mapping (address => uint256)) allowed;

    event Approval(address indexed owner, address indexed spender, uint256 value);
    event RemoveApproval(address indexed owner, address indexed spender);
    event ComfirmTransfer(address indexed owner, address indexed spender, uint256 value);

    function SimpleApprovalManager() {

    }

    function approve(
            address provider, 
            address spender, 
            uint256 value, 
            bytes payload) public returns (bool) {

            require(value > 0 && allowed[msg.sender][spender] == 0);
            allowed[msg.sender][spender] = value;
            Approval(msg.sender, spender, value);
            return true;
        }

    function allowance(address owner, address spender) public constant returns (uint256, address) {
        return (allowed[owner][spender], this);
    }

    function removeApproval(address provider, address spender) returns (bool) {
        allowed[msg.sender][spender] = 0;
        RemoveApproval(msg.sender, spender);
        return true;
    }


    function confirmTransfer(
        address provider, 
        address owner, 
        address spender, 
        uint256 value) returns (bool) {

        uint256 _allowance = allowed[owner][spender];
        allowed[owner][spender] = _allowance.sub(value);
        ComfirmTransfer(owner, spender, value);
        return true;

    }
}