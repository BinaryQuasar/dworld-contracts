pragma solidity ^0.4.18;

import "./DWorldAccessControl.sol";

contract DWorldBase is DWorldAccessControl {
    
    /// @dev Transfer event as defined in the ERC721. Emitted every time plot 
    /// ownership is assigned.
    event Transfer(address from, address to, uint256 tokenId);
    
    /// Plot data
    struct Plot {
        uint256 mintedTimestamp;
        string name;
        string description;
        string imageUrl;
        string infoUrl;
    }
    
    /// @dev All minted plots (array of plot identifiers). There are
    /// 2^17 * 2^17 possible plots (covering the entire world), thus
    /// at least 34 bits are required. This fits in a uint40. Storing
    /// the identifiers as uint40 instead of uint256 makes storage
    /// cheaper. (The impact of this in mappings is less noticeable,
    /// and using uint40 in the mappings below actually *increases*
    /// gas cost for minting).
    uint40[] plots;
    
    mapping (uint256 => Plot) public identifierToPlot;
    mapping (uint256 => address) identifierToOwner;
    mapping (uint256 => address) identifierToApproved;
    mapping (address => uint256) ownershipTokenCount;
    
    /// @dev Represent a 2D coordinate as a single uint.
    /// @param x The x-coordinate.
    /// @param y The y-coordinate.
    function coordinateToIdentifier(uint256 x, uint256 y) public pure returns(uint256) {
        require(validCoordinate(x, y));
        
        return (y << 17) + x;
    }
    
    /// @dev Turn a single uint representation of a coordinate into its x and y parts.
    /// @param identifier The uint representation of a coordinate.
    function identifierToCoordinate(uint256 identifier) public pure returns(uint24 x, uint24 y) {
        require(validIdentifier(identifier));
    
        y = uint24(identifier >> 17);
        x = uint24(identifier - (y << 17));
    }
    
    /// @dev Test whether the coordinate is valid.
    /// @param x The x-part of the coordinate to test.
    /// @param y The y-part of the coordinate to test.
    function validCoordinate(uint256 x, uint256 y) public pure returns(bool) {
        return x < 131072 && y < 131072; // 2^17
    }
    
    /// @dev Test whether an identifier is valid.
    /// @param identifier The identifier to test.
    function validIdentifier(uint256 identifier) public pure returns(bool) {
        return identifier < 17179869184; // 2^17 * 2^17
    }
    
    /// @dev Assigns ownership of a specific plot to an address.
    function _transfer(address _from, address _to, uint256 _tokenId) internal {
        // The number of plots is capped at 2^17 * 2^17, so this cannot
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
}
