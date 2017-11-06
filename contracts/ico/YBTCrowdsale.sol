pragma solidity ^0.4.2;

import '../math/SafeMath.sol';
import "../ownership/Pausable.sol";
import "../token/StandartToken.sol";

contract YBTCrowdsale is Pausable {

    using SafeMath for uint256;

    StandartToken public token;

    address public tokensOwner;

    address public wallet;

    mapping (address => uint) public weiInvested;
    mapping (address => uint) public tokensProvided;

    mapping (address => uint) public presaleDeposit;

    uint public totalWeiInvested;
    uint public totalTokensProvided;
    uint public totalPresaleDeposit;

    uint public totalPresaleClaimed;

    uint public start;
    uint public end;

    uint public minInvestWei = 0;
    uint public maxInvestWei = 2**256-1;

    uint public additionalBonusWei = 0;

    uint public minGoalWei;
    uint public loadedRefundAmount = 0;
    uint public totalWeiRefunded = 0;

    uint public rate;

    event TokenPurchase(address indexed purchaser, address indexed beneficiary, uint256 weiAmount, uint256 tokensAmount);
    event PresaleDeposit(address indexed purchaser, address indexed beneficiary, uint256 weiAmount);
    event PresaleClaim (address indexed purchaser, uint256 weiAmount, uint256 tokensAmount);
    event Refund(address indexed purchaser, uint256 weiAmount);
    enum Status { Unknown, Prepare, PreSale, ActiveSale, Success, Failed, Refunding }

    function YBTCrowdsale(address _token, uint _start, uint _end, uint _rate, uint _minGoal, uint _additionalBonus, address _wallet, address _tokensOwner) {

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
        tokensOwner = _tokensOwner;
    }

    function setWallet(address _wallet) onlyOwner public {
        require(_wallet != address(0));
        wallet = _wallet;
    }

    function setTokensOwner(address _tokensOwner) onlyOwner public {
        require(_tokensOwner != address(0));
        tokensOwner = _tokensOwner;
    }

    function setMinGoal(uint _minGoal) onlyOwner public {
        require(_minGoal >= totalWeiInvested);
        minGoalWei = _minGoal;
    }

    function setRate(uint _rate) onlyOwner public {
        require(_rate > 0);
        rate = _rate;
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
        return token.allowance(tokensOwner, this);
    }

    function() payable public {
        invest(msg.sender);
    }

    function invest(address beneficiary) whenNotPaused payable public {
        Status status = getStatus();
        require(status == Status.PreSale || status == Status.ActiveSale);
        require(msg.value > minInvestWei && msg.value < maxInvestWei);

     
        uint weiAmount = msg.value;
        if (status == Status.ActiveSale) {
            uint tokens = calculateTokens(weiAmount);

            require(remainingTokens() >= tokens);
            token.transferFrom(tokensOwner, beneficiary, tokens);
            weiInvested[beneficiary] = weiInvested[beneficiary].add(weiAmount);
            tokensProvided[beneficiary] = tokensProvided[beneficiary].add(tokens);
            totalWeiInvested = totalWeiInvested.add(weiAmount);
            totalTokensProvided = totalTokensProvided.add(tokens);
            TokenPurchase(msg.sender, beneficiary, weiAmount, tokens);
        } else {
            presaleDeposit[beneficiary] = presaleDeposit[beneficiary].add(weiAmount);
            totalPresaleDeposit = totalPresaleDeposit.add(weiAmount);
            totalWeiInvested = totalWeiInvested.add(weiAmount);
            PresaleDeposit(msg.sender, beneficiary, weiAmount);
        }
        wallet.transfer(msg.value);
        
    } 

    function claimPresaleTokens() hasStatus(Status.Success) public returns(bool) {
        uint deposit = presaleDeposit[msg.sender];
        require(deposit > 0);
        presaleDeposit[msg.sender] = 0;
        uint tokens = deposit.mul(rate);
        uint bonus = tokens.div(10).mul(3);
        tokens = tokens.add(bonus);
        require(remainingTokens() >= tokens);
        token.transferFrom(tokensOwner, msg.sender, tokens);
        totalTokensProvided = totalTokensProvided.add(tokens);
        tokensProvided[msg.sender] = tokensProvided[msg.sender].add(tokens);
        weiInvested[msg.sender] = weiInvested[msg.sender].add(deposit);
        totalPresaleClaimed = totalPresaleClaimed.add(deposit);
        PresaleClaim(msg.sender, deposit, tokens);
    }

    function calculateTokens(uint weiAmount) public constant returns(uint) {
        uint tokens = weiAmount.mul(rate);
        uint bonus = 0;

        uint timeFromStart = block.timestamp.sub(start);
        if (timeFromStart <= 1 days) {
            bonus = tokens.div(100).mul(15); // 15% bonus
        } else if (timeFromStart <= 2 days) {
            bonus = tokens.div(100).mul(12); // 12% bonus
        } else if (timeFromStart <= 3 days) {
            bonus = tokens.div(10); // 10% bonus
        } else if (timeFromStart <= 4 days) {
            bonus = tokens.div(100).mul(8); // 8% bonus
        } else if (timeFromStart <= 5 days) {
            bonus = tokens.div(100).mul(5); // 5% bonus
        } 

        if (additionalBonusWei > 0 && weiAmount > additionalBonusWei) {
            bonus = bonus.add(tokens.div(10));
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
        uint presaleRefund = presaleDeposit[msg.sender];
        uint refund = weiInvested[msg.sender].add(presaleRefund);
        require(refund > 0);
        weiInvested[msg.sender] = 0;
        presaleDeposit[msg.sender] = 0;
        totalWeiInvested = totalWeiInvested.sub(refund);
        totalPresaleDeposit = totalPresaleDeposit.sub(presaleRefund);
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