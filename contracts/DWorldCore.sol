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
    function setPlotData(uint256 _deedId, string name, string description, string imageUrl, string infoUrl)
        public
        whenNotPaused
    {
        // The sender requesting the data update should be
        // the owner (without an active renter) or should
        // be the active renter.
        require(_owns(msg.sender, _deedId) && identifierToRentPeriodEndTimestamp[_deedId] < now || _rents(msg.sender, _deedId));
    
        // Set the data
        _setPlotData(_deedId, name, description, imageUrl, infoUrl);
    }
    
    /// @notice Set the data associated with multiple plots.
    function setPlotDataMultiple(uint256[] _deedIds, string name, string description, string imageUrl, string infoUrl)
        public
        whenNotPaused
    {
        for (uint256 i = 0; i < _deedIds.length; i++) {
            uint256 _deedId = _deedIds[i];
        
            setPlotData(_deedId, name, description, imageUrl, infoUrl);
        }
    }
    
    /// @notice Allow the CFO to withdraw balance available to this contract.
    function withdrawBalance() external onlyCFO {
        cfoAddress.transfer(this.balance);
    }
}
