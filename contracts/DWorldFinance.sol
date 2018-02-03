pragma solidity ^0.4.18;

import "./DWorldDeed.sol";

/// @dev Holds functionality for finance related to plots.
contract DWorldFinance is DWorldDeed {
    /// Total amount of Ether yet to be paid to auction beneficiaries.
    uint256 public outstandingEther = 0 ether;
    
    /// Amount of Ether yet to be paid per beneficiary.
    mapping (address => uint256) public addressToEtherOwed;
    
    /// Base price for unclaimed plots.
    uint256 public unclaimedPlotPrice = 0.0125 ether;
    
    /// Dividend per plot surrounding a new claim, in 1/1000th of percentages
    /// of the base unclaimed plot price.
    uint256 public claimDividendPercentage = 50000;
    
    /// Percentage of the buyout price that goes towards dividends.
    uint256 public buyoutDividendPercentage = 5000;
    
    /// Buyout fee in 1/1000th of a percentage.
    uint256 public buyoutFeePercentage = 3500;
    
    /// Number of free claims per address.
    mapping (address => uint256) freeClaimAllowance;
    
    /// Initial price paid for a plot.
    mapping (uint256 => uint256) public initialPricePaid;
    
    /// Current plot price.
    mapping (uint256 => uint256) public identifierToBuyoutPrice;
    
    /// Boolean indicating whether the plot has been bought out at least once.
    mapping (uint256 => bool) identifierToBoughtOutOnce;
    
    /// @dev Event fired when dividend is paid for a new plot claim.
    event ClaimDividend(address indexed from, address indexed to, uint256 deedIdFrom, uint256 indexed deedIdTo, uint256 dividend);
    
    /// @dev Event fired when a buyout is performed.
    event Buyout(address indexed buyer, address indexed seller, uint256 indexed deedId, uint256 winnings, uint256 totalCost, uint256 newPrice);
    
    /// @dev Event fired when dividend is paid for a buyout.
    event BuyoutDividend(address indexed from, address indexed to, uint256 deedIdFrom, uint256 indexed deedIdTo, uint256 dividend);
    
    /// @dev Event fired when the buyout price is manually changed for a plot.
    event SetBuyoutPrice(uint256 indexed deedId, uint256 newPrice);
    
    /// @dev The time after which buyouts will be enabled. Set in the DWorldCore constructor.
    uint256 public buyoutsEnabledFromTimestamp;
    
    /// @notice Sets the new price for unclaimed plots.
    /// @param _unclaimedPlotPrice The new price for unclaimed plots.
    function setUnclaimedPlotPrice(uint256 _unclaimedPlotPrice) external onlyCFO {
        unclaimedPlotPrice = _unclaimedPlotPrice;
    }
    
    /// @notice Sets the new dividend percentage for unclaimed plots.
    /// @param _claimDividendPercentage The new dividend percentage for unclaimed plots.
    function setClaimDividendPercentage(uint256 _claimDividendPercentage) external onlyCFO {
        // Claim dividend percentage must be 10% at the least.
        // Claim dividend percentage may be 100% at the most.
        require(10000 <= _claimDividendPercentage && _claimDividendPercentage <= 100000);
        
        claimDividendPercentage = _claimDividendPercentage;
    }
    
    /// @notice Sets the new dividend percentage for buyouts.
    /// @param _buyoutDividendPercentage The new dividend percentage for buyouts.
    function setBuyoutDividendPercentage(uint256 _buyoutDividendPercentage) external onlyCFO {
        // Buyout dividend must be 2% at the least.
        // Buyout dividend percentage may be 12.5% at the most.
        require(2000 <= _buyoutDividendPercentage && _buyoutDividendPercentage <= 12500);
        
        buyoutDividendPercentage = _buyoutDividendPercentage;
    }
    
    /// @notice Sets the new fee percentage for buyouts.
    /// @param _buyoutFeePercentage The new fee percentage for buyouts.
    function setBuyoutFeePercentage(uint256 _buyoutFeePercentage) external onlyCFO {
        // Buyout fee may be 5% at the most.
        require(0 <= _buyoutFeePercentage && _buyoutFeePercentage <= 5000);
        
        buyoutFeePercentage = _buyoutFeePercentage;
    }
    
    /// @notice The claim dividend to be paid for each adjacent plot, and
    /// as a flat dividend for each buyout.
    function claimDividend() public view returns (uint256) {
        return unclaimedPlotPrice.mul(claimDividendPercentage).div(100000);
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
        addressToEtherOwed[addr] = addressToEtherOwed[addr].add(amount);
        outstandingEther = outstandingEther.add(amount);
    }
    
    /// @dev Find the _claimed_ plots surrounding a plot.
    /// @param _deedId The identifier of the plot to get the surrounding plots for.
    function _claimedSurroundingPlots(uint256 _deedId) internal view returns (uint256[] memory) {
        var (x, y) = identifierToCoordinate(_deedId);
        
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
                
                // Get the coordinates of this neighboring identifier.
                uint256 neighborIdentifier = coordinateToIdentifier(
                    uint256(int256(x) + dx) % 65536,
                    uint256(int256(y) + dy) % 65536
                );
                
                if (identifierToOwner[neighborIdentifier] != 0x0) {
                    _plots[claimed] = neighborIdentifier;
                    claimed++;
                }
            }
        }
        
        // Memory arrays cannot be resized, so copy all
        // plots from the buffer to the plot array.
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
    /// @param _deedId The identifier of the new plot to calculate and assign dividends for.
    /// Assumed to be valid.
    function _calculateAndAssignClaimDividends(uint256 _deedId)
        internal
        returns (uint256 totalClaimDividend)
    {
        // Get existing surrounding plots.
        uint256[] memory claimedSurroundingPlots = _claimedSurroundingPlots(_deedId);
        
        // Keep track of the claim dividend.
        uint256 _claimDividend = claimDividend();
        totalClaimDividend = 0;
        
        // Assign claim dividend.
        for (uint256 i = 0; i < claimedSurroundingPlots.length; i++) {
            if (identifierToOwner[claimedSurroundingPlots[i]] != msg.sender) {
                totalClaimDividend = totalClaimDividend.add(_claimDividend);
                _assignClaimDividend(msg.sender, identifierToOwner[claimedSurroundingPlots[i]], _deedId, claimedSurroundingPlots[i]);
            }
        }
    }
    
    /// @dev Calculate the next buyout price given the current total buyout cost.
    /// @param totalCost The current total buyout cost.
    function nextBuyoutPrice(uint256 totalCost) public pure returns (uint256) {
        if (totalCost < 0.2 ether) {
            return totalCost * 2;
        } else if (totalCost < 0.5 ether) {
            return totalCost * 150 / 100; // * 1.5
        } else {
            return totalCost.mul(125).div(100); // * 1.25
        }
    }
    
    /// @notice Get the buyout cost for a given plot.
    /// @param _deedId The identifier of the plot to get the buyout cost for.
    function buyoutCost(uint256 _deedId) external view returns (uint256) {
        // The current buyout price.
        uint256 price = identifierToBuyoutPrice[_deedId];
    
        // Get existing surrounding plots.
        uint256[] memory claimedSurroundingPlots = _claimedSurroundingPlots(_deedId);
    
        // The total cost is the price plus flat rate dividends based on claim dividends.
        uint256 flatDividends = claimDividend().mul(claimedSurroundingPlots.length);
        return price.add(flatDividends);
    }
    
    /// @dev Assign the proceeds of the buyout.
    /// @param _deedId The identifier of the plot that is being bought out.
    function _assignBuyoutProceeds(
        address currentOwner,
        uint256 _deedId,
        uint256[] memory claimedSurroundingPlots,
        uint256 currentOwnerWinnings,
        uint256 totalDividendPerBeneficiary,
        uint256 totalCost
    )
        internal
    {
        // Calculate and assign the current owner's winnings.
        
        Buyout(msg.sender, currentOwner, _deedId, currentOwnerWinnings, totalCost, nextBuyoutPrice(totalCost));
        _assignBalance(currentOwner, currentOwnerWinnings);
        
        // Assign dividends to owners of surrounding plots.
        for (uint256 i = 0; i < claimedSurroundingPlots.length; i++) {
            address beneficiary = identifierToOwner[claimedSurroundingPlots[i]];
            BuyoutDividend(msg.sender, beneficiary, _deedId, claimedSurroundingPlots[i], totalDividendPerBeneficiary);
            _assignBalance(beneficiary, totalDividendPerBeneficiary);
        }
    }
    
    /// @dev Calculate and assign the proceeds from the buyout.
    /// @param currentOwner The current owner of the plot that is being bought out.
    /// @param _deedId The identifier of the plot that is being bought out.
    /// @param claimedSurroundingPlots The surrounding plots that have been claimed.
    function _calculateAndAssignBuyoutProceeds(address currentOwner, uint256 _deedId, uint256[] memory claimedSurroundingPlots)
        internal 
        returns (uint256 totalCost)
    {
        // The current price.
        uint256 price = identifierToBuyoutPrice[_deedId];
    
        // The total cost is the price plus flat rate dividends based on claim dividends.
        uint256 flatDividends = claimDividend().mul(claimedSurroundingPlots.length);
        totalCost = price.add(flatDividends);
        
        // Calculate the variable dividends based on the buyout price
        // (only to be paid if there are surrounding plots).
        uint256 variableDividends = price.mul(buyoutDividendPercentage).div(100000);
        
        // Calculate fees.
        uint256 fee = price.mul(buyoutFeePercentage).div(100000);
        
        // Calculate and assign buyout proceeds.
        uint256 currentOwnerWinnings = price.sub(fee);
        
        uint256 totalDividendPerBeneficiary;
        if (claimedSurroundingPlots.length > 0) {
            // If there are surrounding plots, variable dividend is to be paid
            // based on the buyout price..
            currentOwnerWinnings = currentOwnerWinnings.sub(variableDividends);
            
            // Calculate the dividend per surrounding plot.
            totalDividendPerBeneficiary = flatDividends.add(variableDividends) / claimedSurroundingPlots.length;
        }
        
        _assignBuyoutProceeds(
            currentOwner,
            _deedId,
            claimedSurroundingPlots,
            currentOwnerWinnings,
            totalDividendPerBeneficiary,
            totalCost
        );
    }
    
    /// @notice Buy the current owner out of the plot.
    function buyout(uint256 _deedId) external payable whenNotPaused {
        buyoutWithData(_deedId, "", "", "", "");
    }
    
    /// @notice Buy the current owner out of the plot.
    function buyoutWithData(uint256 _deedId, string name, string description, string imageUrl, string infoUrl)
        public
        payable
        whenNotPaused 
    {
        // Buyouts must be enabled.
        require(buyoutsEnabledFromTimestamp <= block.timestamp);
    
        address currentOwner = identifierToOwner[_deedId];
    
        // The plot must be owned before it can be bought out.
        require(currentOwner != 0x0);
        
        // Get existing surrounding plots.
        uint256[] memory claimedSurroundingPlots = _claimedSurroundingPlots(_deedId);
        
        // Assign the buyout proceeds and retrieve the total cost.
        uint256 totalCost = _calculateAndAssignBuyoutProceeds(currentOwner, _deedId, claimedSurroundingPlots);
        
        // Ensure the message has enough value.
        require(msg.value >= totalCost);
        
        // Transfer the plot.
        _transfer(currentOwner, msg.sender, _deedId);
        
        // Set the plot data
        SetData(_deedId, name, description, imageUrl, infoUrl);
        
        // Calculate and set the new plot price.
        identifierToBuyoutPrice[_deedId] = nextBuyoutPrice(totalCost);
        
        // Indicate the plot has been bought out at least once
        if (!identifierToBoughtOutOnce[_deedId]) {
            identifierToBoughtOutOnce[_deedId] = true;
        }
        
        // Calculate the excess Ether sent.
        // msg.value is greater than or equal to totalCost,
        // so this cannot underflow.
        uint256 excess = msg.value - totalCost;
        
        if (excess > 0) {
            // Refund any excess Ether (not susceptible to re-entry attack, as
            // the owner is assigned before the transfer takes place).
            msg.sender.transfer(excess);
        }
    }
    
    /// @notice Calculate the maximum initial buyout price for a plot.
    /// @param _deedId The identifier of the plot to get the maximum initial buyout price for.
    function maximumInitialBuyoutPrice(uint256 _deedId) public view returns (uint256) {
        // The initial buyout price can only be set to 10x the initial plot price
        // (or 100x for the original pre-migration plots).
        uint256 mul = 10;
        
        if (identifierIsOriginal[_deedId]) {
            mul = 100;
        }
        
        return initialPricePaid[_deedId].mul(mul);
    }
    
    /// @notice Test whether a buyout price is valid.
    /// @param _deedId The identifier of the plot to test the buyout price for.
    /// @param price The buyout price to test.
    function validInitialBuyoutPrice(uint256 _deedId, uint256 price) public view returns (bool) {        
        return (price >= unclaimedPlotPrice && price <= maximumInitialBuyoutPrice(_deedId));
    }
    
    /// @notice Manually set the initial buyout price of a plot.
    /// @param _deedId The identifier of the plot to set the buyout price for.
    /// @param price The value to set the buyout price to.
    function setInitialBuyoutPrice(uint256 _deedId, uint256 price) public whenNotPaused {
        // One can only set the buyout price of their own plots.
        require(_owns(msg.sender, _deedId));
        
        // The initial buyout price can only be set if the plot has never been bought out before.
        require(!identifierToBoughtOutOnce[_deedId]);
        
        // The buyout price must be valid.
        require(validInitialBuyoutPrice(_deedId, price));
        
        // Set the buyout price.
        identifierToBuyoutPrice[_deedId] = price;
        
        // Trigger the buyout price event.
        SetBuyoutPrice(_deedId, price);
    }
}
