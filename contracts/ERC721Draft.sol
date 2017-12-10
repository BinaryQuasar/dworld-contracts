pragma solidity ^0.4.18;

/// @title Interface for contracts conforming to ERC-721: Non-Fungible Tokens
contract ERC721 {
    // Interface signature for ERC-165
    bytes4 constant INTERFACE_SIGNATURE_ERC721 = // 0xa9059cbb
        bytes4(keccak256('totalSupply()')) ^
        bytes4(keccak256('balanceOf(address)')) ^
        bytes4(keccak256('ownerOf(uint256)')) ^
        bytes4(keccak256('approve(address,uint256)')) ^
        bytes4(keccak256('takeOwnership(uint256)')) ^
        bytes4(keccak256('transfer(address,uint256)'));

    // Required methods
    function totalSupply() public view returns (uint256 supply);
    function balanceOf(address owner) public view returns (uint256 balance);
    function ownerOf(uint256 tokenId) external view returns (address owner);
    function approve(address to, uint256 tokenId) external;
    function takeOwnership(uint256 tokenId) external;
    function transfer(address to, uint256 tokenId) external;

    // Events
    event Transfer(address indexed from, address indexed to, uint256 tokenId);
    event Approval(address indexed owner, address indexed approved, uint256 tokenId);

    // Optional
    // function name() external view returns (string _name);
    // function symbol() external view returns (string _symbol);
    // function tokensOfOwner(address _owner) external view returns (uint256[] tokenIds);
    // function tokenMetadata(uint _tokenId) external view returns (string _infoUrl);

    // ERC-165 Compatibility (https://github.com/ethereum/EIPs/issues/165)
    // function supportsInterface(bytes4 _interfaceID) external view returns (bool);
}
