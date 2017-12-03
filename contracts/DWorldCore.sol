pragma solidity ^0.4.18;

import "./DWorldAuction.sol";

contract DWorldCore is DWorldAuction {
    /// @notice Set the data associated with a plot.
    function setPlotData(uint256 _tokenId, string name, string description, string imageUrl, string infoUrl) public {
        // The sender requesting the data update should be the owner
        require(_owns(msg.sender, _tokenId));
    
        // Set the data
        identifierToPlot[_tokenId].name = name;
        identifierToPlot[_tokenId].description = description;
        identifierToPlot[_tokenId].imageUrl = imageUrl;
        identifierToPlot[_tokenId].infoUrl = infoUrl;
    }
    
    /// @notice Set the data associated with multiple plots.
    function setPlotDataMultiple(uint256[] _tokenIds, string name, string description, string imageUrl, string infoUrl) public {
        for (uint256 i = 0; i < _tokenIds.length; i++) {
            uint256 _tokenId = _tokenIds[i];
        
            setPlotData(_tokenId, name, description, imageUrl, infoUrl);
        }
    }

    /// @dev Allow the CFO to withdraw balance available to this contract (minus
    /// ether owed through auctions).
    function withdrawBalance() external onlyCFO {
        cfoAddress.transfer(this.balance - outstandingEther);
    }
}
