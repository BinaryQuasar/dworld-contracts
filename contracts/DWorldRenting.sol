pragma solidity ^0.4.18;

import "./DWorldToken.sol";

/// @dev Implements renting functionality.
contract DWorldRenting is DWorldToken {
    event Rent(address indexed renter, uint256 indexed tokenId, uint256 rentPeriod);
    mapping (uint256 => address) identifierToRenter;
    mapping (uint256 => uint256) identifierToRentPeriodEndTimestamp;

    /// @dev Checks if a given address rents a particular plot.
    /// @param _renter The address of the renter to check for.
    /// @param _tokenId The plot identifier to check for.
    function _rents(address _renter, uint256 _tokenId) internal view returns (bool) {
        return identifierToRenter[_tokenId] == _renter && identifierToRentPeriodEndTimestamp[_tokenId] >= now;
    }
    
    /// @dev Rent out a token to an address.
    /// @param _to The address to rent the token out to.
    /// @param _rentPeriod The rent period in seconds.
    /// @param _tokenId The identifier of the token to rent out.
    function _rentOut(address _to, uint256 _rentPeriod, uint256 _tokenId) internal {
        // Set the renter and rent period end timestamp
        identifierToRenter[_tokenId] = _to;
        identifierToRentPeriodEndTimestamp[_tokenId] = now.add(_rentPeriod);
        
        Rent(_to, _tokenId, _rentPeriod);
    }
    
    /// @notice Rents a plot out to another address.
    /// @param _to The address of the renter, can be a user or contract.
    /// @param _rentPeriod The rent time period in seconds.
    /// @param _tokenId The identifier of the plot to rent out.
    function rentOut(address _to, uint256 _rentPeriod, uint256 _tokenId) external whenNotPaused {
        uint256[] memory _tokenIds = new uint256[](1);
        _tokenIds[0] = _tokenId;
        
        rentOutMultiple(_to, _rentPeriod, _tokenIds);
    }
    
    /// @notice Rents multiple plots out to another address.
    /// @param _to The address of the renter, can be a user or contract.
    /// @param _rentPeriod The rent time period in seconds.
    /// @param _tokenIds The identifiers of the plots to rent out.
    function rentOutMultiple(address _to, uint256 _rentPeriod, uint256[] _tokenIds) public whenNotPaused {
        // Safety check to prevent against an unexpected 0x0 default.
        require(_to != address(0));
        
        // Disallow transfers to this contract to prevent accidental misuse.
        require(_to != address(this));
        
        for (uint256 i = 0; i < _tokenIds.length; i++) {
            uint256 _tokenId = _tokenIds[i];
            
            require(validIdentifier(_tokenId));
        
            // There should not be an active renter.
            require(identifierToRentPeriodEndTimestamp[_tokenId] < now);
            
            // One can only rent out their own plots.
            require(_owns(msg.sender, _tokenId));
            
            _rentOut(_to, _rentPeriod, _tokenId);
        }
    }
    
    /// @notice Returns the address of the currently assigned renter and
    /// end time of the rent period of a given plot.
    /// @param _tokenId The identifier of the token to get the renter and 
    /// rent period for.
    function renterOf(uint256 _tokenId) external view returns (address _renter, uint256 _rentPeriodEndTimestamp) {
        require(validIdentifier(_tokenId));
    
        if (identifierToRentPeriodEndTimestamp[_tokenId] < now) {
            // There is no active renter
            _renter = address(0);
            _rentPeriodEndTimestamp = 0;
        } else {
            _renter = identifierToRenter[_tokenId];
            _rentPeriodEndTimestamp = identifierToRentPeriodEndTimestamp[_tokenId];
        }
    }
}
