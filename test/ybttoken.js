'use strict';

const BigNumber = web3.BigNumber

require('chai')
  .use(require('chai-as-promised'))
  .use(require('chai-bignumber')(BigNumber))
  .should();

const expect = require('chai').expect;
const timer = require('./timer');
const assertJump = require('./assertJump');
import expectThrow from './expectThrow';

var YBTToken = artifacts.require('./token/YBTToken.sol');
var RecurringBillingProvider = artifacts.require('./providers/RecurringBillingProvider.sol');

contract('YBTToken', function(accounts) {

    describe('validate standart token logic', function() { 
        let token;
        beforeEach(async function() {
            token = await YBTToken.new('YourBit Token', 'YBT', 1000000000000000000000, 18, true, false);
        });
        it('should return the correct totalSupply after construction', async function() {
            let totalSupply = await token.totalSupply();
            assert.equal(totalSupply, 1000000000000000000000);
        });

        it('should return the correct allowance amount after approval', async function() {
            await token.approve(accounts[1], 100);
            let allowance = await token.allowance(accounts[0], accounts[1]);        
            assert.equal(allowance, 100);
        
        });

        it('should throw error when trying to approve on non zero allowance', async function() {
            await token.approve(accounts[1], 100);
            await expectThrow(token.approve(accounts[1], 100));
        });

        it('should return correct balances after transfer', async function() {
            await token.releaseTokenTransfer();
            await token.transfer(accounts[1], 1000000000000000000);
            let balance0 = await token.balanceOf(accounts[0]);
            //console.log(balance0);
            assert.equal(balance0, 999000000000000000000);

            let balance1 = await token.balanceOf(accounts[1]);
             //console.log(balance1);
            assert.equal(balance1, 1000000000000000000);
        });

        it('should throw an error when trying to transfer more than balance', async function() {
            await token.releaseTokenTransfer();
            await expectThrow(token.transfer(accounts[1], 10000000000000000000000));
        });

        it('should return correct balances after transfering from another account', async function() {
            await token.releaseTokenTransfer();
            await token.approve(accounts[1], 1000000000000000000);
            await token.transferFrom(accounts[0], accounts[2], 1000000000000000000, {from: accounts[1]});

            let balance0 = await token.balanceOf(accounts[0]);
            assert.equal(balance0, 999000000000000000000);

            let balance1 = await token.balanceOf(accounts[2]);
            assert.equal(balance1, 1000000000000000000);

            let balance2 = await token.balanceOf(accounts[1]);
            assert.equal(balance2, 0);
        });

        it('should throw an error when trying to transfer more than allowed', async function() {
            await token.approve(accounts[1], 99);
            await token.releaseTokenTransfer();
            await expectThrow(token.transferFrom(accounts[0], accounts[2], 100, {from: accounts[1]}));
        });
    });

    describe('validating allowance updates to spender', function() {
        let preApproved;
        let token;
        beforeEach(async function() {
            token = await YBTToken.new('YourBit Token', 'YBT', 1000, 18, true, false);
        });

        it('should start with zero', async function() {
            preApproved = await token.allowance(accounts[0], accounts[1]);
            assert.equal(preApproved, 0);
        });

        it('should increase by 50 then decrease by 10', async function() {
            await token.increaseApproval(accounts[1], 50);
            let postIncrease = await token.allowance(accounts[0], accounts[1]);
            preApproved.plus(50).should.be.bignumber.equal(postIncrease);
            await token.decreaseApproval(accounts[1], 10);
            let postDecrease = await token.allowance(accounts[0], accounts[1]);
            postIncrease.minus(10).should.be.bignumber.equal(postDecrease);
        });
    });

    describe('validating errors on transfer to 0x0', function() {
        let token;
        beforeEach(async function() {
            token = await YBTToken.new('YourBit Token', 'YBT', 1000, 18, true, false);
        });
        it('should throw an error when trying to transfer to 0x0', async function() {
            await token.releaseTokenTransfer();
            await expectThrow(token.transfer(0x0, 100));
        });
        it('should throw an error when trying to transferFrom to 0x0', async function() {
            await token.releaseTokenTransfer();
            await token.approve(accounts[1], 100);
            await expectThrow(token.transferFrom(accounts[0], 0x0, 100, {from: accounts[1]}));
        });
    });

    describe('validating releasable logic', function() {
        let token;
        beforeEach(async function() {
            token = await YBTToken.new('YourBit Token', 'YBT', 1000, 18, true, false);
        });
        it('should throw error trying to transfer before release', async function() {
            await expectThrow(token.transfer(accounts[1], 100));
        });

        it('should throw error trying to transferFrom before release', async function() {
            await token.approve(accounts[1], 100);
            await expectThrow(token.transferFrom(accounts[0], accounts[2], 100, {from: accounts[1]}));
        });

        it('should throw error trying to set transfer agent not by owner', async function() {
            await expectThrow(token.setTransferAgent(accounts[1], true, {from: accounts[1]}));
        });

        it('should throw error trying to set transfer agent after token released', async function() {
            await token.releaseTokenTransfer();
            await expectThrow(token.setTransferAgent(accounts[1], true));
        });

        it('should throw error trying to release token not by owner', async function() {
            await expectThrow(token.releaseTokenTransfer({from: accounts[1]}));
        });

        it('should set transfer agent', async function() {
            await token.setTransferAgent(accounts[1], true);
            let res = await token.getTransferAgentState(accounts[1]);
            assert.equal(res, true);
        });

        it('should release token transfer', async function() {
            await token.releaseTokenTransfer();
            let res = await token.released();
            assert.equal(res, true);
        });

        it('should transfer after adding transfer agent', async function() {
            await token.setTransferAgent(accounts[0], true);
            await token.transfer(accounts[1], 100);
            let balance2 = await token.balanceOf(accounts[1]);
            assert.equal(balance2, 100);
        });
    });

     describe('validating mintable logic', function() {
        let token;
        beforeEach(async function() {
            token = await YBTToken.new('YourBit Token', 'YBT', 1000, 18, true, false);
        });
        it('should return mintingFinished false after construction', async function() {
            let mintingFinished = await token.mintingFinished();

            assert.equal(mintingFinished, false);
        });

        it('should mint a given amount of tokens to a given address', async function() {
            const result = await token.mint(accounts[0], 1000);
            assert.equal(result.logs[0].event, 'Mint');
            assert.equal(result.logs[0].args.to.valueOf(), accounts[0]);
            assert.equal(result.logs[0].args.amount.valueOf(), 1000);
            assert.equal(result.logs[1].event, 'Transfer');
            assert.equal(result.logs[1].args.from.valueOf(), 0x0);

            let balance0 = await token.balanceOf(accounts[0]);
            assert(balance0, 2000);

            let totalSupply = await token.totalSupply();
            assert(totalSupply, 2000);
        });

        it('should fail to mint after call to finishMinting', async function () {
            await token.finishMinting();
            assert.equal(await token.mintingFinished(), true);
            await expectThrow(token.mint(accounts[0], 100));
        });
     });

     describe('validate burnable logic', async function() {
        let token;
        beforeEach(async function() {
            token = await YBTToken.new('YourBit Token', 'YBT', 1000, 18, true, false);
        });
        it('owner should be able to burn tokens', async function () {
            const { logs } = await token.burn(1, { from: accounts[0] });

            const balance = await token.balanceOf(accounts[0]);
            assert(balance, 999);

            const totalSupply = await token.totalSupply();
             assert(totalSupply, 999);

            const event = logs.find(e => e.event === 'Burn');
            expect(event).to.exist;
        });

        it('cannot burn more tokens than your balance', async function () {
            await expectThrow(token.burn(2000, { from: accounts[0] }));
        });
     });
    describe('validate recurrent allowance logic', async function() {
        let token;
        let billingProvider;
        beforeEach(async function() {
            token = await YBTToken.new('YourBit Token', 'YBT', 1000, 18, true, true);
            billingProvider = await RecurringBillingProvider.new(token.address);
        });
        it('should fail to approve recurrent allowance to non contract', async function() {
            await expectThrow(token.approveRecurrent(accounts[1], 1508112000, 86400, 10, 0, 0));
        });
        it('should be able to approve recurrent allowance', async function() {
            await token.approveRecurrent(billingProvider.address, 1508112000, 86400, 10, 0, 0);
            let result = await token.allowanceRecurrent(accounts[0], billingProvider.address);
            assert(result[0], 10);
            assert(result[1], 1508112000);
            assert(result[2], 86400);

            await token.removeAllowanceRecurrent(billingProvider.address);
            result = await token.allowanceRecurrent(accounts[0], billingProvider.address);
            assert(result[0], 0);
            assert(result[1], 0);
            assert(result[2], 0);

        });

        it('should fail to transfer reccurent without approval', async function() {
             await expectThrow(billingProvider.withdrawRecurring(accounts[1], 100, {from: accounts[0]}));
        });
        it('should be able to transfer reccurent', async function() {
            await token.transfer(accounts[1], 100);
            await token.approveRecurrent(billingProvider.address, 1508112000, 86400, 100, 0, 0, {from: accounts[1]});

            assert(await billingProvider.withdrawRecurring(accounts[1], 50, { from: accounts[0] }));
            assert(await token.balanceOf(accounts[1]), 50);
            assert(await token.balanceOf(accounts[0]), 950);

            let result = await token.allowanceRecurrent(accounts[1], billingProvider.address);
            assert(result[3], 1);

        });
        it('should fail to transfer reccurent before time', async function() {
                await token.transfer(accounts[1], 100);
                await token.approveRecurrent(billingProvider.address, web3.eth.getBlock('latest').timestamp, 2629743, 100, 0, 1, {from: accounts[1]});

                await expectThrow(billingProvider.withdrawRecurring(accounts[1], 50, { from: accounts[0] }));
        });
        it('should transfer reccurent after time', async function() {
                await token.transfer(accounts[1], 100);
                await token.approveRecurrent(billingProvider.address, 1508112000, 2629743, 100, 0, 1, {from: accounts[1]});
                
                await timer(2712624);
                assert(await billingProvider.withdrawRecurring(accounts[1], 50, { from: accounts[0] }));
                let b1 = await token.balanceOf(accounts[1]);
                let b0 = await token.balanceOf(accounts[0]);
                console.log(b1);
                console.log(b0);
                assert(b1, 50);
                assert(b0, 950);
        });

        it('should remove allowance', async function() {
            await token.transfer(accounts[1], 100);
            let billingProvider1 = await RecurringBillingProvider.new(token.address);
            let billingProvider2 = await RecurringBillingProvider.new(token.address);
            await token.approveRecurrent(billingProvider.address, 1508112000, 2629743, 100, 0, 1, {from: accounts[1]});
            await token.approveRecurrent(billingProvider1.address, 1508112000, 2629743, 100, 0, 1, {from: accounts[1]});
            await token.approveRecurrent(billingProvider2.address, 1508112000, 2629743, 100, 0, 1, {from: accounts[1]});
            let res = await token.getAllowancesAddresess({from: accounts[1]});
            console.log(res);
            assert(res.length, 3);
            assert(res[0], billingProvider.address);
            assert(res[1], billingProvider1.address);
            assert(res[2], billingProvider2.address);

            await token.removeAllowanceRecurrent(billingProvider1.address);
            res = await token.getAllowancesAddresess({from: accounts[1]});
            assert(res.length, 2);
            assert(res[0], billingProvider.address);
            assert(res[1], billingProvider2.address);
            await token.removeAllowanceRecurrent(billingProvider2.address);
            res = await token.getAllowancesAddresess({from: accounts[1]});
            assert(res.length, 1);
            assert(res[0], billingProvider.address);

            await token.removeAllowanceRecurrent(billingProvider.address);
             res = await token.getAllowancesAddresess({from: accounts[1]});
            assert(res.length, 0);
 
        });
    });
    

});