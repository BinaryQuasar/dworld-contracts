pragma solidity ^0.4.18;

import "./ERC721.sol";
import "./ERC721Metadata.sol";
import "./DWorldBase.sol";

/// @dev Holds deed functionality such as approving and transferring. Implements ERC721.
contract DWorldDeed is DWorldBase, ERC721, ERC721Metadata {
    
    /// @notice Name of the collection of deeds (non-fungible token), as defined in ERC721Metadata.
    function name() public pure returns (string _deedName) {
        _deedName = "DWorld Plots";
    }
    
    /// @notice Symbol of the collection of deeds (non-fungible token), as defined in ERC721Metadata.
    function symbol() public pure returns (string _deedSymbol) {
        _deedSymbol = "DWP";
    }
    
    /// @dev ERC-165 (draft) interface signature for itself
    bytes4 internal constant INTERFACE_SIGNATURE_ERC165 = // 0x01ffc9a7
        bytes4(keccak256('supportsInterface(bytes4)'));

    /// @dev ERC-165 (draft) interface signature for ERC721
    bytes4 internal constant INTERFACE_SIGNATURE_ERC721 = // 0xda671b9b
        bytes4(keccak256('ownerOf(uint256)')) ^
        bytes4(keccak256('countOfDeeds()')) ^
        bytes4(keccak256('countOfDeedsByOwner(address)')) ^
        bytes4(keccak256('deedOfOwnerByIndex(address,uint256)')) ^
        bytes4(keccak256('approve(address,uint256)')) ^
        bytes4(keccak256('takeOwnership(uint256)'));
        
    /// @dev ERC-165 (draft) interface signature for ERC721
    bytes4 internal constant INTERFACE_SIGNATURE_ERC721Metadata = // 0x2a786f11
        bytes4(keccak256('name()')) ^
        bytes4(keccak256('symbol()')) ^
        bytes4(keccak256('deedUri(uint256)'));
    
    /// @notice Introspection interface as per ERC-165 (https://github.com/ethereum/EIPs/issues/165).
    /// Returns true for any standardized interfaces implemented by this contract.
    /// (ERC-165 and ERC-721.)
    function supportsInterface(bytes4 _interfaceID) external pure returns (bool) {
        return (
            (_interfaceID == INTERFACE_SIGNATURE_ERC165)
            || (_interfaceID == INTERFACE_SIGNATURE_ERC721)
            || (_interfaceID == INTERFACE_SIGNATURE_ERC721Metadata)
        );
    }
    
    /// @dev Checks if a given address owns a particular plot.
    /// @param _owner The address of the owner to check for.
    /// @param _deedId The plot identifier to check for.
    function _owns(address _owner, uint256 _deedId) internal view returns (bool) {
        return identifierToOwner[_deedId] == _owner;
    }
    
    /// @dev Approve a given address to take ownership of a deed.
    /// @param _from The address approving taking ownership.
    /// @param _to The address to approve taking ownership.
    /// @param _deedId The identifier of the deed to give approval for.
    function _approve(address _from, address _to, uint256 _deedId) internal {
        identifierToApproved[_deedId] = _to;
        
        // Emit event.
        Approval(_from, _to, _deedId);
    }
    
    /// @dev Checks if a given address has approval to take ownership of a deed.
    /// @param _claimant The address of the claimant to check for.
    /// @param _deedId The identifier of the deed to check for.
    function _approvedFor(address _claimant, uint256 _deedId) internal view returns (bool) {
        return identifierToApproved[_deedId] == _claimant;
    }
    
    /// @dev Assigns ownership of a specific deed to an address.
    /// @param _from The address to transfer the deed from.
    /// @param _to The address to transfer the deed to.
    /// @param _deedId The identifier of the deed to transfer.
    function _transfer(address _from, address _to, uint256 _deedId) internal {
        // The number of plots is capped at 2^16 * 2^16, so this cannot
        // be overflowed.
        ownershipDeedCount[_to]++;
        
        // Transfer ownership.
        identifierToOwner[_deedId] = _to;
        
        // When a new deed is minted, the _from address is 0x0, but we
        // do not track deed ownership of 0x0.
        if (_from != address(0)) {
            ownershipDeedCount[_from]--;
            
            // Clear taking ownership approval.
            delete identifierToApproved[_deedId];
        }
        
        // Emit the transfer event.
        Transfer(_from, _to, _deedId);
    }
    
    // ERC 721 implementation
    
    /// @notice Returns the total number of deeds currently in existence.
    /// @dev Required for ERC-721 compliance.
    function countOfDeeds() public view returns (uint256) {
        return plots.length;
    }
    
    /// @notice Returns the number of deeds owned by a specific address.
    /// @param _owner The owner address to check.
    /// @dev Required for ERC-721 compliance
    function countOfDeedsByOwner(address _owner) public view returns (uint256) {
        return ownershipDeedCount[_owner];
    }
    
    /// @notice Returns the address currently assigned ownership of a given deed.
    /// @dev Required for ERC-721 compliance.
    function ownerOf(uint256 _deedId) external view returns (address _owner) {
        _owner = identifierToOwner[_deedId];

        require(_owner != address(0));
    }
    
    /// @notice Approve a given address to take ownership of a deed.
    /// @param _to The address to approve taking owernship.
    /// @param _deedId The identifier of the deed to give approval for.
    /// @dev Required for ERC-721 compliance.
    function approve(address _to, uint256 _deedId) external whenNotPaused {
        uint256[] memory _deedIds = new uint256[](1);
        _deedIds[0] = _deedId;
        
        approveMultiple(_to, _deedIds);
    }
    
    /// @notice Approve a given address to take ownership of multiple deeds.
    /// @param _to The address to approve taking ownership.
    /// @param _deedIds The identifiers of the deeds to give approval for.
    function approveMultiple(address _to, uint256[] _deedIds) public whenNotPaused {
        // Ensure the sender is not approving themselves.
        require(msg.sender != _to);
    
        for (uint256 i = 0; i < _deedIds.length; i++) {
            uint256 _deedId = _deedIds[i];
            
            // Require the sender is the owner of the deed.
            require(_owns(msg.sender, _deedId));
            
            // Perform the approval.
            _approve(msg.sender, _to, _deedId);
        }
    }
    
    /// @notice Transfer a deed to another address. If transferring to a smart
    /// contract be VERY CAREFUL to ensure that it is aware of ERC-721, or your
    /// deed may be lost forever.
    /// @param _to The address of the recipient, can be a user or contract.
    /// @param _deedId The identifier of the deed to transfer.
    /// @dev Required for ERC-721 compliance.
    function transfer(address _to, uint256 _deedId) external whenNotPaused {
        uint256[] memory _deedIds = new uint256[](1);
        _deedIds[0] = _deedId;
        
        transferMultiple(_to, _deedIds);
    }
    
    /// @notice Transfers multiple deeds to another address. If transferring to
    /// a smart contract be VERY CAREFUL to ensure that it is aware of ERC-721,
    /// or your deeds may be lost forever.
    /// @param _to The address of the recipient, can be a user or contract.
    /// @param _deedIds The identifiers of the deeds to transfer.
    function transferMultiple(address _to, uint256[] _deedIds) public whenNotPaused {
        // Safety check to prevent against an unexpected 0x0 default.
        require(_to != address(0));
        
        // Disallow transfers to this contract to prevent accidental misuse.
        require(_to != address(this));
    
        for (uint256 i = 0; i < _deedIds.length; i++) {
            uint256 _deedId = _deedIds[i];
            
            // One can only transfer their own plots.
            require(_owns(msg.sender, _deedId));

            // Transfer ownership
            _transfer(msg.sender, _to, _deedId);
        }
    }
    
    /// @notice Transfer a deed owned by another address, for which the calling
    /// address has previously been granted transfer approval by the owner.
    /// @param _deedId The identifier of the deed to be transferred.
    /// @dev Required for ERC-721 compliance.
    function takeOwnership(uint256 _deedId) external whenNotPaused {
        uint256[] memory _deedIds = new uint256[](1);
        _deedIds[0] = _deedId;
        
        takeOwnershipMultiple(_deedIds);
    }
    
    /// @notice Transfer multiple deeds owned by another address, for which the
    /// calling address has previously been granted transfer approval by the owner.
    /// @param _deedIds The identifier of the deed to be transferred.
    function takeOwnershipMultiple(uint256[] _deedIds) public whenNotPaused {
        for (uint256 i = 0; i < _deedIds.length; i++) {
            uint256 _deedId = _deedIds[i];
            address _from = identifierToOwner[_deedId];
            
            // Check for transfer approval
            require(_approvedFor(msg.sender, _deedId));

            // Reassign ownership (also clears pending approvals and emits Transfer event).
            _transfer(_from, msg.sender, _deedId);
        }
    }
    
    /// @notice Returns a list of all deed identifiers assigned to an address.
    /// @param _owner The owner whose deeds we are interested in.
    /// @dev This method MUST NEVER be called by smart contract code. It's very
    /// expensive and is not supported in contract-to-contract calls as it returns
    /// a dynamic array (only supported for web3 calls).
    function deedsOfOwner(address _owner) external view returns(uint256[]) {
        uint256 deedCount = countOfDeedsByOwner(_owner);

        if (deedCount == 0) {
            // Return an empty array.
            return new uint256[](0);
        } else {
            uint256[] memory result = new uint256[](deedCount);
            uint256 totalDeeds = countOfDeeds();
            uint256 resultIndex = 0;
            
            for (uint256 deedNumber = 0; deedNumber < totalDeeds; deedNumber++) {
                uint256 identifier = plots[deedNumber];
                if (identifierToOwner[identifier] == _owner) {
                    result[resultIndex] = identifier;
                    resultIndex++;
                }
            }

            return result;
        }
    }
    
    /// @notice Returns a deed identifier of the owner at the given index.
    /// @param _owner The address of the owner we want to get a deed for.
    /// @param _index The index of the deed we want.
    function deedOfOwnerByIndex(address _owner, uint256 _index) external view returns (uint256) {
        // The index should be valid.
        require(_index < countOfDeedsByOwner(_owner));

        // Loop through all plots, accounting the number of plots of the owner we've seen.
        uint256 seen = 0;
        uint256 totalDeeds = countOfDeeds();
        
        for (uint256 deedNumber = 0; deedNumber < totalDeeds; deedNumber++) {
            uint256 identifier = plots[deedNumber];
            if (identifierToOwner[identifier] == _owner) {
                if (seen == _index) {
                    return identifier;
                }
                
                seen++;
            }
        }
    }
    
    /// @notice Returns an (off-chain) metadata url for the given deed.
    /// @param _deedId The identifier of the deed to get the metadata
    /// url for.
    /// @dev Implementation of optional ERC-721 functionality.
    function deedUri(uint256 _deedId) external pure returns (string uri) {
        require(validIdentifier(_deedId));
    
        var (x, y) = identifierToCoordinate(_deedId);
    
        // Maximum coordinate length in decimals is 5 (65535)
        uri = "https://dworld.io/plot/xxxxx/xxxxx";
        bytes memory _uri = bytes(uri);
        
        for (uint256 i = 0; i < 5; i++) {
            _uri[27 - i] = byte(48 + (x / 10 ** i) % 10);
            _uri[33 - i] = byte(48 + (y / 10 ** i) % 10);
        }
    }
}
