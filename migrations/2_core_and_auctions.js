const DWorldCore = artifacts.require("./DWorldCore.sol");
const SaleAuction = artifacts.require("./auction/SaleAuction.sol");
const RentAuction = artifacts.require("./auction/RentAuction.sol");

module.exports = async function(deployer) {
  var core;
  var saleAuction;
  var rentAuction;
  
  deployer.then(function() {
      return DWorldCore.new();
  }).then(function(instance) {
      core = instance;
      
      return SaleAuction.new(core.address, 3500);
  }).then(function(instance) {
      saleAuction = instance;

      return RentAuction.new(core.address, 3500);
  }).then(function(instance) {
      rentAuction = instance;
      
      return core.setSaleAuctionContractAddress(saleAuction.address);
  }).then(function(instance) {
      return core.setRentAuctionContractAddress(rentAuction.address);
  });
};
