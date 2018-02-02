pragma solidity ^0.4.18;

import "./DWorldFinance.sol";

/// @dev Holds functionality for minting new plot deeds.
contract DWorldMinting is DWorldFinance {       
    /// @notice Buy an unclaimed plot.
    /// @param _deedId The unclaimed plot to buy.
    /// @param _buyoutPrice The initial buyout price to set on the plot.
    function claimPlot(uint256 _deedId, uint256 _buyoutPrice) external payable whenNotPaused {
        claimPlotWithData(_deedId, _buyoutPrice, "", "", "", "");
    }
       
    /// @notice Buy an unclaimed plot.
    /// @param _deedId The unclaimed plot to buy.
    /// @param _buyoutPrice The initial buyout price to set on the plot.
    /// @param name The name to give the plot.
    /// @param description The description to add to the plot.
    /// @param imageUrl The image url for the plot.
    /// @param infoUrl The info url for the plot.
    function claimPlotWithData(uint256 _deedId, uint256 _buyoutPrice, string name, string description, string imageUrl, string infoUrl) public payable whenNotPaused {
        uint256[] memory _deedIds = new uint256[](1);
        _deedIds[0] = _deedId;
        
        claimPlotMultipleWithData(_deedIds, _buyoutPrice, name, description, imageUrl, infoUrl);
    }
    
    /// @notice Buy unclaimed plots.
    /// @param _deedIds The unclaimed plots to buy.
    /// @param _buyoutPrice The initial buyout price to set on the plot.
    function claimPlotMultiple(uint256[] _deedIds, uint256 _buyoutPrice) external payable whenNotPaused {
        claimPlotMultipleWithData(_deedIds, _buyoutPrice, "", "", "", "");
    }
    
    /// @notice Buy unclaimed plots.
    /// @param _deedIds The unclaimed plots to buy.
    /// @param _buyoutPrice The initial buyout price to set on the plot.
    /// @param name The name to give the plots.
    /// @param description The description to add to the plots.
    /// @param imageUrl The image url for the plots.
    /// @param infoUrl The info url for the plots.
    function claimPlotMultipleWithData(uint256[] _deedIds, uint256 _buyoutPrice, string name, string description, string imageUrl, string infoUrl) public payable whenNotPaused {
        uint256 buyAmount = _deedIds.length;
        uint256 etherRequired;
        if (freeClaimAllowance[msg.sender] > 0) {
            // The sender has a free claim allowance.
            if (freeClaimAllowance[msg.sender] > buyAmount) {
                // Subtract from allowance.
                freeClaimAllowance[msg.sender] -= buyAmount;
                
                // No ether is required.
                etherRequired = 0;
            } else {
                uint256 freeAmount = freeClaimAllowance[msg.sender];
                
                // The full allowance has been used.
                delete freeClaimAllowance[msg.sender];
                
                // The subtraction cannot underflow, as freeAmount <= buyAmount.
                etherRequired = unclaimedPlotPrice.mul(buyAmount - freeAmount);
            }
        } else {
            // The sender does not have a free claim allowance.
            etherRequired = unclaimedPlotPrice.mul(buyAmount);
        }
        
        uint256 offset = plots.length;
        
        // Allocate additional memory for the plots array
        // (this is more efficient than .push-ing each individual
        // plot, as that requires multiple dynamic allocations).
        plots.length = plots.length.add(_deedIds.length);
        
        for (uint256 i = 0; i < _deedIds.length; i++) { 
            uint256 _deedId = _deedIds[i];
            require(validIdentifier(_deedId));
            
            // The plot must be unowned (a plot deed cannot be transferred to
            // 0x0, so once a plot is claimed it will always be owned by a
            // non-zero address).
            require(identifierToOwner[_deedId] == address(0));
            
            // Create the plot
            plots[offset + i] = uint32(_deedId);
            
            // Transfer the new plot to the sender.
            _transfer(address(0), msg.sender, _deedId);
            
            // Set the plot data.
            _setPlotData(_deedId, name, description, imageUrl, infoUrl);
            
            // Calculate and assign claim dividends.
            uint256 claimDividends = _calculateAndAssignClaimDividends(_deedId);
            etherRequired = etherRequired.add(claimDividends);
            
            // Set the initial price paid for the plot.
            initialPricePaid[_deedId] = unclaimedPlotPrice.add(claimDividends);
            
            // Set the initial buyout price. Throws if it does not succeed.
            setInitialBuyoutPrice(_deedId, _buyoutPrice);
        }
        
        // Ensure enough ether is supplied.
        require(msg.value >= etherRequired);
        
        // Calculate the excess ether sent
        // msg.value is greater than or equal to etherRequired,
        // so this cannot underflow.
        uint256 excess = msg.value - etherRequired;
        
        if (excess > 0) {
            // Refund any excess ether (not susceptible to re-entry attack, as
            // the owner is assigned before the transfer takes place).
            msg.sender.transfer(excess);
        }
    }
}
