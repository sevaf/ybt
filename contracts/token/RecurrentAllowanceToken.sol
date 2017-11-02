pragma solidity ^0.4.11;

import "./StandartToken.sol";
import "../math/SafeMath.sol";

/**
 * @title Recurrent allowance token
 * @dev Token that can be aproved to transfer in predefined periods of time
 */
contract RecurrentAllowanceToken is StandartToken {

    using SafeMath for uint256;

    // allowance defenition struct
    struct AllowanceDef {
        uint ind; //index for maping iteration
        uint start; //start timestamp
        uint rec; //current recurrence 
        uint duration; //duration in seconds
        uint withdrawalPeriod; // withdrawal period in seconds
        uint amount; // amount approved
    }

    //default ithdrawal period
    uint public constant DEF_WITHDRAWAL_PERIOD = 2**256-1;

    event ApproveRecurrent(address indexed from, address indexed to, uint256 amount, uint256 start, uint256 duration);
    event RemoveRecurrent(address indexed from, address indexed to, uint256 amount, uint256 start, uint256 duration);
    event TransferRecurrent(address indexed from, address indexed to, uint256 value);

    mapping(address => mapping (address => AllowanceDef)) recurrentAllowances; 
    mapping(address => address[]) recurrentAllowancesArray;

    function approveRecurrent(address spender, uint256 start, uint256 duration, uint256 amount, uint256 withdrawalPeriod, uint256 rec) public returns (bool) {

        require(amount > 0);
        require(recurrentAllowances[msg.sender][spender].amount == 0);
        AllowanceDef memory ad = AllowanceDef(
            recurrentAllowancesArray[msg.sender].length,
            start,
            rec,
            duration,
            withdrawalPeriod,
            amount
        );
        recurrentAllowances[msg.sender][spender] = ad;
        recurrentAllowancesArray[msg.sender].push(spender);
        ApproveRecurrent(msg.sender, spender, amount, start, duration);
    }

    function removeAllowanceRecurrent(address spender) public returns (bool) {
        AllowanceDef storage ad = recurrentAllowances[msg.sender][spender];
        if (ad.amount != 0) {
            if (recurrentAllowancesArray[msg.sender].length > 1 && recurrentAllowancesArray[msg.sender].length - 1 > ad.ind) { 
                address toupdate = recurrentAllowancesArray[msg.sender][recurrentAllowancesArray[msg.sender].length - 1];
                recurrentAllowancesArray[msg.sender][ad.ind] = recurrentAllowancesArray[msg.sender][recurrentAllowancesArray[msg.sender].length - 1];
                recurrentAllowancesArray[msg.sender].length = recurrentAllowancesArray[msg.sender].length - 1;
                recurrentAllowances[msg.sender][toupdate].ind = ad.ind;
            } else if (recurrentAllowancesArray[msg.sender].length - 1 == ad.ind) {
                recurrentAllowancesArray[msg.sender].length = recurrentAllowancesArray[msg.sender].length - 1;
            } else {
                recurrentAllowancesArray[msg.sender].length = 0;
            }
            RemoveRecurrent(msg.sender, spender, ad.amount, ad.start, ad.duration);

            delete recurrentAllowances[msg.sender][spender];
            return true;
        }
        return false;
    }

    function getAllowancesAddresess(address _owner) public constant returns(address[]) {
        return recurrentAllowancesArray[_owner];
    }

    function allowanceRecurrent(address _owner, address _spender) public constant returns (uint256 amount, uint256 start, uint256 duration, uint256 rec) {

        amount = recurrentAllowances[_owner][_spender].amount;
        start = recurrentAllowances[_owner][_spender].start;
        duration = recurrentAllowances[_owner][_spender].duration;
        rec = recurrentAllowances[_owner][_spender].rec;
    }

    function transferRecurrentFrom(address _from, address _to, uint256 _value) public returns (bool) {
        AllowanceDef storage ad = recurrentAllowances[_from][msg.sender];
        require(ad.amount != 0 && ad.start < block.timestamp);
        uint256 next = ad.start.add(ad.rec.mul(ad.duration));
        uint256 tmp = block.timestamp.sub(next);
        uint256 wdp = ad.withdrawalPeriod == 0? DEF_WITHDRAWAL_PERIOD : ad.withdrawalPeriod;
        recurrentAllowances[_from][msg.sender].rec = ad.rec.add(1);
        if(tmp <= wdp) {
            balances[_from] = balances[_from].sub(_value);
            balances[_to] = balances[_to].add(_value);
            TransferRecurrent(_from, _to, _value);
            Transfer(_from, _to, _value);
        } else {
            return false;
        }
        return true;
        
    }
}