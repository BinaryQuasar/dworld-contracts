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
        
        core = await DWorldCore.new({from: owner, gas: 5000000});
        gasPrice = new BigNumber(core.constructor.class_defaults.gasPrice);
        unclaimedPlotPrice = await core.unclaimedPlotPrice();
    }
    
    async function mintDeeds() {
        debug("Buying some deeds.");
        
        // User1 mints a few deeds by sending Ether
        await core.claimPlotMultiple([plotA, plotB, plotC, plotD], {from: user1, value: 4 * unclaimedPlotPrice});
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
            assert.equal(await core.countOfDeeds(), 0);
        });
        
        it("should transform between coordinate and identifier space", async function() {
            assert.equal(await core.coordinateToIdentifier(0, 0), 0);
            assert.equal(await core.coordinateToIdentifier(23, 46), 3014679); // 2^16 * 46 + 23
            assert.equal(await core.coordinateToIdentifier(65535, 65535), 4294967295); // 2^16 * (2^16 - 1) + (2^16 - 1)
            
            var coord1 = await core.identifierToCoordinate(0);
            assert.lengthOf(coord1, 2);
            assert.equal(coord1[0], 0);
            assert.equal(coord1[1], 0);
            
            var coord2 = await core.identifierToCoordinate(3014679);
            assert.lengthOf(coord2, 2);
            assert.equal(coord2[0], 23);
            assert.equal(coord2[1], 46);
            
            var coord3 = await core.identifierToCoordinate(4294967295);
            assert.lengthOf(coord3, 2);
            assert.equal(coord3[0], 65535);
            assert.equal(coord3[1], 65535);
        });
        
        it("correctly identifies interface signatures", async function() {
            assert.equal(await core.supportsInterface("0x01ffc9a7"), true); // ERC-165
            assert.equal(await core.supportsInterface("0xda671b9b"), true); // ERC-721
            assert.equal(await core.supportsInterface("0x2a786f11"), true); // ERC-721 Metadata
            assert.equal(await core.supportsInterface("0xbaaaaaad"), false); // Something unsupported
        });
    });
    
    describe("Deed standard (EIP-721)", function() {
        beforeEach(deployContract);
        beforeEach(mintDeeds);
        
        it("should only give deeds to the buyer", async function() {
            assert.equal(await core.countOfDeedsByOwner(user1), 4);
            assert.equal(await core.countOfDeedsByOwner(user2), 0);
        });
        
        it("should increase supply when minting", async function() {
            assert.equal(await core.countOfDeeds(), 4);
        });
        
        it("only mints if enough ether is sent", async function() {
            await utils.assertRevert(core.claimPlotMultiple([0, 1, 2, 3], {from: user1, value: 3 * unclaimedPlotPrice}));
        });
        
        it("should prevent minting invalid plots", async function() {
            // First valid id is 0
            await utils.assertRevert(core.claimPlotMultiple([-1], {from: user1, value: 1 * unclaimedPlotPrice}));
            
            // Last valid id is 4294967295
            await utils.assertRevert(core.claimPlotMultiple([4294967296], {from: user1, value: 1 * unclaimedPlotPrice}));
            
            await utils.assertRevert(core.claimPlotMultiple([2000000000000000], {from: user1, value: 1 * unclaimedPlotPrice}));
            
            // Also rejects invalid ids between valid ids
            await utils.assertRevert(core.claimPlotMultiple([0, 1, -1, 2, 3], {from: user1, value: 5 * unclaimedPlotPrice}));
        });
        
        it("mints extreme (but valid) plots", async function() {
            await core.claimPlotMultiple([0, 4294967295], {from: user1, value: 2 * unclaimedPlotPrice});
            assert.equal(await core.countOfDeeds(), 6);
        });
        
        it("should correctly assign identifiers to minted deeds", async function() {
            await core.claimPlotMultiple([0, 1], {from: user1, value: 2 * unclaimedPlotPrice});
            await core.claimPlot(42, {from: user1, value: unclaimedPlotPrice});
            
            assert.equal(await core.plots(0), plotA);
            assert.equal(await core.plots(1), plotB);
            assert.equal(await core.plots(2), plotC);
            assert.equal(await core.plots(3), plotD);
            assert.equal(await core.plots(4), 0);
            assert.equal(await core.plots(5), 1);
            assert.equal(await core.plots(6), 42);
        });
        
        it("should not allow transferring deeds to 0x0", async function() {
            await utils.assertRevert(core.transfer(0x0, plotA, {from: user1}));
        });
        
        it("should prevent non-deed holder from transferring deeds", async function() {
            await utils.assertRevert(core.transfer(user2, plotA, {from: user2}));
        });
        
        it("allows deed holder to transfer deeds", async function() {
            await core.transfer(user2, plotA, {from: user1});
            assert.equal(await core.ownerOf(plotA), user2);
            assert.equal(await core.countOfDeedsByOwner(user1), 3);
            assert.equal(await core.countOfDeedsByOwner(user2), 1);
        });
        
        it("can set deed transfer approval", async function() {
            await core.approve(user2, plotA, {from: user1});
            assert.equal(await core.ownerOf(plotA), user1);
        });
        
        it("should prevent non-approved address from taking deed ownership", async function() {
            await utils.assertRevert(core.takeOwnership(plotB, {from: user3}));            
            assert.equal(await core.ownerOf(plotB), user1);
        });
        
        it("allows approved address to take deed ownership", async function() {
            await core.approve(user2, plotA, {from: user1});
            await core.takeOwnership(plotA, {from: user2});
            assert.equal(await core.ownerOf(plotA), user2);
            assert.equal(await core.countOfDeedsByOwner(user1), 3);
            assert.equal(await core.countOfDeedsByOwner(user2), 1);
        });
        
        it("should prevent taking ownership by old pending approval after deed has been transferred", async function() {
            await core.approve(user2, plotA, {from: user1});
            await core.transfer(user3, plotA, {from: user1});
            await utils.assertRevert(core.takeOwnership(plotA, {from: user2}));
            assert.equal(await core.countOfDeedsByOwner(user1), 3);
            assert.equal(await core.countOfDeedsByOwner(user2), 0);
            assert.equal(await core.countOfDeedsByOwner(user3), 1);
        });
        
        it("should prevent minting the same plot twice", async function() {
            await utils.assertRevert(core.claimPlotMultiple([10, 10], {from: user1, value: 2 * unclaimedPlotPrice}));
            await utils.assertRevert(core.claimPlot(plotA, {from: user1, value: 1 * unclaimedPlotPrice}));
        });
        
        it("creates correct metadata urls", async function() {
            assert.equal(await core.deedUri(0), "https://dworld.io/plot/00000/00000");
            assert.equal(await core.deedUri(1), "https://dworld.io/plot/00001/00000");
            assert.equal(await core.deedUri(42), "https://dworld.io/plot/00042/00000");
            assert.equal(await core.deedUri(23074867), "https://dworld.io/plot/06195/00352");
            assert.equal(await core.deedUri(4294967295), "https://dworld.io/plot/65535/65535");
            await utils.assertRevert(core.deedUri(4294967296));
            await utils.assertRevert(core.deedUri(-1));
        });
    });
    
    describe("Plot data", function() {
        beforeEach(deployContract);
        beforeEach(mintDeeds);
        
        it("can not be updated by non-owner", async function() {
            await utils.assertRevert(core.setPlotData(plotA, "TestName", "TestDescription", "TestImageUrl", "TestInfoUrl", {from: user2}));
        });
        
        it("can be updated by owner", async function() {
            var watcher = core.SetData();
            
            await core.setPlotData(plotA, "TestName", "TestDescription", "TestImageUrl", "TestInfoUrl", {from: user1});
            
            var logs = await watcher.get();
            assert.equal(logs.length, 1);
            
            var data = logs[0].args;
            assert.equal(data.deedId, plotA);
            assert.equal(data.name, "TestName");
            assert.equal(data.description, "TestDescription");
            assert.equal(data.imageUrl, 'TestImageUrl');
            assert.equal(data.infoUrl, 'TestInfoUrl');
        });
        
        it("allows setting data when claiming new plots", async function() {
            var watcher = core.SetData();
            
            await core.claimPlotWithData(0, "TestName1", "TestDescription1", "ImageUrl1", "InfoUrl1", {from: user1, value: unclaimedPlotPrice});
            
            var logs = await watcher.get();
            assert.equal(logs.length, 1);
            
            var data = logs[0].args;
            assert.equal(data.deedId, 0);
            assert.equal(data.name, "TestName1");
            assert.equal(data.description, "TestDescription1");
            assert.equal(data.imageUrl, 'ImageUrl1');
            assert.equal(data.infoUrl, 'InfoUrl1');
            
            await core.claimPlotMultipleWithData([1, 2], "TestName2", "TestDescription2", "ImageUrl2", "InfoUrl2", {from: user1, value: 2 * unclaimedPlotPrice});
            
            logs = await watcher.get();
            assert.equal(logs.length, 2);
            
            data = logs[0].args;
            assert.equal(data.deedId, 1);
            assert.equal(data.name, "TestName2");
            assert.equal(data.description, "TestDescription2");
            assert.equal(data.imageUrl, 'ImageUrl2');
            assert.equal(data.infoUrl, 'InfoUrl2');
            
            data = logs[1].args;
            assert.equal(data.deedId, 2);
            assert.equal(data.name, "TestName2");
            assert.equal(data.description, "TestDescription2");
            assert.equal(data.imageUrl, 'ImageUrl2');
            assert.equal(data.infoUrl, 'InfoUrl2');
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
        
        it("should prevent non-CFO from withdrawing free funds", async function() {
            await utils.assertRevert(core.withdrawFreeBalance({from: owner}));
            await utils.assertRevert(core.withdrawFreeBalance({from: user1}));
        });
        
        it("allows CFO to withdraw free funds", async function() {
            var contractBalanceBefore = await web3.eth.getBalance(core.address);
            var cfoBalanceBefore = await web3.eth.getBalance(cfo);
            
            // Withdraw balance
            var tx = await core.withdrawFreeBalance({from: cfo});
            
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
    
    describe("Allowance", function() {
        beforeEach(deployContract);
        beforeEach(mintDeeds);
        beforeEach(async function setCFO() {
            await core.setCFO(cfo, {from: owner});
        });
        
        it("should prevent non-CFO from setting free claim allowance", async function() {
            await utils.assertRevert(core.setFreeClaimAllowance(user1, 3, {from: owner}));
            await utils.assertRevert(core.setFreeClaimAllowance(cfo, 3, {from: user1}));
        });
        
        it("allows CFO to set free claim allowance", async function() {
            await core.setFreeClaimAllowance(user1, 3, {from: cfo});
            assert.equal(await core.freeClaimAllowanceOf(user1), 3);
        });
        
        it("allows free claims", async function() {
            await core.setFreeClaimAllowance(user1, 3, {from: cfo});
            await core.claimPlot(0, {from: user1});
        });
        
        it("correctly subtracts free claim allowance", async function() {
            await core.setFreeClaimAllowance(user1, 3, {from: cfo});
            await core.claimPlot(0, {from: user1});
            assert.equal(await core.freeClaimAllowanceOf(user1), 2);
            await core.claimPlotMultiple([1, 2], {from: user1});
            assert.equal(await core.freeClaimAllowanceOf(user1), 0);
        });
        
        it("allows using the entire allowance in one bulk mint", async function() {
            await core.setFreeClaimAllowance(user1, 6, {from: cfo});
            await core.claimPlotMultiple([1, 2, 3, 4, 5, 6], {from: user1});
        });
        
        it("does not allow one user to make use of another user's free claim allowance", async function() {
            await core.setFreeClaimAllowance(user1, 3, {from: cfo});
            await utils.assertRevert(core.claimPlotMultiple([1, 2], {from: user2}));
            await core.claimPlotMultiple([1, 2], {from: user1});
        });
        
        it("should prevent minting more plots for free than the user has allowance for", async function() {
            // No allowance set.
            await utils.assertRevert(core.claimPlotMultiple([1, 2], {from: user1}));
            
            await core.setFreeClaimAllowance(user1, 3, {from: cfo});
            await utils.assertRevert(core.claimPlotMultiple([1, 2, 3, 4], {from: user1}));
            
            await utils.assertRevert(core.claimPlotMultiple([1, 2, 3, 4], {from: user1, value: unclaimedPlotPrice.mul(0.5)}));
            
            await utils.assertRevert(core.claimPlotMultiple([1, 2, 3, 4, 5, 6], {from: user1, value: unclaimedPlotPrice.mul(2)}));
        });
        
        it("allows minting more plots than the user has allowance for given enough ether", async function() {
            await core.setFreeClaimAllowance(user1, 3, {from: cfo});
            await core.claimPlotMultiple([1, 2, 3, 4, 5, 6], {from: user1, value: unclaimedPlotPrice.mul(3)});
        });
        
        it("should refund all ether when paying in full with allowance", async function() {
            await core.setFreeClaimAllowance(user1, 3, {from: cfo});
            
            var balanceBefore = await web3.eth.getBalance(user1);
            
            // Overspend by 1.35 ether
            var overspend = web3.toWei(new BigNumber("1.35"), 'ether');
            var tx = await core.claimPlotMultiple([1, 2, 3], {from: user1, value: overspend});
            var balanceAfter = await web3.eth.getBalance(user1);
            
            // Calculate gas cost for the transaction
            var gasCost = gasPrice.mul(tx.receipt.gasUsed);
            
            // balanceBefore - balanceAfter - gasCost = price paid for minting
            assert.deepEqual(balanceBefore.minus(balanceAfter).minus(gasCost).toNumber(), 0);
        });
        
        it("should refund exactly the correct amount of ether when paying in part with allowance", async function() {
            await core.setFreeClaimAllowance(user1, 3, {from: cfo});
            
            var balanceBefore = await web3.eth.getBalance(user1);
            
            // Overspend by 1.35 ether
            var overspend = web3.toWei(new BigNumber("1.35"), 'ether');
            var tx = await core.claimPlotMultiple([1, 2, 3, 4, 5, 6], {from: user1, value: unclaimedPlotPrice.mul(3).add(overspend)});
            var balanceAfter = await web3.eth.getBalance(user1);
            
            // Calculate gas cost for the transaction
            var gasCost = gasPrice.mul(tx.receipt.gasUsed);
            
            // balanceBefore - balanceAfter - gasCost = price paid for minting
            assert.deepEqual(balanceBefore.minus(balanceAfter).minus(gasCost).toNumber(), unclaimedPlotPrice.mul(3).toNumber());
        });
    });
    
    describe("Pausing", function() {
        before(deployContract);
        before(mintDeeds);
        before(async function approveTransfer() {
            await core.approve(user2, plotB, {from: user1});
        });
        
        it("should prevent non-owners from pausing", async function() {
            await utils.assertRevert(core.pause({from: cfo}));
            await utils.assertRevert(core.pause({from: user1}));
        });
        
        it("allows the owner to pause", async function() { 
            await core.pause({from: owner});
        });
        
        it("should prevent minting, transferring, etc., when paused", async function() {
            await utils.assertRevert(core.approve(user2, plotA, {from: user1}));
            await utils.assertRevert(core.approveMultiple(user2, [plotA], {from: user1}));
            await utils.assertRevert(core.transfer(user2, plotA, {from: user1}));
            await utils.assertRevert(core.transferMultiple(user2, [plotA], {from: user1}));
            await utils.assertRevert(core.takeOwnership(plotB, {from: user2}));
            await utils.assertRevert(core.takeOwnershipMultiple([plotB], {from: user2}));
            
            await utils.assertRevert(core.claimPlot(0, {from: user1, value: unclaimedPlotPrice}));
            await utils.assertRevert(core.claimPlotMultiple([0], {from: user1, value: unclaimedPlotPrice}));
            
            await utils.assertRevert(core.setPlotData(plotA, "TestName", "TestDescription", "TestImageUrl", "TestInfoUrl", {from: user1}));
            await utils.assertRevert(core.setPlotDataMultiple([plotA], "TestName", "TestDescription", "TestImageUrl", "TestInfoUrl", {from: user1}));
        });
        
        it("should prevent non-owners from unpausing", async function() {
            await utils.assertRevert(core.unpause({from: cfo}));
            await utils.assertRevert(core.unpause({from: user1}));
        });
        
        it("allows the owner to unpause", async function() {
            await core.unpause({from: owner});
        });
        
        it("allows minting, transferring, etc., after unpausing", async function() {
            await core.approve(user2, plotA, {from: user1});
            await core.transfer(user2, plotA, {from: user1});
            await core.takeOwnership(plotB, {from: user2});
            
            await core.claimPlot(0, {from: user1, value: unclaimedPlotPrice});
            
            await core.setPlotData(plotC, "TestName", "TestDescription", "TestImageUrl", "TestInfoUrl", {from: user1});
        });
    });
    
    describe("Upgrading", function() {
        before(deployContract);
        
        it("should not be marked as upgraded by default", async function() {
            assert.equal(await core.upgradedContractAddress(), 0);
        });
        
        it("should prevent upgrading the contract when it is not paused", async function() {
            await utils.assertRevert(core.setUpgradedContractAddress(0x42, {from: owner}));
            await utils.assertRevert(core.setUpgradedContractAddress(0x42, {from: user1}));
        });
        
        it("should prevent non-owners from upgrading the contract (even when paused)", async function() {
            await core.pause({from: owner});
            await utils.assertRevert(core.setUpgradedContractAddress(0x42, {from: user1}));
        });
        
        it("should allow the owner to upgrade the contract when paused", async function() {
            await core.setUpgradedContractAddress(0x42, {from: owner});
            assert.equal(await core.upgradedContractAddress(), 0x42);
        });
    });
});
