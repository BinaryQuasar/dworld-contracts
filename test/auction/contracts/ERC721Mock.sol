// Adapted from: https://github.com/axiomzen/cryptokitties-bounty/blob/master/test/contracts/NonFungibleMock.sol
pragma solidity ^0.4.18;

import "./../../../contracts/ERC721Draft.sol";

/// @title NonFungibleMock
/// @dev Mock implementation of NonFungible, aiming for simplicity.
contract ERC721Mock is ERC721 {

    function() public payable {}

    function supportsInterface(bytes4 _interfaceID) external pure returns (bool) {
        return _interfaceID == INTERFACE_SIGNATURE_ERC721;
    }

    struct MockNFT {
        uint256 id;
    }

    // Global list of all NFTs
    MockNFT[] tokens;
    // Tracks ownership of each token
    mapping (uint => address) identifierToOwner;
    // Tracks allowances for proxy ownership of each token
    mapping (uint => address) allowances;

    function implementsERC721() public pure returns (bool)
    {
        return true;
    }

    function _owns(address _claimant, uint256 _tokenId) internal view returns (bool) {
        return identifierToOwner[_tokenId] == _claimant;
    }

    function _approvedFor(address _claimant, uint256 _tokenId) internal view returns (bool) {
        return allowances[_tokenId] == _claimant;
    }

    /// @dev creates a new token and assigns ownership to the sender
    function createToken() public returns (uint) {
        uint256 id = tokens.length + 1;
        tokens.push(MockNFT(id));
        identifierToOwner[id] = msg.sender;
    }

    function totalSupply() public view returns (uint) {
        return tokens.length;
    }

    function balanceOf(address _owner) public view returns (uint) {
        uint256 balance = 0;
        for (uint256 i = 0; i < totalSupply(); i++) {
            if (identifierToOwner[tokens[i].id] == _owner) {
                balance++;
            }
        }
        return balance;
    }

    function ownerOf(uint256 _tokenId) external view returns (address owner) {
        return identifierToOwner[_tokenId];
    }

    function transfer(address _to, uint256 _tokenId) external {
        require(_owns(msg.sender, _tokenId));
        // NOTE: This implementation does not clear approvals on transfer for simplicity
        // A complete implementation should do this.
        identifierToOwner[_tokenId] = _to;
    }

    function approve(address _to, uint256 _tokenId) external {
        require(_owns(msg.sender, _tokenId));
        allowances[_tokenId] = _to;
    }

    function takeOwnership(uint256 _tokenId) external {
        require(_approvedFor(msg.sender, _tokenId));
        // NOTE: This implementation does not clear approvals on transfer for simplicity
        // A complete implementation should do this.
        identifierToOwner[_tokenId] = msg.sender;
    }
}