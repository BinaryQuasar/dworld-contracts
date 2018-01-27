// Adapted from: https://github.com/axiomzen/cryptokitties-bounty/blob/master/test/contracts/NonFungibleMock.sol
pragma solidity ^0.4.18;

import "./../../../contracts/ERC721.sol";

/// @title DeedMock
/// @dev Mock implementation of Deed, aiming for simplicity.
contract ERC721Mock is ERC721 {

    function() public payable {}

    /// @dev ERC-165 (draft) interface signature for ERC721
    bytes4 internal constant INTERFACE_SIGNATURE_ERC721 = // 0xda671b9b
        bytes4(keccak256('ownerOf(uint256)')) ^
        bytes4(keccak256('countOfDeeds()')) ^
        bytes4(keccak256('countOfDeedsByOwner(address)')) ^
        bytes4(keccak256('deedOfOwnerByIndex(address,uint256)')) ^
        bytes4(keccak256('approve(address,uint256)')) ^
        bytes4(keccak256('takeOwnership(uint256)'));
    
    function supportsInterface(bytes4 _interfaceID) external pure returns (bool) {
        return _interfaceID == INTERFACE_SIGNATURE_ERC721;
    }

    struct MockDeed {
        uint256 id;
    }

    // Global list of all deeds
    MockDeed[] deeds;
    // Tracks ownership of each deed
    mapping (uint => address) identifierToOwner;
    // Tracks allowances for proxy ownership of each deed
    mapping (uint => address) allowances;

    function implementsERC721() public pure returns (bool) {
        return true;
    }

    function _owns(address _claimant, uint256 _deedId) internal view returns (bool) {
        return identifierToOwner[_deedId] == _claimant;
    }

    function _approvedFor(address _claimant, uint256 _deedId) internal view returns (bool) {
        return allowances[_deedId] == _claimant;
    }

    /// @dev creates a new deed and assigns ownership to the sender
    function createDeed() public returns (uint) {
        uint256 id = deeds.length + 1;
        deeds.push(MockDeed(id));
        identifierToOwner[id] = msg.sender;
    }

    function countOfDeeds() public view returns (uint) {
        return deeds.length;
    }

    function countOfDeedsByOwner(address _owner) public view returns (uint) {
        uint256 balance = 0;
        for (uint256 i = 0; i < countOfDeeds(); i++) {
            if (identifierToOwner[deeds[i].id] == _owner) {
                balance++;
            }
        }
        return balance;
    }

    function ownerOf(uint256 _deedId) external view returns (address owner) {
        return identifierToOwner[_deedId];
    }
    
    function deedOfOwnerByIndex(address _owner, uint256 _index) external view returns (uint256) {
        // The index should be valid.
        require(_index < countOfDeedsByOwner(_owner));

        // Loop through all plots, accounting the number of plots of the owner we've seen.
        uint256 seen = 0;
        uint256 totalDeeds = countOfDeeds();
        
        for (uint256 deedNumber = 0; deedNumber < totalDeeds; deedNumber++) {
            MockDeed storage deed = deeds[deedNumber];
            if (identifierToOwner[deed.id] == _owner) {
                if (seen == _index) {
                    return deed.id;
                }
                
                seen++;
            }
        }
    }

    function transfer(address _to, uint256 _deedId) external {
        require(_owns(msg.sender, _deedId));
        // NOTE: This implementation does not clear approvals on transfer for simplicity
        // A complete implementation should do this.
        identifierToOwner[_deedId] = _to;
    }

    function approve(address _to, uint256 _deedId) external {
        require(_owns(msg.sender, _deedId));
        allowances[_deedId] = _to;
    }

    function takeOwnership(uint256 _deedId) external {
        require(_approvedFor(msg.sender, _deedId));
        // NOTE: This implementation does not clear approvals on transfer for simplicity
        // A complete implementation should do this.
        identifierToOwner[_deedId] = msg.sender;
    }
}