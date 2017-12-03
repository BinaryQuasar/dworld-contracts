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
    
    /// All minted plots (array of plot identifiers).
    uint256[] plots;
    
    /// There are 2^17 * 2^17 possible plots (covering the entire world), thus
    /// at least 34 bits are required .
    mapping (uint256 => Plot) public identifierToPlot;
    mapping (uint256 => address) identifierToOwner;
    mapping (uint256 => address) identifierToApproved;
    mapping (address => uint256) ownershipTokenCount;
    
    /// @dev Represent a 2D coordinate as a single uint.
    /// @param x The x-coordinate.
    /// @param y The y-coordinate.
    function coordinateToIdentifier(uint24 x, uint24 y) public pure returns(uint256) {
        uint40 _x = uint40(x);
        uint40 _y = uint40(y);
        return (_y << 17) + _x;
    }
    
    /// @dev Turn a single uint representation of a coordinate into its x and y parts.
    /// @param identifier The uint representation of a coordinate.
    function identifierToCoordinate(uint256 identifier) public pure returns(uint24 x, uint24 y) {
        y = uint24(identifier >> 17);
        x = uint24(identifier - (y << 17));
    }
    
    /// @dev Test whether an identifier is valid.
    /// @param identifier The identifier to test.
    function validIdentifier(uint256 identifier) public pure returns(bool) {
        return identifier < 17179869184;
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
