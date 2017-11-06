pragma solidity ^0.4.11;

import "./StandartToken.sol";
import "../math/SafeMath.sol";
import "../providers/IApprovalManager.sol";
import "../ownership/Ownable.sol";


contract ExternalApprovalToken is StandartToken, Ownable {
    using SafeMath for uint256;
    IApprovalManager public approvalManager;

    event TransferFromExternal(address indexed from, address indexed to, address indexed provider, uint256 value);
    function setApprovalManager(address manager) onlyOwner public returns (bool) {
        approvalManager = IApprovalManager(manager);
    }

    function transferFromExternal(address from, address to, uint256 value) public returns (bool) {
        require(address(approvalManager) != address(0));
        var (amount, provider) = approvalManager.allowance(from, msg.sender);
        require(value <= amount);
        balances[from] = balances[from].sub(value);
        balances[to] = balances[to].add(value);
        require(approvalManager.confirmTransfer(provider, from, msg.sender, value));
        TransferFromExternal(from, to, provider, value);
        return true;
    }
}