pragma solidity ^0.4.2;

import '../math/SafeMath.sol';
import "../ownership/Pausable.sol";
import "../token/StandartToken.sol";

contract YBTCrowdsale is Pausable {

    using SafeMath for uint256;

    StandartToken public token;

    address public wallet;

    mapping (address => uint) public weiInvested;
    mapping (address => uint) public tokensProvided;

    uint public totalWeiInvested;
    uint public totalTokensProvided;

    uint public start;
    uint public end;

    enum Status { Unknown, Prepare, PreSale, ActiveSale, EndedSale }

    function YBTCrowdsale(address _token, uint _start, uint _end, address _wallet) {

        require(_start > 0 && _end > 0 && _start < _end);
        require(_wallet != address(0));

        start = _start;
        end = _end;
        wallet = _wallet;
        token = StandartToken(_token);
    }


    function investInternal(address investor, uint amount) whenNotPaused private {

    }

    function getSatus() public constant returns (Status) {
        if (block.timestamp < start) {
            return Status.PreSale;
        } else if (block.timestamp <= end) {
            return Status.ActiveSale;
        } else {
            return Status.EndedSale;
        }
    }

    
}