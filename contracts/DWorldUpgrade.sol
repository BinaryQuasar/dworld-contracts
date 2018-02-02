pragma solidity ^0.4.18;

import "./DWorldMinting.sol";
import "./OriginalDWorldDeed.sol";
import "./auction/ClockAuction.sol";

/// @dev Migrate original data from the old contract.
contract DWorldUpgrade is DWorldMinting {
    function DWorldUpgrade(
        address originalContractAddress,
        address originalSaleAuctionAddress,
        address originalRentAuctionAddress
    )
        public
    {
        if (originalContractAddress != 0) {
            _migrate(originalContractAddress, originalSaleAuctionAddress, originalRentAuctionAddress);
        }
    }
    
    /// @dev Migrate data from the original contract.
    /// @param originalContractAddress The address of the original contract.
    function _migrate(
        address originalContractAddress,
        address originalSaleAuctionAddress,
        address originalRentAuctionAddress
    )
        internal
    {
        OriginalDWorldDeed originalContract = OriginalDWorldDeed(originalContractAddress);
        ClockAuction originalSaleAuction = ClockAuction(originalSaleAuctionAddress);
        ClockAuction originalRentAuction = ClockAuction(originalRentAuctionAddress);
        
        // Copy original plots.
        uint256 numPlots = originalContract.countOfDeeds();
        
        // Allocate storage for the plots array (this is more
        // efficient than .push-ing each individual plot, as
        // that requires multiple dynamic allocations).
        plots.length = numPlots;
        
        // Loop through plots and assign to original owner.
        for (uint256 i = 0; i < numPlots; i++) {
            uint32 _deedId = originalContract.plots(i);
            
            // Set plot.
            plots[i] = _deedId;
            
            // Get the original owner and transfer.
            address owner = originalContract.ownerOf(_deedId);
            
            // If the owner of the plot is an auction contract,
            // get the actual owner of the plot.
            address seller;
            if (owner == originalSaleAuctionAddress) {
                (seller, ) = originalSaleAuction.getAuction(_deedId);
                owner = seller;
            } else if (owner == originalRentAuctionAddress) {
                (seller, ) = originalRentAuction.getAuction(_deedId);
                owner = seller;
            }
            
            _transfer(address(0), owner, _deedId);
            
            // Set the initial price paid for the plot.
            initialPricePaid[_deedId] = 0.0125 ether;
            
            // The initial buyout price.
            uint256 _initialBuyoutPrice = 0.075 ether;
            
            // Set the initial buyout price.
            identifierToBuyoutPrice[_deedId] = _initialBuyoutPrice;
            
            // Trigger the buyout price event.
            SetBuyoutPrice(_deedId, _initialBuyoutPrice);
            
            // Mark the plot as being an original.
            identifierIsOriginal[_deedId] = true;
        }
    }
}
