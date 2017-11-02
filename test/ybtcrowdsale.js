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
    const rate =  new BigNumber(40713296962788); // 0.01 euro cents
    const minGoal =  new BigNumber(web3.toWei(122140, 'ether'));
    const preminted = new BigNumber('80000000000000000000000000000');
    const additionalBonus = new BigNumber(web3.toWei(40.7, 'ether'));
    const totalTokensForSell = preminted.dividedBy(4); //25% for sale


    beforeEach(async function () {
        this.startTime = latestTime() + duration.weeks(1);
        this.endTime =   this.startTime + duration.weeks(1);
        this.afterEndTime = this.endTime + duration.seconds(1)
        this.token = await YBTToken.new('YourBit Token', 'YBT', preminted, 18, true, false);

        this.crowdsale = await YBTCrowdsale.new(this.token.address, this.startTime, this.endTime, rate, minGoal, additionalBonus, wallet);
        await this.token.setTransferAgent(this.crowdsale.address, true);
        await this.token.approve(this.crowdsale.address, totalTokensForSell);
    });

    describe('validate init', function() { 
        it('should be properly initialized', async function() {
            let status = await this.crowdsale.getStatus();
            let rtokens = await this.crowdsale.remainingTokens();
            console.log(status);
            console.log(rtokens.toString());
            console.log(rtokens.equals(totalTokensForSell));
            //assert.equal(status, 2);
            status.should.be.bignumber.equal(2);
            rtokens.should.be.bignumber.equal(totalTokensForSell);
           // assert.equal(rtokens, totalTokensForSell);
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
        });
        it('should fail update not by owner', async function() {
            await expectThrow(this.crowdsale.setMinWei(100, {from: accounts[2]}));
            await expectThrow(this.crowdsale.setMaxWei(1000, {from: accounts[2]}));
            await expectThrow(this.crowdsale.setAdditionalBonusWei(10000, {from: accounts[2]}));
        });
    });

    describe('validate pricing logic', function() {
        it('should return 30% bonus in PreSale', async function() {
            let tkn = await this.crowdsale.calculateTokens(100);
            console.log(tkn.toString());
            console.log(rate.times(130).toString());
            assert.equal(await this.crowdsale.calculateTokens(100), rate.times(130));
        });
        it('should return 15% bonus in first day', async function() {
            await increaseTimeTo(this.startTime);
            assert.equal(await this.crowdsale.calculateTokens(100), 115);
        });
        it('should return 12% bonus in second day', async function() {
            await increaseTimeTo(this.startTime + duration.days(1));
            let res = await this.crowdsale.calculateTokens(100);
            console.log(res);
            assert.equal(1, 112);
        });
        
    });


});