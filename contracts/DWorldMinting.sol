pragma solidity ^0.4.18;

import "./DWorldRenting.sol";

/// @dev Holds functionality for minting new plot tokens.
contract DWorldMinting is DWorldRenting {
    uint256 public unclaimedPlotPrice = 0.0025 ether;
    mapping (address => uint256) freeClaimAllowance;
    
    /// @notice Sets the new price for unclaimed plots.
    /// @param _unclaimedPlotPrice The new price for unclaimed plots.
    function setUnclaimedPlotPrice(uint256 _unclaimedPlotPrice) external onlyCFO {
        unclaimedPlotPrice = _unclaimedPlotPrice;
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
       
    /// @notice Buy an unclaimed plot.
    /// @param _tokenId The unclaimed plot to buy.
    function claimPlot(uint256 _tokenId) external payable whenNotPaused {
        claimPlotWithData(_tokenId, "", "", "", "");
    }
       
    /// @notice Buy an unclaimed plot.
    /// @param _tokenId The unclaimed plot to buy.
    /// @param name The name to give the plot.
    /// @param description The description to add to the plot.
    /// @param imageUrl The image url for the plot.
    /// @param infoUrl The info url for the plot.
    function claimPlotWithData(uint256 _tokenId, string name, string description, string imageUrl, string infoUrl) public payable whenNotPaused {
        uint256[] memory _tokenIds = new uint256[](1);
        _tokenIds[0] = _tokenId;
        
        claimPlotMultipleWithData(_tokenIds, name, description, imageUrl, infoUrl);
    }
    
    /// @notice Buy unclaimed plots.
    /// @param _tokenIds The unclaimed plots to buy.
    function claimPlotMultiple(uint256[] _tokenIds) external payable whenNotPaused {
        claimPlotMultipleWithData(_tokenIds, "", "", "", "");
    }
    
    /// @notice Buy unclaimed plots.
    /// @param _tokenIds The unclaimed plots to buy.
    /// @param name The name to give the plots.
    /// @param description The description to add to the plots.
    /// @param imageUrl The image url for the plots.
    /// @param infoUrl The info url for the plots.
    function claimPlotMultipleWithData(uint256[] _tokenIds, string name, string description, string imageUrl, string infoUrl) public payable whenNotPaused {
        uint256 buyAmount = _tokenIds.length;
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
                
                // Cannot underflow, as freeAmount <= buyAmount.
                etherRequired = unclaimedPlotPrice.mul(buyAmount - freeAmount);
            }
        } else {
            // The sender does not have a free claim allowance.
            etherRequired = unclaimedPlotPrice.mul(buyAmount);
        }
        
        // Ensure enough ether is supplied.
        require(msg.value >= etherRequired);
        
        uint256 offset = plots.length;
        
        // Allocate additional memory for the plots array
        // (this is more efficient than .push-ing each individual
        // plot, as that requires multiple dynamic allocations).
        plots.length = plots.length.add(_tokenIds.length);
        
        for (uint256 i = 0; i < _tokenIds.length; i++) { 
            uint256 _tokenId = _tokenIds[i];
            require(validIdentifier(_tokenId));
            
            // The plot must be unowned (a plot token cannot be transferred to
            // 0x0, so once a plot is claimed it will always be owned by a
            // non-zero address).
            require(identifierToOwner[_tokenId] == address(0));
            
            // Create the plot
            plots[offset + i] = uint32(_tokenId);
            
            // Transfer the new plot to the sender.
            _transfer(address(0), msg.sender, _tokenId);
            
            // Set the plot data.
            _setPlotData(_tokenId, name, description, imageUrl, infoUrl);
        }
        
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
