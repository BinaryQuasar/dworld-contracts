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
    
    /// @dev Event fired when a plot's data are changed.
    event Change(uint256 indexed tokenId, string name, string description, string imageUrl, string infoUrl);
    
    /// @notice Get all minted plots.
    function getAllPlots() external view returns(uint32[]) {
        return plots;
    }
    
    /// @notice Get a plot by its identifier. Alias for identifierToPlot with better Web3 compatibility..
    /// @param identifier The identifier of the plot to get.
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
    
    /// @dev Set a plot's data.
    /// @param identifier The identifier of the plot to set data for.
    function _setPlotData(uint256 identifier, string name, string description, string imageUrl, string infoUrl) internal {
        Plot storage plot = identifierToPlot[identifier];
        
        // Test strings for change before storing them. Uses dramatically
        // less gas if even just one of the parameters did not change.
        if (keccak256(plot.name) != keccak256(name)) {
            plot.name = name;
        }
        
        if (keccak256(plot.description) != keccak256(description)) {
            plot.description = description;
        }
        
        if (keccak256(plot.imageUrl) != keccak256(imageUrl)) {
            plot.imageUrl = imageUrl;
        }
        
        if (keccak256(plot.infoUrl) != keccak256(infoUrl)) {
            plot.infoUrl = infoUrl;
        }
    
        Change(identifier, name, description, imageUrl, infoUrl);
    }
}
