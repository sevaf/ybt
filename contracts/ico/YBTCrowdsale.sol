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

    uint public minInvestWei = 0;
    uint public maxInvestWei = 2**256-1;

    uint public additionalBonusWei = 0;

    uint public minGoalWei;
    uint public loadedRefundAmount = 0;
    uint public totalWeiRefunded = 0;

    uint public rate;

    event TokenPurchase(address indexed purchaser, uint256 weiAmount, uint256 tokensAmount);
    event Refund(address indexed purchaser, uint256 weiAmount);
    enum Status { Unknown, Prepare, PreSale, ActiveSale, Success, Failed, Refunding }

    function YBTCrowdsale(address _token, uint _start, uint _end, uint _rate, uint _minGoal, uint _additionalBonus, address _wallet) {

        require(_start > 0 && _end > 0 && _start < _end);
        require(_wallet != address(0));
        require(_rate > 0);
        require(_minGoal > 0);

        start = _start;
        end = _end;
        wallet = _wallet;
        token = StandartToken(_token);
        rate = _rate;
        minGoalWei = _minGoal;
        additionalBonusWei = _additionalBonus;
    }

    function setMinWei(uint _min) onlyOwner public {
        require(_min < maxInvestWei);
        minInvestWei = _min;
    }

    function setAdditionalBonusWei(uint _additionalBonus) onlyOwner public {
        additionalBonusWei = _additionalBonus;
    }

    function setMaxWei(uint _max) onlyOwner public {
        require(_max > minInvestWei);
        maxInvestWei = _max;
    }


    function remainingTokens() public constant returns(uint) {
        return token.allowance(owner, this);
    }

    function() payable public {
        invest();
    }

    function invest() whenNotPaused payable public {
        Status status = getStatus();
        require(status == Status.PreSale || status == Status.ActiveSale);
        require(msg.value > minInvestWei && msg.value < maxInvestWei);
        require(remainingTokens() > 0);
        

        uint weiAmount = msg.value;

        uint tokens = calculateTokens(weiAmount);

        require(remainingTokens() >= tokens);
        token.transferFrom(owner, msg.sender, tokens);
        weiInvested[msg.sender] = weiInvested[msg.sender].add(weiAmount);
        tokensProvided[msg.sender] = tokensProvided[msg.sender].add(tokens);
        
        wallet.transfer(msg.value);
        TokenPurchase(msg.sender, weiAmount, tokens);
    } 

    function calculateTokens(uint weiAmount) public constant returns(uint) {
        uint tokens = weiAmount.mul(rate);
        uint bonus = 0;
        if(getStatus() == Status.PreSale) {
            bonus = tokens.div(100).mul(30); // 30% bonus
        } else {
            uint timeFromStart = block.timestamp.sub(start);
            if (timeFromStart <= 1 days) {
                bonus = tokens.div(100).mul(15); // 15% bonus
            } else if (timeFromStart <= 2 days) {
                bonus = tokens.div(10); // 10% bonus
            } else if (timeFromStart <= 3 days) {
                bonus = tokens.div(100).mul(8); // 8% bonus
            }  else if (timeFromStart <= 4 days) {
                bonus = tokens.div(100).mul(5); // 8% bonus
            }

            if (additionalBonusWei > 0 && weiAmount > additionalBonusWei) {
                bonus = bonus.add(tokens.div(10));
            }
        }

       

        tokens = tokens.add(bonus);
        return tokens;
    }

    function withdrawFunds(uint amount) onlyOwner public {
        require(amount <= this.balance);
        if (getStatus() == Status.Refunding) {
            loadedRefundAmount = loadedRefundAmount.sub(amount);
        }
        wallet.transfer(amount);
    }

    function sendFunds() public payable hasStatus(Status.Failed) {
        require(msg.value > 0);
        loadedRefundAmount = loadedRefundAmount.add(msg.value);
    }

    function claimRefund() public hasStatus(Status.Refunding) {
        uint refund = weiInvested[msg.sender];
        require(refund > 0);
        weiInvested[msg.sender] = 0;
        totalWeiInvested = totalWeiInvested.sub(refund);
        totalWeiRefunded = totalWeiRefunded.add(refund);
        Refund(msg.sender, refund);
        msg.sender.transfer(refund);
    }

    function getStatus() public constant returns (Status) {
        if (block.timestamp < start && remainingTokens() == 0) {
            return Status.Prepare;
        } else if (block.timestamp < start) {
            return Status.PreSale;
        } else if (block.timestamp <= end && remainingTokens() > 0) {
            return Status.ActiveSale;
        } else if (totalWeiInvested >= minGoalWei) {
            return Status.Success;
        } else if (totalWeiInvested < minGoalWei && totalWeiInvested > 0 && loadedRefundAmount >= totalWeiInvested) {
            return Status.Refunding;
        } else {
            return Status.Failed;
        }
    }

    modifier hasStatus(Status status) {
        require(status == getStatus());
        _;
    }

    
}