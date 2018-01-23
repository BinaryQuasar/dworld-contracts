pragma solidity ^0.4.18;

import "zeppelin-solidity/contracts/math/SafeMath.sol";
import "./DWorldAccessControl.sol";

/// @dev Defines base data structures for DWorld.
contract DWorldBase is DWorldAccessControl {
    using SafeMath for uint256;

    /// Plot data
    struct Plot {
        uint256 mintedTimestamp;
        string name;
        string description;
        string imageUrl;
        string infoUrl;
    }
    
    /// @dev All minted plots (array of plot identifiers). There are
    /// 2^16 * 2^16 possible plots (covering the entire world), thus
    /// 32 bits are required. This fits in a uint32. Storing
    /// the identifiers as uint32 instead of uint256 makes storage
    /// cheaper. (The impact of this in mappings is less noticeable,
    /// and using uint32 in the mappings below actually *increases*
    /// gas cost for minting).
    uint32[] public plots;
    
    mapping (uint256 => Plot) public identifierToPlot;
    mapping (uint256 => address) identifierToOwner;
    mapping (uint256 => address) identifierToApproved;
    mapping (address => uint256) ownershipTokenCount;
    
    /// @notice Get all minted plots.
    function getAllPlots() external view returns(uint32[]) {
        return plots;
    }
    
    /// @notice Get a plot by its identifier.
    function getPlot(uint256 identifier)
        external
        view
        returns (uint256, string, string, string, string)
    {
        Plot storage plot = identifierToPlot[identifier];
        return (plot.mintedTimestamp, plot.name, plot.description, plot.imageUrl, plot.infoUrl);
    }
    
    /// @dev Represent a 2D coordinate as a single uint.
    /// @param x The x-coordinate.
    /// @param y The y-coordinate.
    function coordinateToIdentifier(uint256 x, uint256 y) public pure returns(uint256) {
        require(validCoordinate(x, y));
        
        return (y << 16) + x;
    }
    
    /// @dev Turn a single uint representation of a coordinate into its x and y parts.
    /// @param identifier The uint representation of a coordinate.
    function identifierToCoordinate(uint256 identifier) public pure returns(uint256 x, uint256 y) {
        require(validIdentifier(identifier));
    
        y = identifier >> 16;
        x = identifier - (y << 16);
    }
    
    /// @dev Test whether the coordinate is valid.
    /// @param x The x-part of the coordinate to test.
    /// @param y The y-part of the coordinate to test.
    function validCoordinate(uint256 x, uint256 y) public pure returns(bool) {
        return x < 65536 && y < 65536; // 2^16
    }
    
    /// @dev Test whether an identifier is valid.
    /// @param identifier The identifier to test.
    function validIdentifier(uint256 identifier) public pure returns(bool) {
        return identifier < 4294967296; // 2^16 * 2^16
    }
}
