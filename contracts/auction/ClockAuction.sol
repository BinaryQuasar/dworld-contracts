pragma solidity ^0.4.18;

import "zeppelin-solidity/contracts/lifecycle/Pausable.sol";
import "../ERC721Draft.sol";
import "./ClockAuctionBase.sol";

contract ClockAuction is ClockAuctionBase, Pausable {
    function ClockAuction(address _tokenContractAddress, uint256 _fee) 
        ClockAuctionBase(_tokenContractAddress, _fee)
        public
    {}
    
    /// @notice Update the auction fee.
    /// @param _fee The new fee.
    function setFee(uint256 _fee) external onlyOwner {
        require(0 <= _fee && _fee <= 100000);
    
        fee = _fee;
    }
    
    /// @notice Get the auction for the given token.
    /// @param _tokenId The identifier of the token to get the auction for.
    /// @dev Throws if there is no auction for the given token.
    function getAuction(uint256 _tokenId) external view returns (
            address seller,
            uint256 startPrice,
            uint256 endPrice,
            uint256 duration,
            uint256 startedAt
        )
    {
        Auction storage auction = identifierToAuction[_tokenId];
        
        // The auction must be active
        require(_activeAuction(auction));
        
        return (
            auction.seller,
            auction.startPrice,
            auction.endPrice,
            auction.duration,
            auction.startedAt
        );
    }

    /// @notice Create an auction for a given token.
    /// Must previously have been given approval to take ownership of the token.
    /// @param _tokenId The identifier of the token to create an auction for.
    /// @param _startPrice The starting price of the auction.
    /// @param _endPrice The ending price of the auction.
    /// @param _duration The duration of the dynamic pricing part of the auction.
    function createAuction(uint256 _tokenId, uint256 _startPrice, uint256 _endPrice, uint256 _duration)
        public
        fitsIn128Bits(_startPrice)
        fitsIn128Bits(_endPrice)
        fitsIn64Bits(_duration)
        whenNotPaused
    {
        // Get the owner of the token to be auctioned
        address tokenOwner = tokenContract.ownerOf(_tokenId);
    
        // Caller must either be the token contract or the owner of the token
        // to prevent abuse.
        require(
            msg.sender == address(tokenContract)
            || msg.sender == tokenOwner
        );
    
        // The duration of the auction must be at least 60 seconds.
        require(_duration >= 60);
    
        // Throws if placing the token in escrow fails (the contract requires
        // transfer approval prior to creating the auction).
        _escrow(_tokenId);
        
        // Auction struct
        Auction memory auction = Auction(
            tokenOwner,
            uint128(_startPrice),
            uint128(_endPrice),
            uint64(_duration),
            uint64(now)
        );
        
        _createAuction(_tokenId, auction);
    }
    
    /// @notice Cancel an auction
    /// @param _tokenId The identifier of the token to cancel the auction for.
    function cancelAuction(uint256 _tokenId) external whenNotPaused {
        Auction storage auction = identifierToAuction[_tokenId];
        
        // The auction must be active.
        require(_activeAuction(auction));
        
        // The auction can only be cancelled by the seller
        require(msg.sender == auction.seller);
        
        _cancelAuction(_tokenId, auction);
    }
    
    /// @notice Bid on an auction.
    /// @param _tokenId The identifier of the token to bid on.
    function bid(uint256 _tokenId) external payable whenNotPaused {
        // Throws if the bid does not succeed.
        _bid(msg.sender, msg.value, _tokenId);
        
        // The bid was won!
        _winBid(msg.sender, _tokenId);
    }
    
    /// @dev Perform the bid win logic (in this case: transfer the token).
    /// @param _winner The address of the winner.
    /// @param _tokenId The identifier of the token.
    function _winBid(address _winner, uint256 _tokenId) internal {
        _transfer(_winner, _tokenId);
    }
    
    /// @dev Returns the current price of an auction.
    /// @param _tokenId The identifier of the token to get the currency price for.
    function getCurrentPrice(uint256 _tokenId) external view returns (uint256) {
        Auction storage auction = identifierToAuction[_tokenId];
        
        // The auction must be active.
        require(_activeAuction(auction));
        
        return _currentPrice(auction);
    }
    
    /// @notice Withdraw ether owed.
    function withdrawAuctionBalance() external {
        uint256 etherOwed = addressToEtherOwed[msg.sender];
        
        // Ensure ether is owed to the sender
        require(etherOwed > 0);
         
        // Set ether owed to 0   
        addressToEtherOwed[msg.sender] = 0;
        
        // Subtract from total outstanding balance. etherOwed is guaranteed
        // to be less than or equal to outstandingEther, so this cannot
        // underflow.
        outstandingEther -= etherOwed;
        
        // Transfer ether owed to sender (not susceptible to re-entry attack, as
        // the ether owed is set to 0 before the transfer takes place).
        msg.sender.transfer(etherOwed);
    }
    
    /// @notice Withdraw (unowed) contract balance.
    function withdrawFreeBalance() external {
        // Calculate the free (unowed) balance. This never underflows, as
        // outstandingEther is guaranteed to be less than freeBalance.        
        uint256 freeBalance = this.balance - outstandingEther;
        
        address tokenContractAddress = address(tokenContract);

        require(
            msg.sender == owner ||
            msg.sender == tokenContractAddress
        );
        
        tokenContractAddress.transfer(freeBalance);
    }
}
