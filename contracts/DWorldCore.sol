pragma solidity ^0.4.18;

import "./DWorldAuction.sol";

/// @dev Implements highest-level DWorld functionality.
contract DWorldCore is DWorldAuction {
    /// If this contract is broken, this will be used to publish the address at which an upgraded contract can be found
    address public upgradedContractAddress;
    event ContractUpgrade(address upgradedContractAddress);

    /// @notice Only to be used when this contract is significantly broken,
    /// and an upgrade is required.
    function setUpgradedContractAddress(address _upgradedContractAddress) public onlyOwner whenPaused {
        upgradedContractAddress = _upgradedContractAddress;
        ContractUpgrade(_upgradedContractAddress);
    }

    /// @notice Set the data associated with a plot.
    function setPlotData(uint256 _tokenId, string name, string description, string imageUrl, string infoUrl)
        public
        whenNotPaused
    {
        // The sender requesting the data update should be the owner
        require(_owns(msg.sender, _tokenId));
    
        // Set the data
        identifierToPlot[_tokenId].name = name;
        identifierToPlot[_tokenId].description = description;
        identifierToPlot[_tokenId].imageUrl = imageUrl;
        identifierToPlot[_tokenId].infoUrl = infoUrl;
    }
    
    /// @notice Set the data associated with multiple plots.
    function setPlotDataMultiple(uint256[] _tokenIds, string name, string description, string imageUrl, string infoUrl)
        public
        whenNotPaused
    {
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
