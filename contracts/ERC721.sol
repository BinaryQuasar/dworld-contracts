pragma solidity ^0.4.18;

/// @title Interface for contracts conforming to ERC-721: Deed Standard
/// @author William Entriken (https://phor.net), et al.
/// @dev Specification at https://github.com/ethereum/EIPs/pull/841 (DRAFT)
interface ERC721 {

    // COMPLIANCE WITH ERC-165 (DRAFT) /////////////////////////////////////////

    /// @dev ERC-165 (draft) interface signature for itself
    // bytes4 internal constant INTERFACE_SIGNATURE_ERC165 = // 0x01ffc9a7
    //     bytes4(keccak256('supportsInterface(bytes4)'));

    /// @dev ERC-165 (draft) interface signature for ERC721
    // bytes4 internal constant INTERFACE_SIGNATURE_ERC721 = // 0xda671b9b
    //     bytes4(keccak256('ownerOf(uint256)')) ^
    //     bytes4(keccak256('countOfDeeds()')) ^
    //     bytes4(keccak256('countOfDeedsByOwner(address)')) ^
    //     bytes4(keccak256('deedOfOwnerByIndex(address,uint256)')) ^
    //     bytes4(keccak256('approve(address,uint256)')) ^
    //     bytes4(keccak256('takeOwnership(uint256)'));

    /// @notice Query a contract to see if it supports a certain interface
    /// @dev Returns `true` the interface is supported and `false` otherwise,
    ///  returns `true` for INTERFACE_SIGNATURE_ERC165 and
    ///  INTERFACE_SIGNATURE_ERC721, see ERC-165 for other interface signatures.
    function supportsInterface(bytes4 _interfaceID) external pure returns (bool);

    // PUBLIC QUERY FUNCTIONS //////////////////////////////////////////////////

    /// @notice Find the owner of a deed
    /// @param _deedId The identifier for a deed we are inspecting
    /// @dev Deeds assigned to zero address are considered destroyed, and
    ///  queries about them do throw.
    /// @return The non-zero address of the owner of deed `_deedId`, or `throw`
    ///  if deed `_deedId` is not tracked by this contract
    function ownerOf(uint256 _deedId) external view returns (address _owner);

    /// @notice Count deeds tracked by this contract
    /// @return A count of the deeds tracked by this contract, where each one of
    ///  them has an assigned and queryable owner
    function countOfDeeds() public view returns (uint256 _count);

    /// @notice Count all deeds assigned to an owner
    /// @dev Throws if `_owner` is the zero address, representing destroyed deeds.
    /// @param _owner An address where we are interested in deeds owned by them
    /// @return The number of deeds owned by `_owner`, possibly zero
    function countOfDeedsByOwner(address _owner) public view returns (uint256 _count);

    /// @notice Enumerate deeds assigned to an owner
    /// @dev Throws if `_index` >= `countOfDeedsByOwner(_owner)` or if
    ///  `_owner` is the zero address, representing destroyed deeds.
    /// @param _owner An address where we are interested in deeds owned by them
    /// @param _index A counter between zero and `countOfDeedsByOwner(_owner)`,
    ///  inclusive
    /// @return The identifier for the `_index`th deed assigned to `_owner`,
    ///   (sort order not specified)
    function deedOfOwnerByIndex(address _owner, uint256 _index) external view returns (uint256 _deedId);

    // TRANSFER MECHANISM //////////////////////////////////////////////////////

    /// @dev This event emits when ownership of any deed changes by any
    ///  mechanism. This event emits when deeds are created (`from` == 0) and
    ///  destroyed (`to` == 0). Exception: during contract creation, any
    ///  transfers may occur without emitting `Transfer`.
    event Transfer(address indexed from, address indexed to, uint256 indexed deedId);

    /// @dev This event emits on any successful call to
    ///  `approve(address _spender, uint256 _deedId)`. Exception: does not emit
    ///  if an owner revokes approval (`_to` == 0x0) on a deed with no existing
    ///  approval.
    event Approval(address indexed owner, address indexed approved, uint256 indexed deedId);

    /// @notice Approve a new owner to take your deed, or revoke approval by
    ///  setting the zero address. You may `approve` any number of times while
    ///  the deed is assigned to you, only the most recent approval matters.
    /// @dev Throws if `msg.sender` does not own deed `_deedId` or if `_to` ==
    ///  `msg.sender`.
    /// @param _deedId The deed you are granting ownership of
    function approve(address _to, uint256 _deedId) external;

    /// @notice Become owner of a deed for which you are currently approved
    /// @dev Throws if `msg.sender` is not approved to become the owner of
    ///  `deedId` or if `msg.sender` currently owns `_deedId`.
    /// @param _deedId The deed that is being transferred
    function takeOwnership(uint256 _deedId) external;
    
    // SPEC EXTENSIONS /////////////////////////////////////////////////////////
    
    /// @notice Transfer a deed to a new owner.
    /// @dev Throws if `msg.sender` does not own deed `_deedId` or if
    ///  `_to` == 0x0.
    /// @param _to The address of the new owner.
    /// @param _deedId The deed you are transferring.
    function transfer(address _to, uint256 _deedId) external;
}
