pragma solidity ^0.4.18;

import "../ERC721.sol";

/// @title The internal clock auction functionality.
/// Inspired by CryptoKitties' clock auction
contract ClockAuctionBase {

    // Address of the ERC721 contract this auction is linked to.
    ERC721 public deedContract;

    // Fee per successful auction in 1/1000th of a percentage.
    uint256 public fee;
    
    // Total amount of ether yet to be paid to auction beneficiaries.
    uint256 public outstandingEther = 0 ether;
    
    // Amount of ether yet to be paid per beneficiary.
    mapping (address => uint256) public addressToEtherOwed;
    
    /// @dev Represents a deed auction.
    /// Care has been taken to ensure the auction fits in
    /// two 256-bit words.
    struct Auction {
        address seller;
        uint128 startPrice;
        uint128 endPrice;
        uint64 duration;
        uint64 startedAt;
    }

    mapping (uint256 => Auction) identifierToAuction;
    
    // Events
    event AuctionCreated(address indexed seller, uint256 indexed deedId, uint256 startPrice, uint256 endPrice, uint256 duration);
    event AuctionSuccessful(address indexed buyer, uint256 indexed deedId, uint256 totalPrice);
    event AuctionCancelled(uint256 indexed deedId);
    
    /// @dev Modifier to check whether the value can be stored in a 64 bit uint.
    modifier fitsIn64Bits(uint256 _value) {
        require (_value == uint256(uint64(_value)));
        _;
    }
    
    /// @dev Modifier to check whether the value can be stored in a 128 bit uint.
    modifier fitsIn128Bits(uint256 _value) {
        require (_value == uint256(uint128(_value)));
        _;
    }
    
    function ClockAuctionBase(address _deedContractAddress, uint256 _fee) public {
        deedContract = ERC721(_deedContractAddress);
        
        // Contract must indicate support for ERC721 through its interface signature.
        require(deedContract.supportsInterface(0xda671b9b));
        
        // Fee must be between 0 and 100%.
        require(0 <= _fee && _fee <= 100000);
        fee = _fee;
    }
    
    /// @dev Checks whether the given auction is active.
    /// @param auction The auction to check for activity.
    function _activeAuction(Auction storage auction) internal view returns (bool) {
        return auction.startedAt > 0;
    }
    
    /// @dev Put the deed into escrow, thereby taking ownership of it.
    /// @param _deedId The identifier of the deed to place into escrow.
    function _escrow(uint256 _deedId) internal {
        // Throws if the transfer fails
        deedContract.takeOwnership(_deedId);
    }
    
    /// @dev Create the auction.
    /// @param _deedId The identifier of the deed to create the auction for.
    /// @param auction The auction to create.
    function _createAuction(uint256 _deedId, Auction auction) internal {
        // Add the auction to the auction mapping.
        identifierToAuction[_deedId] = auction;
        
        // Trigger auction created event.
        AuctionCreated(auction.seller, _deedId, auction.startPrice, auction.endPrice, auction.duration);
    }
    
    /// @dev Bid on an auction.
    /// @param _buyer The address of the buyer.
    /// @param _value The value sent by the sender (in ether).
    /// @param _deedId The identifier of the deed to bid on.
    function _bid(address _buyer, uint256 _value, uint256 _deedId) internal {
        Auction storage auction = identifierToAuction[_deedId];
        
        // The auction must be active.
        require(_activeAuction(auction));
        
        // Calculate the auction's current price.
        uint256 price = _currentPrice(auction);
        
        // Make sure enough funds were sent.
        require(_value >= price);
        
        address seller = auction.seller;
    
        if (price > 0) {
            uint256 totalFee = _calculateFee(price);
            uint256 proceeds = price - totalFee;
            
            // Assign the proceeds to the seller.
            // We do not send the proceeds directly, as to prevent
            // malicious sellers from denying auctions (and burning
            // the buyer's gas).
            _assignProceeds(seller, proceeds);
        }
        
        AuctionSuccessful(_buyer, _deedId, price);
        
        // The bid was won!
        _winBid(seller, _buyer, _deedId, price);
        
        // Remove the auction (we do this at the end, as
        // winBid might require some additional information
        // that will be removed when _removeAuction is
        // called. As we do not transfer funds here, we do
        // not have to worry about re-entry attacks.
        _removeAuction(_deedId);
    }

    /// @dev Perform the bid win logic (in this case: transfer the deed).
    /// @param _seller The address of the seller.
    /// @param _winner The address of the winner.
    /// @param _deedId The identifier of the deed.
    /// @param _price The price the auction was bought at.
    function _winBid(address _seller, address _winner, uint256 _deedId, uint256 _price) internal {
        _transfer(_winner, _deedId);
    }
    
    /// @dev Cancel an auction.
    /// @param _deedId The identifier of the deed for which the auction should be cancelled.
    /// @param auction The auction to cancel.
    function _cancelAuction(uint256 _deedId, Auction auction) internal {
        // Remove the auction
        _removeAuction(_deedId);
        
        // Transfer the deed back to the seller
        _transfer(auction.seller, _deedId);
        
        // Trigger auction cancelled event.
        AuctionCancelled(_deedId);
    }
    
    /// @dev Remove an auction.
    /// @param _deedId The identifier of the deed for which the auction should be removed.
    function _removeAuction(uint256 _deedId) internal {
        delete identifierToAuction[_deedId];
    }
    
    /// @dev Transfer a deed owned by this contract to another address.
    /// @param _to The address to transfer the deed to.
    /// @param _deedId The identifier of the deed.
    function _transfer(address _to, uint256 _deedId) internal {
        // Throws if the transfer fails
        deedContract.transfer(_to, _deedId);
    }
    
    /// @dev Assign proceeds to an address.
    /// @param _to The address to assign proceeds to.
    /// @param _value The proceeds to assign.
    function _assignProceeds(address _to, uint256 _value) internal {
        outstandingEther += _value;
        addressToEtherOwed[_to] += _value;
    }
    
    /// @dev Calculate the current price of an auction.
    function _currentPrice(Auction storage _auction) internal view returns (uint256) {
        require(now >= _auction.startedAt);
        
        uint256 secondsPassed = now - _auction.startedAt;
        
        if (secondsPassed >= _auction.duration) {
            return _auction.endPrice;
        } else {
            // Negative if the end price is higher than the start price!
            int256 totalPriceChange = int256(_auction.endPrice) - int256(_auction.startPrice);
            
            // Calculate the current price based on the total change over the entire
            // auction duration, and the amount of time passed since the start of the
            // auction.
            int256 currentPriceChange = totalPriceChange * int256(secondsPassed) / int256(_auction.duration);
            
            // Calculate the final price. Note this once again
            // is representable by a uint256, as the price can
            // never be negative.
            int256 price = int256(_auction.startPrice) + currentPriceChange;
            
            // This never throws.
            assert(price >= 0);
            
            return uint256(price);
        }
    }
    
    /// @dev Calculate the fee for a given price.
    /// @param _price The price to calculate the fee for.
    function _calculateFee(uint256 _price) internal view returns (uint256) {
        // _price is guaranteed to fit in a uint128 due to the createAuction entry
        // modifiers, so this cannot overflow.
        return _price * fee / 100000;
    }
}
