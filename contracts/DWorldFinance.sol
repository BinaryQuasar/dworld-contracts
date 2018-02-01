pragma solidity ^0.4.18;

import "./DWorldRenting.sol";

/// @dev Holds functionality for finance related to plots.
contract DWorldFinance is DWorldRenting {    
    /// Total amount of ether yet to be paid to auction beneficiaries.
    uint256 public outstandingEther = 0 ether;
    
    /// Amount of ether yet to be paid per beneficiary.
    mapping (address => uint256) public addressToEtherOwed;
    
    /// Base price for unclaimed plots.
    uint256 public unclaimedPlotPrice = 0.0125 ether;
    
    /// Dividend per plot surrounding a new claim, in 1/1000th of percentages
    /// of the base unclaimed plot price.
    uint256 public dividendPercentage = 50000;
    
    /// Number of free claims per address.
    mapping (address => uint256) freeClaimAllowance;
    
    /// @dev Event fired when a dividend is paid for a new plot claim.
    event ClaimDividend(address indexed from, address indexed to, uint256 deedIdFrom, uint256 indexed deedIdTo, uint256 dividend);
    
    /// @notice Sets the new price for unclaimed plots.
    /// @param _unclaimedPlotPrice The new price for unclaimed plots.
    function setUnclaimedPlotPrice(uint256 _unclaimedPlotPrice) external onlyCFO {
        unclaimedPlotPrice = _unclaimedPlotPrice;
    }
    
    /// @notice Sets the new dividend percentage for unclaimed plots.
    /// @param _dividendPercentage The new dividend percentage for unclaimed plots.
    function setDividendPercentage(uint256 _dividendPercentage) external onlyCFO {
        require(0 <= _dividendPercentage && _dividendPercentage <= 100000);
        
        dividendPercentage = _dividendPercentage;
    }
    
    /// @notice The claim dividend to be paid for each adjacent plot.
    function claimDividend() public view returns (uint256) {
        return unclaimedPlotPrice.mul(dividendPercentage).div(100000);
    }
    
    /// @notice Set the free claim allowance for an address.
    /// @param addr The address to set the free claim allowance for.
    /// @param allowance The free claim allowance to set.
    function setFreeClaimAllowance(address addr, uint256 allowance) external onlyCFO {
        freeClaimAllowance[addr] = allowance;
    }
    
    /// @notice Get the free claim allowance of an address.
    /// @param addr The address to get the free claim allowance of.
    function freeClaimAllowanceOf(address addr) external view returns (uint256) {
        return freeClaimAllowance[addr];
    }
    
    /// @dev Assign balance to an account.
    /// @param addr The address to assign balance to.
    /// @param amount The amount to assign.
    function _assignBalance(address addr, uint256 amount) internal {
        addressToEtherOwed[addr] += amount;
        outstandingEther += amount;
    }
    
    /// @dev Find the _claimed_ plots surrounding a plot.
    /// @param identifier The identifier of the plot to get the surrounding plots for.
    function _claimedSurroundingPlots(uint256 identifier) internal returns (uint256[]) {
        var (x, y) = identifierToCoordinate(identifier);
        
        // Find all claimed surrounding plots.
        uint256 claimed = 0;
        
        // Create memory buffer capable of holding all plots.
        uint256[] memory _plots = new uint256[](8);
        
        // Loop through all neighbors.
        for (int256 dx = -1; dx <= 1; dx++) {
            for (int256 dy = -1; dy <= 1; dy++) {
                if (dx == 0 && dy == 0) {
                    // Skip the center (i.e., the plot itself).
                    continue;
                }
                
                uint256 neighborIdentifier = coordinateToIdentifier(uint256(int256(x) + dx) % 65536, uint256(int256(y) + dy) % 65536);
                
                if (identifierToOwner[neighborIdentifier] != 0x0) {
                    _plots[claimed] = neighborIdentifier;
                    claimed++;
                }
            }
        }
        
        // Copy to plot array.
        uint256[] memory plots = new uint256[](claimed);
        
        for (uint256 i = 0; i < claimed; i++) {
            plots[i] = _plots[i];
        }
        
        return plots;
    }
    
    /// @dev Assign claim dividend to an address.
    /// @param _from The address who paid the dividend.
    /// @param _to The dividend beneficiary.
    /// @param _deedIdFrom The identifier of the deed the dividend is being paid for.
    /// @param _deedIdTo The identifier of the deed the dividend is being paid to.
    function _assignClaimDividend(address _from, address _to, uint256 _deedIdFrom, uint256 _deedIdTo) internal {
        uint256 _claimDividend = claimDividend();
        
        // Trigger event.
        ClaimDividend(_from, _to, _deedIdFrom, _deedIdTo, _claimDividend);
        
        // Assign the dividend.
        _assignBalance(_to, _claimDividend);
    }

    /// @dev Calculate and assign the dividend payable for the new plot claim.
    /// A new claim pays dividends to all existing surrounding plots.
    /// @param identifier The identifier of the new plot to calculate and assign dividends for.
    /// Assumed to be valid.
    function _calculateAndAssignClaimDividends(uint256 identifier)
        internal
        returns (uint256 totalClaimDividend)
    {
        // Get existing surrounding plots.
        uint256[] memory claimedSurroundingPlots = _claimedSurroundingPlots(identifier);
        
        // Calculate the claim dividend.
        totalClaimDividend = claimedSurroundingPlots.length.mul(claimDividend());
        
        // Assign claim dividend.
        for (uint256 i = 0; i < claimedSurroundingPlots.length; i++) {
            _assignClaimDividend(msg.sender, identifierToOwner[claimedSurroundingPlots[i]], identifier, claimedSurroundingPlots[i]);
        }
    }
}
