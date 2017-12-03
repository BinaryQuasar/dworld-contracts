const BigNumber = require('bignumber.js');
const debug = require("debug")("dworld");
const utils = require("./utils");

// Test DWorld core
const DWorldCore = artifacts.require("./DWorldCore.sol");

contract("DWorldCore", function(accounts) {
    const owner = accounts[0];
    const cfo   = accounts[1];
    const user1 = accounts[2];
    const user2 = accounts[3];
    const user3 = accounts[4];
    
    let core;
    let gasPrice;
    let unclaimedPlotPrice;
    let plotA = 3014702;
    let plotB = 3014703;
    let plotC = 3145774;
    let plotD = 3145775;
    let plotUnowned = 1111111;
    
    async function deployContract() {
        debug("Deploying DWorld core contract.");
        
        core = await DWorldCore.new(owner);
        gasPrice = new BigNumber(core.constructor.class_defaults.gasPrice);
        unclaimedPlotPrice = await core.unclaimedPlotPrice();
    }
    
    async function mintTokens() {
        debug("Buying some tokens");
        
        // User1 mints a few tokens by sending Ether
        core.claimPlotMultiple([plotA, plotB, plotC, plotD], {from: user1, value: 4 * unclaimedPlotPrice});
    }
    
    describe("Initial state", function() {
        before(deployContract);
        
        it("initial message sender should be contract owner", async function () {
            assert.equal(await core.owner(), owner);
        });
        
        it("initial owner should be CFO", async function() {            
            assert.equal(await core.cfoAddress(), owner);
        });
        
        it("should have no supply", async function() {
            assert.equal(await core.totalSupply(), 0);
        });
        
        it("should transform between coordinate and identifier space", async function() {
            assert.equal(await core.coordinateToIdentifier(0, 0), 0);
            assert.equal(await core.coordinateToIdentifier(23, 46), 6029335); // 2^17 * 46 + 23
            assert.equal(await core.coordinateToIdentifier(131071, 131071), 17179869183); // 2^17 * (2^17 - 1) + (2^17 - 1)
            
            var coord1 = await core.identifierToCoordinate(0);
            assert.lengthOf(coord1, 2);
            assert.equal(coord1[0], 0);
            assert.equal(coord1[1], 0);
            
            var coord2 = await core.identifierToCoordinate(6029335);
            assert.lengthOf(coord2, 2);
            assert.equal(coord2[0], 23);
            assert.equal(coord2[1], 46);
            
            var coord3 = await core.identifierToCoordinate(17179869183);
            assert.lengthOf(coord3, 2);
            assert.equal(coord3[0], 131071);
            assert.equal(coord3[1], 131071);
        });
    });
    
        /*
    describe("NonFungible, EIP-721", function() {
        let plotA, plotB, plotC, plotD;
        before(deployContract);

        it("buy a few plots", async function() {
            core.buyNewWorldBlocks({from: user1});
        });

        it("approve + transferFrom + ownerOf", async function() {
            await coreC.approve(user1, kitC);
            eq(await coreC.ownerOf(kitC), coo);
            await coreC.transferFrom(coo, user1, kitC, { from: user1 });
            eq(await coreC.ownerOf(kitC), user1);
        });

        it("balanceOf", async function() {
            eq(await coreC.balanceOf(coo), 9);
            eq(await coreC.balanceOf(user1), 1);
            eq(await coreC.balanceOf(user2), 0);
        });

        it("tokensOfOwnerByIndex", async function() {
            eq(await coreC.tokensOfOwnerByIndex(coo, 0), kitA);
            eq(await coreC.tokensOfOwnerByIndex(coo, 1), kitB);
            eq(await coreC.tokensOfOwnerByIndex(coo, 2), kitD);
            await util.assertRevert(coreC.tokensOfOwnerByIndex(coo, 10));
            eq(await coreC.tokensOfOwnerByIndex(user1, 0), kitC);
            await util.assertRevert(coreC.tokensOfOwnerByIndex(user1, 1));
        });

        it.skip("tokenMetadata", async function() {
            debug(await coreC.website());
            eq(
                await coreC.tokenMetadata(kitA),
                "https://www.cryptokitties.co/kitty/1"
            );
            eq(
                await coreC.tokenMetadata(10),
                "https://www.cryptokitties.co/kitty/10"
            );
            await util.assertRevert(coreC.tokenMetadata(11));
        });
    });
    */
    
    describe("Non-fungible plot tokens (EIP-721)", function() {
        beforeEach(deployContract);
        beforeEach(mintTokens);
        
        it("should only give tokens to the buyer", async function() {
            assert.equal(await core.balanceOf(user1), 4);
            assert.equal(await core.balanceOf(user2), 0);
        });
        
        it("should increase supply when minting", async function() {
            assert.equal(await core.totalSupply(), 4);
        });
        
        it("only mints if enough ether is sent", async function() {
            await utils.assertRevert(core.claimPlotMultiple([0, 1, 2, 3], {from: user1, value: 3 * unclaimedPlotPrice}));
        });
        
        it("should prevent minting invalid plots", async function() {
            // First valid id is 0
            await utils.assertRevert(core.claimPlotMultiple([-1], {from: user1, value: 1 * unclaimedPlotPrice}));
            
            // Last valid id is 17179869183
            await utils.assertRevert(core.claimPlotMultiple([17179869184], {from: user1, value: 1 * unclaimedPlotPrice}));
            
            await utils.assertRevert(core.claimPlotMultiple([2000000000000000], {from: user1, value: 1 * unclaimedPlotPrice}));
            
            // Also rejects invalid ids between valid ids
            await utils.assertRevert(core.claimPlotMultiple([0, 1, -1, 2, 3], {from: user1, value: 5 * unclaimedPlotPrice}));
        });
        
        it("mints extreme (but valid) plots", async function() {
            await core.claimPlotMultiple([0, 17179869183], {from: user1, value: 2 * unclaimedPlotPrice});
            assert.equal(await core.totalSupply(), 6);
        });
        
        it("should not allow transferring tokens to 0x0", async function() {
            await utils.assertRevert(core.transfer(0x0, plotA, {from: user1}));
        });
        
        it("should prevent non-token holder from transferring tokens", async function() {
            await utils.assertRevert(core.transfer(user2, plotA, {from: user2}));
        });
        
        it("allows token holder to transfer tokens", async function() {
            await core.transfer(user2, plotA, {from: user1});
            assert.equal(await core.ownerOf(plotA), user2);
            assert.equal(await core.balanceOf(user1), 3);
            assert.equal(await core.balanceOf(user2), 1);
        });
        
        it("can set token transfer approval", async function() {
            await core.approve(user2, plotA, {from: user1});
            assert.equal(await core.ownerOf(plotA), user1);
        });
        
        it("should prevent non-approved address from taking token ownership", async function() {
            await utils.assertRevert(core.takeOwnership(plotB, {from: user3}));            
            assert.equal(await core.ownerOf(plotB), user1);
        });
        
        it("allows approved address to take token ownership", async function() {
            await core.approve(user2, plotA, {from: user1});
            await core.takeOwnership(plotA, {from: user2});
            assert.equal(await core.ownerOf(plotA), user2);
            assert.equal(await core.balanceOf(user1), 3);
            assert.equal(await core.balanceOf(user2), 1);
        });
        
        it("should prevent taking ownership by old pending approval after token has been transferred", async function() {
            await core.approve(user2, plotA, {from: user1});
            await core.transfer(user3, plotA, {from: user1});
            await utils.assertRevert(core.takeOwnership(plotA, {from: user2}));
            assert.equal(await core.balanceOf(user1), 3);
            assert.equal(await core.balanceOf(user2), 0);
            assert.equal(await core.balanceOf(user3), 1);
        });
        
        it("should prevent minting the same plot twice", async function() {
            await utils.assertRevert(core.claimPlotMultiple([10, 10], {from: user1, value: 2 * unclaimedPlotPrice}));
            await utils.assertRevert(core.claimPlot(plotA, {from: user1, value: 1 * unclaimedPlotPrice}));
        });
    });
    
    describe("Plot data", function() {
        before(deployContract);
        before(mintTokens);
        
        it("is initially empty", async function() {            
            var data = await core.identifierToPlot(plotA);
            assert.lengthOf(data, 5);
            // data[0] is equal to the plot's creation time
            assert.equal(data[1], '');
            assert.equal(data[2], '');
            assert.equal(data[3], '');
            assert.equal(data[4], '');
        });
        
        it("can not be updated by non-owner", async function() {
            await utils.assertRevert(core.setPlotData(plotA, "TestName", "TestDescription", "TestImageUrl", "TestInfoUrl", {from: user2}));
        });
        
        it("can be updated by owner", async function() {
            await core.setPlotData(plotA, "TestName", "TestDescription", "TestImageUrl", "TestInfoUrl", {from: user1});
            var data = await core.identifierToPlot(plotA);
            assert.lengthOf(data, 5);
            // data[0] is equal to the plot's creation time
            assert.equal(data[1], 'TestName');
            assert.equal(data[2], 'TestDescription');
            assert.equal(data[3], 'TestImageUrl');
            assert.equal(data[4], 'TestInfoUrl');
        });
    });
    
    // Taken in part from
    // https://github.com/OpenZeppelin/zeppelin-solidity/blob/master/test/Claimable.test.js
    describe("Ownership and claiming", function() {
        before(deployContract);
        
        it("should have an owner", async function() {
            let owner = await core.owner();
            assert.isTrue(core !== 0);
        });
        
        it('changes pendingOwner after transfer', async function () {
            await core.transferOwnership(user1, {from: owner});
            
            assert.equal(await core.owner(), owner);
            assert.equal(await core.pendingOwner(), user1);
        });
        
        it('should prevent claimOwnership from no pendingOwner', async function () {
            await utils.assertRevert(core.claimOwnership({from: user2}));
        });
        
        it("should prevent non-owners from transferring", async function() {
            assert.notEqual(owner, user1);
            assert.notEqual(owner, user2);
            
            // Does not allow pending owner to transfer ownership
            await utils.assertRevert(core.transferOwnership(user1, {from: user1}));
            // Does not allow unknown address to transfer ownership
            await utils.assertRevert(core.transferOwnership(user2, {from: user2}));
        });
        
        it('allows pending owner to claim ownership', async function() {
            await core.claimOwnership({from: user1});
            assert.equal(await core.owner(), user1);
            assert.equal(await core.pendingOwner(), 0x0)
        });
    });
    
    describe("Access control", function() {
        before(deployContract);
        
        it("should prevent non-owner from setting CFO address", async function() {
            await utils.assertRevert(core.setCFO(cfo, {from: cfo}));
            await utils.assertRevert(core.setCFO(cfo, {from: user1}));
        });
        
        it("should allow owner to set CFO address", async function() {
            assert.equal(await core.cfoAddress(), owner);
            assert.notEqual(owner, cfo);
            await core.setCFO(cfo, {from: owner});
            assert.equal(await core.cfoAddress(), cfo);
        });
        
        it("should not allow CFO to set CFO address", async function() {
            await utils.assertRevert(core.setCFO(user1, {from: cfo}));
        });
    });
    
    describe("Funds", function() {
        before(deployContract);
        before(async function setCFO() {
            await core.setCFO(cfo, {from: owner});
        });
        
        it("should refund ether overspent for minting", async function() {
            var balanceBefore = await web3.eth.getBalance(user1);
            
            // Overspend by 1.35 ether
            var overspend = web3.toWei(new BigNumber("1.35"), 'ether');
            var tx = await core.claimPlotMultiple([0, 1, 2, 3], {from: user1, value: unclaimedPlotPrice.mul(4).add(overspend)});
            var balanceAfter = await web3.eth.getBalance(user1);
            
            // Calculate gas cost for the transaction
            var gasCost = gasPrice.mul(tx.receipt.gasUsed);
            
            // balanceBefore - balanceAfter - gasCost = price paid for minting
            assert.deepEqual(balanceBefore.minus(balanceAfter).minus(gasCost), unclaimedPlotPrice.mul(4));
        });
        
        it("should receive funds from minting", async function() {
            assert.deepEqual(await web3.eth.getBalance(core.address), unclaimedPlotPrice.mul(4));
        });
        
        it("should prevent non-CFO from withdrawing funds", async function() {
            await utils.assertRevert(core.withdrawBalance({from: owner}));
            await utils.assertRevert(core.withdrawBalance({from: user1}));
        });
        
        it("allows CFO to withdraw funds", async function() {
            var contractBalanceBefore = await web3.eth.getBalance(core.address);
            var cfoBalanceBefore = await web3.eth.getBalance(cfo);
            
            // Withdraw balance
            var tx = await core.withdrawBalance({from: cfo});
            
            // Calculate gas cost for the transaction
            var gasCost = gasPrice.mul(tx.receipt.gasUsed);
            
            var cfoBalanceAfter = await web3.eth.getBalance(cfo);
            
            assert.deepEqual(cfoBalanceAfter.minus(cfoBalanceBefore).plus(gasCost), contractBalanceBefore);
        });
        
        it("should have no balance after withdrawing funds", async function() {
            assert.equal(await web3.eth.getBalance(core.address), 0);
        });
        
        it("should prevent non-CFO from setting unclaimed plot mint price", async function() {
            var newPrice = web3.toWei(new BigNumber("0.05"), 'ether');
            
            await utils.assertRevert(core.setUnclaimedPlotPrice(newPrice, {from: user1}));
        });
        
        it("allows CFO to set new plot mint price", async function() {
            var newPrice = web3.toWei(new BigNumber("0.1"), 'ether');
            
            await core.setUnclaimedPlotPrice(newPrice, {from: cfo});
            assert.deepEqual((await core.unclaimedPlotPrice()).toNumber(), newPrice.toNumber());
        });
    });
});
