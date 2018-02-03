pragma solidity ^0.4.18;

import "./DWorldMinting.sol";
import "./OriginalDWorldDeed.sol";
import "./auction/ClockAuction.sol";

/// @dev Migrate original data from the old contract.
contract DWorldUpgrade is DWorldMinting {
    OriginalDWorldDeed originalContract;
    ClockAuction originalSaleAuction;
    ClockAuction originalRentAuction;
    
    /// @notice Keep track of whether we have finished migrating.
    bool public migrationFinished = false;
    
    /// @dev Keep track of how many plots have been transferred so far.
    uint256 migrationNumPlotsTransferred = 0;
    
    function DWorldUpgrade(
        address originalContractAddress,
        address originalSaleAuctionAddress,
        address originalRentAuctionAddress
    )
        public
    {
        if (originalContractAddress != 0) {
            _startMigration(originalContractAddress, originalSaleAuctionAddress, originalRentAuctionAddress);
        } else {
            migrationFinished = true;
        }
    }
    
    /// @dev Migrate data from the original contract. Assumes the original
    /// contract is paused, and remains paused for the duration of the
    /// migration.
    /// @param originalContractAddress The address of the original contract.
    function _startMigration(
        address originalContractAddress,
        address originalSaleAuctionAddress,
        address originalRentAuctionAddress
    )
        internal
    {
        // Set contracts.
        originalContract = OriginalDWorldDeed(originalContractAddress);
        originalSaleAuction = ClockAuction(originalSaleAuctionAddress);
        originalRentAuction = ClockAuction(originalRentAuctionAddress);
        
        // Start paused.
        paused = true;
        
        // Get count of original plots.
        uint256 numPlots = originalContract.countOfDeeds();
        
        // Allocate storage for the plots array (this is more
        // efficient than .push-ing each individual plot, as
        // that requires multiple dynamic allocations).
        plots.length = numPlots;
    }
    
    function migrationStep(uint256 numPlotsTransfer) external onlyOwner whenPaused {
        // Migration must not be finished yet.
        require(!migrationFinished);
    
        // Get count of original plots.
        uint256 numPlots = originalContract.countOfDeeds();
    
        // Loop through plots and assign to original owner.
        uint256 i;
        for (i = migrationNumPlotsTransferred; i < numPlots && i < migrationNumPlotsTransferred + numPlotsTransfer; i++) {
            uint32 _deedId = originalContract.plots(i);
            
            // Set plot.
            plots[i] = _deedId;
            
            // Get the original owner and transfer.
            address owner = originalContract.ownerOf(_deedId);
            
            // If the owner of the plot is an auction contract,
            // get the actual owner of the plot.
            address seller;
            if (owner == address(originalSaleAuction)) {
                (seller, ) = originalSaleAuction.getAuction(_deedId);
                owner = seller;
            } else if (owner == address(originalRentAuction)) {
                (seller, ) = originalRentAuction.getAuction(_deedId);
                owner = seller;
            }
            
            _transfer(address(0), owner, _deedId);
            
            // Set the initial price paid for the plot.
            initialPricePaid[_deedId] = 0.0125 ether;
            
            // The initial buyout price.
            uint256 _initialBuyoutPrice = 0.050 ether;
            
            // Set the initial buyout price.
            identifierToBuyoutPrice[_deedId] = _initialBuyoutPrice;
            
            // Trigger the buyout price event.
            SetBuyoutPrice(_deedId, _initialBuyoutPrice);
            
            // Mark the plot as being an original.
            identifierIsOriginal[_deedId] = true;
        }
        
        migrationNumPlotsTransferred += numPlotsTransfer;
        
        // Finished migration.
        if (i == numPlots) {
            migrationFinished = true;
        }
    }
}
