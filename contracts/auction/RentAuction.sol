pragma solidity ^0.4.18;

import "../DWorldRenting.sol";
import "./ClockAuction.sol";

contract RentAuction is ClockAuction {
    function RentAuction(address _tokenContractAddress, uint256 _fee) ClockAuction(_tokenContractAddress, _fee) public {}
    
    /// @dev Allows other contracts to check whether this is the expected contract.
    bool public isRentAuction = true;
    
    mapping (uint256 => uint256) public identifierToRentPeriod;
    
    /// @notice Create an auction for a given token.
    /// Must previously have been given approval to take ownership of the token.
    /// @param _tokenId The identifier of the token to create an auction for.
    /// @param _startPrice The starting price of the auction.
    /// @param _endPrice The ending price of the auction.
    /// @param _duration The duration in seconds of the dynamic pricing part of the auction.
    /// @param _rentPeriod The rent period in seconds being auctioned.
    function createAuction(
        uint256 _tokenId,
        uint256 _startPrice,
        uint256 _endPrice,
        uint256 _duration,
        uint256 _rentPeriod
    )
        external
    {
        // Require the rent period to be at least one hour.
        require(_rentPeriod >= 3600);
        
        // Require there to be no active renter.
        DWorldRenting dWorldRentingContract = DWorldRenting(tokenContract);
        var (renter,) = dWorldRentingContract.renterOf(_tokenId);
        require(renter == address(0));
    
        // Set the rent period.
        identifierToRentPeriod[_tokenId] = _rentPeriod;
    
        // Throws (reverts) if creating the auction fails.
        createAuction(_tokenId, _startPrice, _endPrice, _duration);
    }
    
    /// @dev Perform the bid win logic (in this case: give renter status to the winner).
    /// @param _seller The address of the seller.
    /// @param _winner The address of the winner.
    /// @param _tokenId The identifier of the token.
    /// @param _price The price the auction was bought at.
    function _winBid(address _seller, address _winner, uint256 _tokenId, uint256 _price) internal {
        DWorldRenting dWorldRentingContract = DWorldRenting(tokenContract);
    
        // Rent the token out to the winner
        dWorldRentingContract.rentOut(_winner, identifierToRentPeriod[_tokenId], _tokenId);
        
        // Transfer the token back to the seller
        _transfer(_seller, _tokenId);
    }
    
    /// @dev Remove an auction.
    /// @param _tokenId The identifier of the token for which the auction should be removed.
    function _removeAuction(uint256 _tokenId) internal {
        delete identifierToAuction[_tokenId];
        delete identifierToRentPeriod[_tokenId];
    }
}
