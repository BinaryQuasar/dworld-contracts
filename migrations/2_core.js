const DWorldCore = artifacts.require("./DWorldCore.sol");

module.exports = async function(deployer) {
  var core;
  
  deployer.then(function() {
      return DWorldCore.new();
  });
};
