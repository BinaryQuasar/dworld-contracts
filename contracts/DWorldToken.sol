pragma solidity ^0.4.18;

import "./ERC721Draft.sol";
import "./DWorldBase.sol";

/// @dev Holds token functionality such as approving and transferring. Implements ERC721.
contract DWorldToken is DWorldBase, ERC721 {
    /// @notice Name and symbol of the non fungible token, as defined in ERC721.
    string public constant name = "DWorld Plots";
    string public constant symbol = "DWP";
    
    /// @dev Interface signature for ERC-165
    bytes4 constant INTERFACE_SIGNATURE_ERC165 =
        bytes4(keccak256('supportsInterface(bytes4)'));
    
    /// @notice Introspection interface as per ERC-165 (https://github.com/ethereum/EIPs/issues/165).
    /// Returns true for any standardized interfaces implemented by this contract.
    /// (ERC-165 and ERC-721.)
    function supportsInterface(bytes4 _interfaceID) external pure returns (bool) {
        return ((_interfaceID == INTERFACE_SIGNATURE_ERC165) || (_interfaceID == INTERFACE_SIGNATURE_ERC721));
    }
    
    /// @dev Checks if a given address owns a particular plot.
    /// @param _owner The address of the owner to check for.
    /// @param _tokenId The plot identifier to check for.
    function _owns(address _owner, uint256 _tokenId) internal view returns (bool) {
        return identifierToOwner[_tokenId] == _owner;
    }
    
    /// @dev Approve a give address to take ownership of a token.
    /// @param _from The address approving taking ownership.
    /// @param _to The address to approve taking ownership.
    /// @param _tokenId The plot identifier to give approval for.
    function _approve(address _from, address _to, uint256 _tokenId) internal {
        identifierToApproved[_tokenId] = _to;
        
        // Emit event.
        Approval(_from, _to, _tokenId);
    }
    
    /// @dev Checks if a given address has approval to take ownership of a plot.
    /// @param _claimant The address of the claimant to check for.
    /// @param _tokenId The plot identifier to check for.
    function _approvedFor(address _claimant, uint256 _tokenId) internal view returns (bool) {
        return identifierToApproved[_tokenId] == _claimant;
    }
    
    /// @dev Assigns ownership of a specific plot to an address.
    /// @param _from The address to transfer the token from.
    /// @param _to The address to transfer the token to.
    /// @param _tokenId The identifier of the token to transfer.
    function _transfer(address _from, address _to, uint256 _tokenId) internal {
        // The number of plots is capped at 2^16 * 2^16, so this cannot
        // be overflowed.
        ownershipTokenCount[_to]++;
        
        // Transfer ownership.
        identifierToOwner[_tokenId] = _to;
        
        // When a new plot is minted, the _from address is 0x0, but we
        // do not track token ownership of 0x0.
        if (_from != address(0)) {
            ownershipTokenCount[_from]--;
            
            // Clear taking ownership approval.
            delete identifierToApproved[_tokenId];
        }
        
        // Emit the transfer event.
        Transfer(_from, _to, _tokenId);
    }
    
    // ERC 721 implementation
    
    /// @notice Returns the total number of plots currently in existence.
    /// @dev Required for ERC-721 compliance.
    function totalSupply() public view returns (uint256) {
        return plots.length;
    }
    
    /// @notice Returns the number of Kitties owned by a specific address.
    /// @param _owner The owner address to check.
    /// @dev Required for ERC-721 compliance
    function balanceOf(address _owner) public view returns (uint256) {
        return ownershipTokenCount[_owner];
    }
    
    /// @notice Returns the address currently assigned ownership of a given plot.
    /// @dev Required for ERC-721 compliance.
    function ownerOf(uint256 _tokenId) external view returns (address _owner) {
        _owner = identifierToOwner[_tokenId];

        require(_owner != address(0));
    }
    
    /// @notice Approve a given address to take ownership of a token.
    /// @param _to The address to approve taking owernship.
    /// @param _tokenId The token identifier to give approval for.
    /// @dev Required for ERC-721 compliance.
    function approve(address _to, uint256 _tokenId) external whenNotPaused {
        uint256[] memory _tokenIds = new uint256[](1);
        _tokenIds[0] = _tokenId;
        
        approveMultiple(_to, _tokenIds);
    }
    
    /// @notice Approve a given address to take ownership of multiple tokens.
    /// @param _to The address to approve taking ownership.
    /// @param _tokenIds The token identifiers to give approval for.
    function approveMultiple(address _to, uint256[] _tokenIds) public whenNotPaused {
        for (uint256 i = 0; i < _tokenIds.length; i++) {
            uint256 _tokenId = _tokenIds[i];
            
            // Require the sender is the owner of the token.
            require(_owns(msg.sender, _tokenId));
            
            // Perform the approval.
            _approve(msg.sender, _to, _tokenId);
        }
    }
    
    /// @notice Transfers a plot to another address. If transferring to a smart
    /// contract be VERY CAREFUL to ensure that it is aware of ERC-721, or your
    /// plot may be lost forever.
    /// @param _to The address of the recipient, can be a user or contract.
    /// @param _tokenId The identifier of the plot to transfer.
    /// @dev Required for ERC-721 compliance.
    function transfer(address _to, uint256 _tokenId) external whenNotPaused {
        uint256[] memory _tokenIds = new uint256[](1);
        _tokenIds[0] = _tokenId;
        
        transferMultiple(_to, _tokenIds);
    }
    
    /// @notice Transfers multiple plots to another address. If transferring to
    /// a smart contract be VERY CAREFUL to ensure that it is aware of ERC-721,
    /// or your plots may be lost forever.
    /// @param _to The address of the recipient, can be a user or contract.
    /// @param _tokenIds The identifiers of the plots to transfer.
    function transferMultiple(address _to, uint256[] _tokenIds) public whenNotPaused {
        // Safety check to prevent against an unexpected 0x0 default.
        require(_to != address(0));
        
        // Disallow transfers to this contract to prevent accidental misuse.
        require(_to != address(this));
    
        for (uint256 i = 0; i < _tokenIds.length; i++) {
            uint256 _tokenId = _tokenIds[i];
            
            // One can only transfer their own plots.
            require(_owns(msg.sender, _tokenId));

            // Transfer ownership
            _transfer(msg.sender, _to, _tokenId);
        }
    }
    
    /// @notice Transfer a plot owned by another address, for which the calling
    /// address has previously been granted transfer approval by the owner.
    /// @param _tokenId The identifier of the plot to be transferred.
    /// @dev Required for ERC-721 compliance.
    function takeOwnership(uint256 _tokenId) external whenNotPaused {
        uint256[] memory _tokenIds = new uint256[](1);
        _tokenIds[0] = _tokenId;
        
        takeOwnershipMultiple(_tokenIds);
    }
    
    /// @notice Transfer multiple plots owned by another address, for which the
    /// calling address has previously been granted transfer approval by the owner.
    /// @param _tokenIds The identifier of the plot to be transferred.
    function takeOwnershipMultiple(uint256[] _tokenIds) public whenNotPaused {
        for (uint256 i = 0; i < _tokenIds.length; i++) {
            uint256 _tokenId = _tokenIds[i];
            address _from = identifierToOwner[_tokenId];
            
            // Check for transfer approval
            require(_approvedFor(msg.sender, _tokenId));

            // Reassign ownership (also clears pending approvals and emits Transfer event).
            _transfer(_from, msg.sender, _tokenId);
        }
    }
    
    /// @notice Returns a list of all plot identifiers assigned to an address.
    /// @param _owner The owner whose plots we are interested in.
    /// @dev This method MUST NEVER be called by smart contract code. It's very
    /// expensive and is not supported in contract-to-contract calls as it returns
    /// a dynamic array (only supported for web3 calls).
    function tokensOfOwner(address _owner) external view returns(uint256[]) {
        uint256 tokenCount = balanceOf(_owner);

        if (tokenCount == 0) {
            // Return an empty array.
            return new uint256[](0);
        } else {
            uint256[] memory result = new uint256[](tokenCount);
            uint256 totalPlots = totalSupply();
            uint256 resultIndex = 0;
            
            for (uint256 plotNumber = 0; plotNumber <= totalPlots; plotNumber++) {
                uint256 identifier = plots[plotNumber];
                if (identifierToOwner[identifier] == _owner) {
                    result[resultIndex] = identifier;
                    resultIndex++;
                }
            }

            return result;
        }
    }
    
    /// @notice Returns an (off-chain) metadata url for the given token.
    /// @param _tokenId The identifier of the token to get the metadata
    /// url for.
    /// @dev Implementation of optional ERC-721 functionality.
    function tokenMetadata(uint256 _tokenId) external pure returns (string metadataUrl) {
        require(validIdentifier(_tokenId));
    
        var (x, y) = identifierToCoordinate(_tokenId);
    
        // Maximum coordinate length in decimals is 5 (65535)
        metadataUrl = "https://dworld.io/plot/xxxxx/xxxxx";
        bytes memory _metadataUrl = bytes(metadataUrl);
        
        for (uint256 i = 0; i < 5; i++) {
            _metadataUrl[27 - i] = byte(48 + (x / 10 ** i) % 10);
            _metadataUrl[33 - i] = byte(48 + (y / 10 ** i) % 10);
        }
    }
}
