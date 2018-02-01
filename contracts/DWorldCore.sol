pragma solidity ^0.4.18;

import "./DWorldMinting.sol";

/// @dev Implements highest-level DWorld functionality.
contract DWorldCore is DWorldMinting {
    /// If this contract is broken, this will be used to publish the address at which an upgraded contract can be found
    address public upgradedContractAddress;
    event ContractUpgrade(address upgradedContractAddress);

    /// @notice Only to be used when this contract is significantly broken,
    /// and an upgrade is required.
    function setUpgradedContractAddress(address _upgradedContractAddress) external onlyOwner whenPaused {
        upgradedContractAddress = _upgradedContractAddress;
        ContractUpgrade(_upgradedContractAddress);
    }

    /// @notice Set the data associated with a plot.
    function setPlotData(uint256 _deedId, string name, string description, string imageUrl, string infoUrl)
        public
        whenNotPaused
    {
        // The sender requesting the data update should be
        // the owner.
        require(_owns(msg.sender, _deedId));
    
        // Set the data
        _setPlotData(_deedId, name, description, imageUrl, infoUrl);
    }
    
    /// @notice Set the data associated with multiple plots.
    function setPlotDataMultiple(uint256[] _deedIds, string name, string description, string imageUrl, string infoUrl)
        external
        whenNotPaused
    {
        for (uint256 i = 0; i < _deedIds.length; i++) {
            uint256 _deedId = _deedIds[i];
        
            setPlotData(_deedId, name, description, imageUrl, infoUrl);
        }
    }
    
    /// @notice Withdraw Ether owed to the sender.
    function withdrawBalance() external {
        uint256 etherOwed = addressToEtherOwed[msg.sender];
        
        // Ensure Ether is owed to the sender.
        require(etherOwed > 0);
         
        // Set Ether owed to 0.
        delete addressToEtherOwed[msg.sender];
        
        // Subtract from total outstanding balance. etherOwed is guaranteed
        // to be less than or equal to outstandingEther, so this cannot
        // underflow.
        outstandingEther -= etherOwed;
        
        // Transfer Ether owed to the sender (not susceptible to re-entry
        // attack, as the Ether owed is set to 0 before the transfer takes place).
        msg.sender.transfer(etherOwed);
    }
    
    /// @notice Withdraw (unowed) contract balance.
    function withdrawFreeBalance() external onlyCFO {
        // Calculate the free (unowed) balance. This never underflows, as
        // outstandingEther is guaranteed to be less than or equal to the
        // contract balance.
        uint256 freeBalance = this.balance - outstandingEther;
        
        cfoAddress.transfer(freeBalance);
    }
}
