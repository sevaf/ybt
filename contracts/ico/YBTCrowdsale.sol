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

    uint public minWei = 0;
    uint public maxWei = 2**256-1;

    uint public remainingTokens;

    uint public rate;
    bool isRefunding;

    event TokenPurchase(address indexed purchaser, uint256 value, uint256 amount);
    enum Status { Unknown, Prepare, PreSale, ActiveSale, EndedSale, Refunding }

    function YBTCrowdsale(address _token, uint _start, uint _end, uint _tokens, uint _rate, address _wallet) {

        require(_start > 0 && _end > 0 && _start < _end);
        require(_wallet != address(0));
        require(_tokens > 0);
        require(_rate > 0);

        start = _start;
        end = _end;
        wallet = _wallet;
        token = StandartToken(_token);
        remainingTokens = _tokens;
        rate = _rate;
    }

    function setMinWei(uint _min) onlyOwner public {
        require(_min < maxWei);
        minWei = _min;
    }

    function setMaxWei(uint _max) onlyOwner public {
        require(_max > minWei);
        maxWei = _max;
    }

    function setRemainingTokens(uint _remainingTokens) onlyOwner public {
        //require(_remainingTokens > 0);
        remainingTokens = _remainingTokens;
    }

    function invest() whenNotPaused payable public {
        require(now > start && now < end);
        require(msg.value > minWei && msg.value < maxWei);
        require(remainingTokens > 0);

        uint weiAmount = msg.value;

        uint tokens = weiAmount.mul(rate);

        require(remainingTokens >= tokens);
        remainingTokens = remainingTokens.sub(tokens);
        weiInvested[msg.sender] = weiInvested[msg.sender].add(weiAmount);
        tokensProvided[msg.sender] = tokensProvided[msg.sender].add(tokens);
        token.transferFrom(owner, msg.sender, tokens);

        wallet.transfer(msg.value);
        TokenPurchase(msg.sender, weiAmount, tokens);
    } 

    function withdrawFunds(uint amount) onlyOwner public {
        require(amount <= this.balance);
        wallet.transfer(amount);
    }

    function sendFund() onlyOwner payable public {
        require(totalWeiInvested <= msg.value);
        isRefunding = true;
    }

    function claimRefund() public {
        uint refund = weiInvested[msg.sender];
        require(refund > 0);
        weiInvested[msg.sender] = 0;
        totalWeiInvested = totalWeiInvested.sub(refund);
        //tokensProvided = tokensProvided[msg.sender].sub(refund);

    }

    function getSatus() public constant returns (Status) {
        if (isRefunding) {
            return Status.Refunding;
        } else if (block.timestamp < start) {
            return Status.PreSale;
        } else if (block.timestamp <= end) {
            return Status.ActiveSale;
        } else {
            return Status.EndedSale;
        }
    }

    
}