pragma solidity ^0.4.18;

import "./DWorldMinting.sol";
import "./OriginalDWorldDeed.sol";

/// @dev Migrate original data from the old contract.
contract DWorldUpgrade is DWorldMinting {
    function DWorldUpgrade(address originalContractAddress) public {
        if (originalContractAddress != 0) {
            _migrate(originalContractAddress);
        }
    }
    
    /// @dev Migrate data from the original contract.
    /// @param originalContractAddress The address of the original contract.
    function _migrate(address originalContractAddress) internal {
        OriginalDWorldDeed originalContract = OriginalDWorldDeed(originalContractAddress);
        
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
            address owner = identifierToOwner[_deedId];
            _transfer(address(0), owner, _deedId);
            
            // Set the initial price paid for the plot.
            initialPricePaid[_deedId] = 0.0125 ether;
            
            // Set the initial buyout price.
            identifierToBuyoutPrice[_deedId] = 0.075 ether;
            
            // Mark the plot as being an original.
            identifierIsOriginal[_deedId] = true;
        }
    }
}
