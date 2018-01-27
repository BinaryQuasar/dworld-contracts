pragma solidity ^0.4.18;

import "./DWorldDeed.sol";

/// @dev Implements renting functionality.
contract DWorldRenting is DWorldDeed {
    event Rent(address indexed renter, uint256 indexed deedId, uint256 rentPeriodEndTimestamp, uint256 rentPeriod);
    mapping (uint256 => address) identifierToRenter;
    mapping (uint256 => uint256) identifierToRentPeriodEndTimestamp;

    /// @dev Checks if a given address rents a particular plot.
    /// @param _renter The address of the renter to check for.
    /// @param _deedId The plot identifier to check for.
    function _rents(address _renter, uint256 _deedId) internal view returns (bool) {
        return identifierToRenter[_deedId] == _renter && identifierToRentPeriodEndTimestamp[_deedId] >= now;
    }
    
    /// @dev Rent out a deed to an address.
    /// @param _to The address to rent the deed out to.
    /// @param _rentPeriod The rent period in seconds.
    /// @param _deedId The identifier of the deed to rent out.
    function _rentOut(address _to, uint256 _rentPeriod, uint256 _deedId) internal {
        // Set the renter and rent period end timestamp
        uint256 rentPeriodEndTimestamp = now.add(_rentPeriod);
        identifierToRenter[_deedId] = _to;
        identifierToRentPeriodEndTimestamp[_deedId] = rentPeriodEndTimestamp;
        
        Rent(_to, _deedId, rentPeriodEndTimestamp, _rentPeriod);
    }
    
    /// @notice Rents a plot out to another address.
    /// @param _to The address of the renter, can be a user or contract.
    /// @param _rentPeriod The rent time period in seconds.
    /// @param _deedId The identifier of the plot to rent out.
    function rentOut(address _to, uint256 _rentPeriod, uint256 _deedId) external whenNotPaused {
        uint256[] memory _deedIds = new uint256[](1);
        _deedIds[0] = _deedId;
        
        rentOutMultiple(_to, _rentPeriod, _deedIds);
    }
    
    /// @notice Rents multiple plots out to another address.
    /// @param _to The address of the renter, can be a user or contract.
    /// @param _rentPeriod The rent time period in seconds.
    /// @param _deedIds The identifiers of the plots to rent out.
    function rentOutMultiple(address _to, uint256 _rentPeriod, uint256[] _deedIds) public whenNotPaused {
        // Safety check to prevent against an unexpected 0x0 default.
        require(_to != address(0));
        
        // Disallow transfers to this contract to prevent accidental misuse.
        require(_to != address(this));
        
        for (uint256 i = 0; i < _deedIds.length; i++) {
            uint256 _deedId = _deedIds[i];
            
            require(validIdentifier(_deedId));
        
            // There should not be an active renter.
            require(identifierToRentPeriodEndTimestamp[_deedId] < now);
            
            // One can only rent out their own plots.
            require(_owns(msg.sender, _deedId));
            
            _rentOut(_to, _rentPeriod, _deedId);
        }
    }
    
    /// @notice Returns the address of the currently assigned renter and
    /// end time of the rent period of a given plot.
    /// @param _deedId The identifier of the deed to get the renter and 
    /// rent period for.
    function renterOf(uint256 _deedId) external view returns (address _renter, uint256 _rentPeriodEndTimestamp) {
        require(validIdentifier(_deedId));
    
        if (identifierToRentPeriodEndTimestamp[_deedId] < now) {
            // There is no active renter
            _renter = address(0);
            _rentPeriodEndTimestamp = 0;
        } else {
            _renter = identifierToRenter[_deedId];
            _rentPeriodEndTimestamp = identifierToRentPeriodEndTimestamp[_deedId];
        }
    }
}
