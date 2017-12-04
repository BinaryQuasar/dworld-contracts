pragma solidity ^0.4.18;

import "./DWorldToken.sol";

contract DWorldMinting is DWorldToken {
    uint256 public unclaimedPlotPrice = 0.0025 ether;
    
    /// @notice Sets the new price for unclaimed plots.
    /// @param _unclaimedPlotPrice The new price for unclaimed plots.
    function setUnclaimedPlotPrice(uint256 _unclaimedPlotPrice) external onlyCFO {
        unclaimedPlotPrice = _unclaimedPlotPrice;
    }
    
    /// @notice Buy an unclaimed plot.
    /// @param _tokenId The unclaimed plot to buy.
    function claimPlot(uint256 _tokenId) external payable {
        uint256[] memory _tokenIds = new uint256[](1);
        _tokenIds[0] = _tokenId;
        
        claimPlotMultiple(_tokenIds);
    }
    
    /// @notice Buy unclaimed plots.
    /// @param _tokenIds The unclaimed plots to buy.
    function claimPlotMultiple(uint256[] _tokenIds) public payable {
        uint256 etherRequired = unclaimedPlotPrice * _tokenIds.length;
        
        // Ensure enough ether is supplied.
        require(msg.value >= etherRequired);
        
        uint256 offset = plots.length;
        
        // Allocate additional memory for the plots array
        // (this is more efficient than .push-ing each individual
        // plot, as that requires multiple dynamic allocations).
        plots.length += _tokenIds.length;
        
        for (uint256 i = 0; i < _tokenIds.length; i++) { 
            uint256 _tokenId = _tokenIds[i];
            require(validIdentifier(_tokenId));
            
            // The plot must be unowned (a plot token cannot be transferred to
            // 0x0, so once a plot is claimed it will always be owned by a
            // non-zero address).
            require(identifierToOwner[_tokenId] == address(0));
            
            // Create the plot and associate it with the plot identifier
            identifierToPlot[_tokenId].mintedTimestamp = now;
            plots[offset + i] = _tokenId;
            
            // Transfer the new plot to the sender.
            _transfer(address(0), msg.sender, _tokenId);
        }
        
        // Calculate the excess ether sent.
        uint256 excess = msg.value - etherRequired;
        
        if (excess > 0) {
            // Refund any excess ether (not susceptible to re-entry attack, as
            // the owner is assigned before the transfer takes place).
            msg.sender.transfer(excess);
        }
    }
}
