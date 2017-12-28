pragma solidity ^0.4.18;

import "./DWorldAccessControl.sol";

/// @dev Defines base data structures for DWorld.
contract DWorldBase is DWorldAccessControl {
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
}
