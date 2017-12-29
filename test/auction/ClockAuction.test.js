const BigNumber = require('bignumber.js');
const debug = require("debug")("dworld-auction");
const utils = require("../utils");

// Test ClockAuction
const ERC721Mock = artifacts.require("./test/contracts/ERC721Mock.sol");
const ClockAuction = artifacts.require("./ClockAuction.sol");

contract("ClockAuction", function(accounts) {
    const owner = accounts[0];
    const cfo   = accounts[1];
    const user1 = accounts[2];
    const user2 = accounts[3];
    const user3 = accounts[4];
    
    const oneEth = web3.toWei(new BigNumber("1"), 'ether');
    const halveEth = web3.toWei(new BigNumber("0.5"), 'ether');
    
    const currentPrice = function(startPrice, endPrice, duration, elapsed) {
        if (elapsed >= duration) {
            return endPrice;
        }
        
        var totalChange = endPrice.minus(startPrice);
        var currentChange = totalChange.times(elapsed).div(duration);
        return startPrice.plus(currentChange.floor());
    }
    
    let erc721;
    let auction;
    let gasPrice;
    let tokenA;
    let tokenB;
    
    async function deployContract() {
        debug("Deploying clock auction contract.");
        
        erc721 = await ERC721Mock.new({from: owner, gas: 5000000});
        auction = await ClockAuction.new(erc721.address, 3500, {from: owner, gas: 5000000});
        gasPrice = new BigNumber(auction.constructor.class_defaults.gasPrice);
    }
    
    async function mintTokens() {
        await erc721.createToken({from: user1});
        await erc721.createToken({from: user1});
        await erc721.createToken({from: user2});
        tokenA = 1;
        tokenB = 2;
        tokenC = 3;
    }
    
    describe("Initial State", function() {
        beforeEach(deployContract);
        
        it("should have the correct owner", async function() {
            assert.equal(await auction.owner(), owner);
        });
        
        it("should have the correct ERC721 address", async function() {
            assert.equal(await auction.tokenContract(), erc721.address);
        });
    });
    
    describe("Auction creation and cancellation", function() {
        beforeEach(deployContract);
        beforeEach(mintTokens);
        
        it("should prevent creating auctions with tokens not approved for transfer to the auction contract", async function() {
            await utils.assertRevert(auction.createAuction(tokenA, oneEth, halveEth, utils.duration.days(3), {from: user1}));
        });
        
        it("should prevent creating auctions with too large auction values", async function() {
            await erc721.approve(auction.address, tokenA, {from: user1});
            
            // Start price: max 128 bits
            await utils.assertRevert(auction.createAuction(tokenA, new BigNumber(2).pow(128), oneEth, utils.duration.days(3))); // 2^128
            await utils.assertRevert(auction.createAuction(tokenA, new BigNumber(2).pow(150), oneEth, utils.duration.days(3))); // 2^128
            await utils.assertRevert(auction.createAuction(tokenA, new BigNumber(2).pow(256).minus(1), oneEth, utils.duration.days(3))); // 2^256-1
            
            // End price: max 128 bits
            await utils.assertRevert(auction.createAuction(tokenA, oneEth, new BigNumber(2).pow(128), utils.duration.days(3))); // 2^128
            await utils.assertRevert(auction.createAuction(tokenA, oneEth, new BigNumber(2).pow(150), utils.duration.days(3))); // 2^128
            await utils.assertRevert(auction.createAuction(tokenA, oneEth, new BigNumber(2).pow(256).minus(1), utils.duration.days(3))); // 2^256-1
            
            // Duration: max 64 bits
            await utils.assertRevert(auction.createAuction(tokenA, oneEth, halveEth, new BigNumber(2).pow(64)));
            await utils.assertRevert(auction.createAuction(tokenA, oneEth, halveEth, new BigNumber(2).pow(80)));
            await utils.assertRevert(auction.createAuction(tokenA, oneEth, halveEth, new BigNumber(2).pow(256).minus(1)));
        });
        
        it("should prevent creating auctions for non-token holders", async function() {
            await erc721.approve(auction.address, tokenA, {from: user1});
            
            await utils.assertRevert(auction.createAuction(tokenA, oneEth, halveEth, utils.duration.days(3), {from: user2}));
        });
        
        it("should prevent creating auctions for tokens that do not exist", async function() {
            await utils.assertRevert(auction.createAuction(42, oneEth, halveEth, utils.duration.days(3), {from: user2}));
        });
        
        it("successfully creates an auction for the owner of an approved token", async function() {
            await erc721.approve(auction.address, tokenA, {from: user1});
            await auction.createAuction(tokenA, oneEth, halveEth, utils.duration.days(3), {from: user1});
            var timestamp = await utils.latestTime();
            
            var [seller, startPrice, endPrice, duration, startedAt] = await auction.getAuction(tokenA);
            
            assert.equal(seller, user1);
            assert.equal(startPrice.toNumber(), oneEth.toNumber());
            assert.equal(endPrice.toNumber(), halveEth.toNumber());
            assert.equal(duration.toNumber(), utils.duration.days(3));
            assert.equal(startedAt.toNumber(), timestamp);
        });
        
        it("places the token in escrow", async function() {
            await erc721.approve(auction.address, tokenA, {from: user1});
            await auction.createAuction(tokenA, oneEth, halveEth, utils.duration.days(3), {from: user1});
            
            assert.equal(await erc721.ownerOf(tokenA), auction.address);
        });
        
        it("should prevent creating an auction if the token is already on auction", async function() {
            await erc721.approve(auction.address, tokenA, {from: user1});
            await auction.createAuction(tokenA, oneEth, halveEth, utils.duration.days(3), {from: user1});
            
            await utils.assertRevert(auction.createAuction(tokenA, oneEth, halveEth, utils.duration.days(3), {from: user1}));
        });
        
        it("should prevent auction cancellation for tokens that do not exist", async function() {
            await utils.assertRevert(auction.cancelAuction(42, {from: user1}));
        });
        
        it("should prevent auction cancellation of tokens not in auction", async function() {
            await utils.assertRevert(auction.cancelAuction(tokenA, {from: user1}));
        });
        
        it("should prevent auction cancellation by non-token owner", async function() {
            await erc721.approve(auction.address, tokenA, {from: user1});
            await auction.createAuction(tokenA, oneEth, halveEth, utils.duration.days(3), {from: user1});
            
            await utils.assertRevert(auction.cancelAuction(tokenA, {from: user2}));
        });
        
        it("successfully cancels auction and returns token to owner", async function() {
            await erc721.approve(auction.address, tokenA, {from: user1});
            await auction.createAuction(tokenA, oneEth, halveEth, utils.duration.days(3), {from: user1});
            await auction.cancelAuction(tokenA, {from: user1});
            
            await utils.assertRevert(auction.getAuction(tokenA));
            assert.equal(await erc721.ownerOf(tokenA), user1);
        });
    });
    
    describe("Bidding", function() {
        beforeEach(deployContract);
        beforeEach(mintTokens);
        beforeEach(async function approveTransfer() {
            await erc721.approve(auction.address, tokenA, {from: user1});
        });
        
        it("successfully handles stable prices", async function() {
            await auction.createAuction(tokenA, halveEth, halveEth, utils.duration.days(3), {from: user1});
            
            // Initially equal to start price
            assert.equal((await auction.getCurrentPrice(tokenA)).toNumber(), halveEth.toNumber());
            
            await utils.increaseTime(utils.duration.days(1));
            
            // After some time still equal to start price
            assert.equal((await auction.getCurrentPrice(tokenA)).toNumber(), halveEth.toNumber());
            
            await utils.increaseTime(utils.duration.days(2) + utils.duration.minutes(1));
            
            // After end of dynamic pricing duration still equal to end price
            assert.equal((await auction.getCurrentPrice(tokenA)).toNumber(), halveEth.toNumber());
        });
        
        it("successfully handles decreasing prices", async function() {
            await auction.createAuction(tokenA, oneEth, halveEth, utils.duration.days(3), {from: user1});
            
            var startTimestamp = await utils.latestTime();
            
            // Initially equal to start price
            assert.equal((await auction.getCurrentPrice(tokenA)).toNumber(), oneEth.toNumber());
            
            await utils.increaseTime(utils.duration.days(1));
            
            // After some time price has decreased
            var timestamp = await utils.latestTime();
            var curPrice = currentPrice(oneEth, halveEth, utils.duration.days(3), timestamp - startTimestamp);
            assert.equal((await auction.getCurrentPrice(tokenA)).toNumber(), curPrice.toNumber());
            
            await utils.increaseTime(utils.duration.days(2) + utils.duration.minutes(1));
            
            // After end of dynamic pricing duration equal to end price
            assert.equal((await auction.getCurrentPrice(tokenA)).toNumber(), halveEth.toNumber());
        });
        
        it("successfully handles increasing prices", async function() {
            await auction.createAuction(tokenA, halveEth, oneEth, utils.duration.days(3), {from: user1});
            
            var startTimestamp = await utils.latestTime();
            
            // Initially equal to start price
            assert.equal((await auction.getCurrentPrice(tokenA)).toNumber(), halveEth.toNumber());
            
            await utils.increaseTime(utils.duration.days(1));
            
            // After some time price has increased
            var timestamp = await utils.latestTime();
            var curPrice = currentPrice(halveEth, oneEth, utils.duration.days(3), timestamp - startTimestamp);
            assert.equal((await auction.getCurrentPrice(tokenA)).toNumber(), curPrice.toNumber());
            
            await utils.increaseTime(utils.duration.days(2) + utils.duration.minutes(1));
            
            // After end of dynamic pricing duration equal to end price
            assert.equal((await auction.getCurrentPrice(tokenA)).toNumber(), oneEth.toNumber());
        });
        
        it("should prevent bidding after auction has been cancelled", async function() {
            await auction.createAuction(tokenA, oneEth, halveEth, utils.duration.days(3), {from: user1});
            await auction.cancelAuction(tokenA, {from: user1});
            
            await utils.assertRevert(auction.bid(tokenA, {from: user2, value: oneEth}));
        });
        
        it("should fail bidding with insufficient ether", async function() {
            await auction.createAuction(tokenA, halveEth, oneEth, utils.duration.days(3), {from: user1});
            
            await utils.assertRevert(auction.bid(tokenA, {from: user2, value: halveEth.div(2)}));
        });
        
        it("should prevent bidding after auction has been concluded", async function() {
            await auction.createAuction(tokenA, halveEth, oneEth, utils.duration.days(3), {from: user1});
            
            await auction.bid(tokenA, {from: user3, value: oneEth});
            
            await utils.assertRevert(auction.bid(tokenA, {from: user2, value: oneEth}));
        });
        
        it("successfully transfers winnings to buyer after a valid bid", async function() {
            await auction.createAuction(tokenA, halveEth, oneEth, utils.duration.days(3), {from: user1});
            
            await auction.bid(tokenA, {from: user3, value: oneEth});
            assert.equal(await erc721.ownerOf(tokenA), user3);
        });
    });
    
    describe("Funds", async function() {        
        before(deployContract);
        before(mintTokens);
        before(async function createAuction() {
            await erc721.approve(auction.address, tokenA, {from: user1});
            await auction.createAuction(tokenA, oneEth, halveEth, utils.duration.days(3), {from: user1});
        });
        
        let actualPrice;
        
        it("auction contract has no initial balance", async function() {
            assert.equal(await web3.eth.getBalance(auction.address), 0);
        });
        
        it("has no initial outstanding proceeds", async function() {
            assert.equal((await auction.addressToEtherOwed(user1)).toNumber(), 0);
            assert.equal((await auction.outstandingEther()).toNumber(), 0);
        });
        
        it("should prevent withdrawing when no proceeds are owed", async function() {
            await utils.assertRevert(auction.withdrawAuctionBalance({from: user1}));
        });
        
        it("assigns proceeds from auctions", async function() {
            var [seller, startPrice, endPrice, duration, startedAt] = await auction.getAuction(tokenA);
            
            // Bid.
            await auction.bid(tokenA, {from: user2, value: oneEth});
            var endTimestamp = await utils.latestTime();
            
            // Calculate the actual price of the token based on the transaction's block timestamp.
            actualPrice = currentPrice(oneEth, halveEth, utils.duration.days(3), endTimestamp - startedAt);
            
            assert.equal((await auction.addressToEtherOwed(user1)).toNumber(), actualPrice.times(1 - 0.035));
            assert.equal((await auction.addressToEtherOwed(user1)).toNumber(), (await auction.outstandingEther()).toNumber());
            assert.equal(await auction.addressToEtherOwed(user2), 0);
        });
        
        it("allows the seller to withdraw proceeds", async function() {
            var balanceBefore = await web3.eth.getBalance(user1);
            var tx = await auction.withdrawAuctionBalance({from: user1});
            var balanceAfter = await web3.eth.getBalance(user1);
            
            var totalGasCost = gasPrice.times(tx.receipt.gasUsed);
            
            assert.equal(balanceAfter.minus(balanceBefore).plus(totalGasCost).toNumber(), actualPrice.times(1 - 0.035).toNumber());
        });
        
        it("sets outstanding proceeds of seller to 0 after withdrawal", async function() {
            assert.equal((await auction.addressToEtherOwed(user1)).toNumber(), 0);
            assert.equal((await auction.outstandingEther()).toNumber(), 0);
        });
        
        it("keeps fees as contract balance", async function() {
            assert.isAtLeast(await web3.eth.getBalance(auction.address), actualPrice.times(0.035));
        });
        
        it("should prevent non-owners from withdrawing free balance to the token contract", async function() {
            await utils.assertRevert(auction.withdrawFreeBalance({from: user1}));
        });
        
        it("allows the owner to withdraw the free balance to the token contract", async function() {
            assert.equal(await web3.eth.getBalance(erc721.address), 0);
            
            // Withdraw free balance from the auction contract to the token contract.
            await auction.withdrawFreeBalance({from: owner});
            
            // After transferring out the owed balance and free balance,
            // there should be no balance left in the auction contract.
            assert.equal(await web3.eth.getBalance(auction.address), 0);
            
            // Token contract should now have all the free balance.
            assert.isAtLeast(await web3.eth.getBalance(erc721.address), actualPrice.times(0.035));
        });
        
        it("prevents non-owners from setting the auction fee",  async function() {
            await utils.assertRevert(auction.setFee(42, {from: user1}));
        });
        
        it("allows owner to set the auction fee", async function() {
            assert.equal(await auction.fee(), 3500);
            await auction.setFee(42, {from: owner});
            assert.equal(await auction.fee(), 42);
        });
    });
});
