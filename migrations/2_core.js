const DWorldCore = artifacts.require("./DWorldCore.sol");

module.exports = async function(deployer, network) {
    var core;
  
    deployer.then(function() {
        let originalContractAddress;
        let originalSaleAuctionAddress;
        let originalRentAuctionAddress;
        let buyoutsEnabledAfterHours;

        if (network == "rinkeby") {
            originalContractAddress = "0xf8c2b13ACcf82c66B01160a3Aaaa8f9299EFcfd4";
            originalSaleAuctionAddress = "0x7990F0A9286D46aB4Ced513522cC1E23A22b3489";
            originalRentAuctionAddress = "0x9F2EfDbAb961dA25FE39D44f9f6fC95fba32A71b";
            buyoutsEnabledAfterHours = 1;
        } else if (network == "mainnet") {
            originalContractAddress = "0xd4Df33983FF82CE4469c6ea3CFf390403E58d90A";
            originalSaleAuctionAddress = "0x621aD3562F5141c4A0E7Cad958b8b524d356332B";
            originalRentAuctionAddress = "0x5301F1EC2F48F86bbd5291DfD7998a3d733A3245";
            buyoutsEnabledAfterHours = 24;
        }

        return DWorldCore.new(
            originalContractAddress,
            originalSaleAuctionAddress,
            originalRentAuctionAddress,
            buyoutsEnabledAfterHours
        );
    });
};
