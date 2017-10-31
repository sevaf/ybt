pragma solidity ^0.4.11;


import "../math/SafeMath.sol";
import "../ownership/Ownable.sol";
import "../token/RecurrentAllowanceToken.sol";


contract RecurringBillingProvider is Ownable {

    mapping(address => bool) merchants;
    mapping(address => bytes32) public bills;
    RecurrentAllowanceToken public token;



    function RecurringBillingProvider(address _token) {
        token = RecurrentAllowanceToken(_token);
        merchants[msg.sender] = true;
    }

    function addMerchant(address merchant) onlyMerchant(msg.sender) public returns(bool isSucsess) {
        merchants[merchant] = true;
        return true;
    }

    function removeMerchant(address merchant) onlyMerchant(msg.sender) public returns(bool isSucsess) {
        require(merchant != owner);
        merchants[merchant] = false;
        return true;
    }

    function withdrawRecurring(address from, uint256 amount) onlyMerchant(msg.sender) public returns(bool isSucsess) {
        return token.transferRecurrentFrom(from, msg.sender, amount);
    }

    modifier onlyMerchant(address ad) {
        require(merchants[ad]);
        _;
    }
}
