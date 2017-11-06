'use strict';

const BigNumber = web3.BigNumber

require('chai')
  .use(require('chai-as-promised'))
  .use(require('chai-bignumber')(BigNumber))
  .should();

const expect = require('chai').expect;
const timer = require('./timer');
const assertJump = require('./assertJump');
import {increaseTimeTo, duration} from './increaseTime';
import latestTime from './latestTime';
import expectThrow from './expectThrow';

var YBTToken = artifacts.require('./token/YBTToken.sol');
var YBTCrowdsale = artifacts.require('./ico/YBTCrowdsale.sol');

contract('YBTCrowdsale', function(accounts){

    const wallet = accounts[1];
    //                          1 token = 1 * 10^18 (18 decimals)            0.01 euro cent ~ wei
    const rate = (new BigNumber(1000000000000000000)).divToInt(new BigNumber(40000000000000)); // 0.01 euro cents approximately
    console.log(rate.toString());
    const minGoal =  new BigNumber(web3.toWei(12, 'ether'));
    const preminted = new BigNumber('80000000000000000000000000000');
    const additionalBonus = (new BigNumber(web3.toWei(40, 'ether'))).floor();
    const totalTokensForSell = preminted.dividedBy(4); //25% for sale


    beforeEach(async function () {
        web3.eth.defaultAccount = accounts[0];
        this.startTime = latestTime() + duration.weeks(1);
        this.endTime =   this.startTime + duration.days(30);
        this.afterEndTime = this.endTime + duration.seconds(1);
        this.token = await YBTToken.new('YourBit Token', 'YBT', preminted, 18, true, false);

        this.crowdsale = await YBTCrowdsale.new(this.token.address, this.startTime, this.endTime, rate, minGoal, additionalBonus, wallet, accounts[0]);
        await this.token.setTransferAgent(this.crowdsale.address, true);
        await this.token.setTransferAgent(accounts[0], true);
        await this.token.approve(this.crowdsale.address, totalTokensForSell);
        await this.token.approve(accounts[0], totalTokensForSell);
    });


    describe('validate init', function() { 
        it('should be properly initialized', async function() {
            let status = await this.crowdsale.getStatus();
            let rtokens = await this.crowdsale.remainingTokens();
            status.should.be.bignumber.equal(2);
            rtokens.should.be.bignumber.equal(totalTokensForSell);
        });
        it('should be in Prepare satus when before start and no remaining tokens', async function(){
             await this.token.decreaseApproval(this.crowdsale.address, totalTokensForSell);
             (await this.crowdsale.getStatus()).should.be.bignumber.equal(1);
             (await this.crowdsale.remainingTokens()).should.be.bignumber.equal(0);
        });
    });

    describe('validate update parameters', function() {
        it('should be properly updated by owner', async function() {
            await this.crowdsale.setMinWei(100);
            (await this.crowdsale.minInvestWei()).should.be.bignumber.equal(100);
            await this.crowdsale.setMaxWei(1000);
            (await this.crowdsale.maxInvestWei()).should.be.bignumber.equal(1000);
            await this.crowdsale.setAdditionalBonusWei(10000);
            (await this.crowdsale.additionalBonusWei()).should.be.bignumber.equal(10000);
            await this.crowdsale.setWallet(accounts[3]);
            assert.equal(await this.crowdsale.wallet(), accounts[3]);
            await this.crowdsale.setTokensOwner(accounts[4]);
            assert.equal(await this.crowdsale.tokensOwner(), accounts[4]);
            await this.crowdsale.setRate(10000);
            (await this.crowdsale.rate()).should.be.bignumber.equal(10000);

        });
        it('should fail update not by owner', async function() {
            await expectThrow(this.crowdsale.setMinWei(100, {from: accounts[2]}));
            await expectThrow(this.crowdsale.setMaxWei(1000, {from: accounts[2]}));
            await expectThrow(this.crowdsale.setAdditionalBonusWei(10000, {from: accounts[2]}));
        });
    });

    describe('validate pricing logic', function() {
        it('should return 15% bonus on 1 day', async function() {
            await increaseTimeTo(this.startTime);
            (await this.crowdsale.calculateTokens(100)).should.be.bignumber.equal(rate.times(115));
        });
        it('should return 12% bonus on 2 day', async function() {
            await increaseTimeTo(this.startTime + duration.days(1) + duration.seconds(1));
            (await this.crowdsale.calculateTokens(100)).should.be.bignumber.equal(rate.times(112));
        });
        it('should return 10% bonus on 3 day', async function() {
            await increaseTimeTo(this.startTime + duration.days(2) + duration.seconds(1));
            (await this.crowdsale.calculateTokens(100)).should.be.bignumber.equal(rate.times(110));
        });
        it('should return 8% bonus on 4 day', async function() {
            await increaseTimeTo(this.startTime + duration.days(3) + duration.seconds(1));
            (await this.crowdsale.calculateTokens(100)).should.be.bignumber.equal(rate.times(108));
        });

        it('should return 5% bonus on 5 day', async function() {
            await increaseTimeTo(this.startTime + duration.days(4) + duration.seconds(1));
            (await this.crowdsale.calculateTokens(100)).should.be.bignumber.equal(rate.times(105));
        });

        it('should return 10% bonus when invested more than additionalBonus', async function() {
            await increaseTimeTo(this.startTime  + duration.days(6));
            let invest = additionalBonus.add(1);
            let expected = invest.times(rate);
            expected = expected.add(expected.divToInt(10));
            
            (await this.crowdsale.calculateTokens(invest)).should.be.bignumber.equal(expected);
        });
        
    });

    describe('validate presale deposit', async function() {
        it('should invest presale deposit', async function() {
           
           let deposit = web3.toWei(1, 'ether');
           assert(await this.crowdsale.sendTransaction({from: accounts[2], value: deposit}));
           (await this.crowdsale.totalPresaleDeposit()).should.be.bignumber.equal(deposit);
           (await this.crowdsale.presaleDeposit(accounts[2])).should.be.bignumber.equal(deposit);

        });
        it('shoult claim tokens after presale', async function() {
            let deposit = new BigNumber(web3.toWei(1, 'ether'));
            let tokens = deposit.times(rate);
            tokens = tokens.add(tokens.divToInt(10).mul(3));
            assert(await this.crowdsale.sendTransaction({from: accounts[0], value: minGoal}));
            assert(await this.crowdsale.sendTransaction({from: accounts[2], value: deposit}));

            await increaseTimeTo(this.afterEndTime);

            assert(await this.crowdsale.claimPresaleTokens({from: accounts[2]}));

            (await this.crowdsale.weiInvested(accounts[2])).should.be.bignumber.equal(deposit);
            (await this.crowdsale.tokensProvided(accounts[2])).should.be.bignumber.equal(tokens);
            (await this.crowdsale.totalTokensProvided()).should.be.bignumber.equal(tokens);
            (await this.crowdsale.totalPresaleClaimed()).should.be.bignumber.equal(deposit);

        });
    });

    describe('validate invest', async function() {
        it('should fail when less than min or more than max', async function() {
            await increaseTimeTo(this.startTime  + duration.seconds(1));
            await this.crowdsale.setMinWei(100);
            await this.crowdsale.setMaxWei(1000);
            await expectThrow(this.crowdsale.sendTransaction({from: accounts[2], value: 10}));
            await expectThrow(this.crowdsale.sendTransaction({from: accounts[2], value: 10000}));
        });
        it('should accept invest', async function() {
            await increaseTimeTo(this.startTime + duration.seconds(1));

            let wei = web3.toWei(1, 'ether');
            let tokens = await this.crowdsale.calculateTokens(wei);

            await this.crowdsale.sendTransaction({from: accounts[2], value: wei});

            (await this.crowdsale.weiInvested(accounts[2])).should.be.bignumber.equal(wei);
            (await this.crowdsale.tokensProvided(accounts[2])).should.be.bignumber.equal(tokens);
            (await this.crowdsale.totalWeiInvested()).should.be.bignumber.equal(wei);
            (await this.crowdsale.totalTokensProvided()).should.be.bignumber.equal(tokens);
        });
        it('should fail to invest after end', async function() {
            await increaseTimeTo(this.afterEndTime);
            await expectThrow(this.crowdsale.sendTransaction({from: accounts[2], value: 1000}));
        });

        it('should fail to invest where paused', async function() {
            await increaseTimeTo(this.startTime  + duration.seconds(1));
            await this.crowdsale.pause();
            assert(await this.crowdsale.paused());
            await expectThrow(this.crowdsale.sendTransaction({from: accounts[2], value: 1000}));

            await this.crowdsale.unpause();

            assert(!(await this.crowdsale.paused()));

            assert(await this.crowdsale.sendTransaction({from: accounts[2], value: 1000}));
        });
    });

    describe('validate refund', async function() {
        it('should fail to send funds whe not failed', async function() {
            await increaseTimeTo(this.startTime  + duration.seconds(1));
            assert(await this.crowdsale.sendTransaction({from: accounts[0], value: minGoal}));
            await increaseTimeTo(this.afterEndTime);
            //(await this.crowdsale.getStatus()).should.be.bignumber.equal(5);
            await expectThrow(this.crowdsale.sendFunds({value: 100}));
        });

        it('should accept funds for refund', async function() {
            await increaseTimeTo(this.startTime  + duration.seconds(1));
            assert(await this.crowdsale.sendTransaction({from: accounts[0], value: 1000}));
            await increaseTimeTo(this.afterEndTime);
            (await this.crowdsale.getStatus()).should.be.bignumber.equal(5);
            await this.crowdsale.sendFunds({value: 1000});
            (await this.crowdsale.loadedRefundAmount()).should.be.bignumber.equal(1000);
            web3.eth.getBalance(this.crowdsale.address).should.be.bignumber.equal(1000);
        });

        it('should let owner to withdral funds when refunding', async function () {
            await increaseTimeTo(this.startTime  + duration.seconds(1));
            assert(await this.crowdsale.sendTransaction({from: accounts[0], value: 1000}));
            await increaseTimeTo(this.afterEndTime);
            let res = await this.crowdsale.sendFunds({value: 1000, from: wallet});

            await this.crowdsale.withdrawFunds(500);

            (await this.crowdsale.loadedRefundAmount()).should.be.bignumber.equal(500);

        });

        it('should be able to claim refund', async function() {
            assert(await this.crowdsale.sendTransaction({from: accounts[3], value: 10000}));
            await increaseTimeTo(this.startTime  + duration.seconds(1));
            assert(await this.crowdsale.sendTransaction({from: accounts[2], value: 1000}));
            await increaseTimeTo(this.afterEndTime);
            let res = await this.crowdsale.sendFunds({value: 11000, from: wallet});
            await this.crowdsale.claimRefund({from: accounts[2]});
            (await this.crowdsale.weiInvested(accounts[2])).should.be.bignumber.equal(0);
            (await this.crowdsale.totalWeiRefunded()).should.be.bignumber.equal(1000);
            await this.crowdsale.claimRefund({from: accounts[3]});
            (await this.crowdsale.weiInvested(accounts[3])).should.be.bignumber.equal(0);
            (await this.crowdsale.presaleDeposit(accounts[3])).should.be.bignumber.equal(0);

            (await this.crowdsale.totalWeiInvested()).should.be.bignumber.equal(0);
            (await this.crowdsale.totalPresaleDeposit()).should.be.bignumber.equal(0);
            (await this.crowdsale.totalWeiRefunded()).should.be.bignumber.equal(11000);
            web3.eth.getBalance(this.crowdsale.address).should.be.bignumber.equal(0);
            
        });
    });


});
