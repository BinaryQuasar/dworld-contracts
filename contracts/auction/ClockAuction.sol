pragma solidity ^0.4.18;

import "zeppelin-solidity/contracts/lifecycle/Pausable.sol";
import "./ClockAuctionBase.sol";

contract ClockAuction is ClockAuctionBase, Pausable {
    function ClockAuction(address _deedContractAddress, uint256 _fee) 
        ClockAuctionBase(_deedContractAddress, _fee)
        public
    {}
    
    /// @notice Update the auction fee.
    /// @param _fee The new fee.
    function setFee(uint256 _fee) external onlyOwner {
        require(0 <= _fee && _fee <= 100000);
    
        fee = _fee;
    }
    
    /// @notice Get the auction for the given deed.
    /// @param _deedId The identifier of the deed to get the auction for.
    /// @dev Throws if there is no auction for the given deed.
    function getAuction(uint256 _deedId) external view returns (
            address seller,
            uint256 startPrice,
            uint256 endPrice,
            uint256 duration,
            uint256 startedAt
        )
    {
        Auction storage auction = identifierToAuction[_deedId];
        
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

    /// @notice Create an auction for a given deed.
    /// Must previously have been given approval to take ownership of the deed.
    /// @param _deedId The identifier of the deed to create an auction for.
    /// @param _startPrice The starting price of the auction.
    /// @param _endPrice The ending price of the auction.
    /// @param _duration The duration in seconds of the dynamic pricing part of the auction.
    function createAuction(uint256 _deedId, uint256 _startPrice, uint256 _endPrice, uint256 _duration)
        public
        fitsIn128Bits(_startPrice)
        fitsIn128Bits(_endPrice)
        fitsIn64Bits(_duration)
        whenNotPaused
    {
        // Get the owner of the deed to be auctioned
        address deedOwner = deedContract.ownerOf(_deedId);
    
        // Caller must either be the deed contract or the owner of the deed
        // to prevent abuse.
        require(
            msg.sender == address(deedContract) ||
            msg.sender == deedOwner
        );
    
        // The duration of the auction must be at least 60 seconds.
        require(_duration >= 60);
    
        // Throws if placing the deed in escrow fails (the contract requires
        // transfer approval prior to creating the auction).
        _escrow(_deedId);
        
        // Auction struct
        Auction memory auction = Auction(
            deedOwner,
            uint128(_startPrice),
            uint128(_endPrice),
            uint64(_duration),
            uint64(now)
        );
        
        _createAuction(_deedId, auction);
    }
    
    /// @notice Cancel an auction
    /// @param _deedId The identifier of the deed to cancel the auction for.
    function cancelAuction(uint256 _deedId) external whenNotPaused {
        Auction storage auction = identifierToAuction[_deedId];
        
        // The auction must be active.
        require(_activeAuction(auction));
        
        // The auction can only be cancelled by the seller
        require(msg.sender == auction.seller);
        
        _cancelAuction(_deedId, auction);
    }
    
    /// @notice Bid on an auction.
    /// @param _deedId The identifier of the deed to bid on.
    function bid(uint256 _deedId) external payable whenNotPaused {
        // Throws if the bid does not succeed.
        _bid(msg.sender, msg.value, _deedId);
    }
    
    /// @dev Returns the current price of an auction.
    /// @param _deedId The identifier of the deed to get the currency price for.
    function getCurrentPrice(uint256 _deedId) external view returns (uint256) {
        Auction storage auction = identifierToAuction[_deedId];
        
        // The auction must be active.
        require(_activeAuction(auction));
        
        return _currentPrice(auction);
    }
    
    /// @notice Withdraw ether owed to a beneficiary.
    /// @param beneficiary The address to withdraw the auction balance for.
    function withdrawAuctionBalance(address beneficiary) external {
        // The sender must either be the beneficiary or the core deed contract.
        require(
            msg.sender == beneficiary ||
            msg.sender == address(deedContract)
        );
        
        uint256 etherOwed = addressToEtherOwed[beneficiary];
        
        // Ensure ether is owed to the beneficiary.
        require(etherOwed > 0);
         
        // Set ether owed to 0   
        delete addressToEtherOwed[beneficiary];
        
        // Subtract from total outstanding balance. etherOwed is guaranteed
        // to be less than or equal to outstandingEther, so this cannot
        // underflow.
        outstandingEther -= etherOwed;
        
        // Transfer ether owed to the beneficiary (not susceptible to re-entry
        // attack, as the ether owed is set to 0 before the transfer takes place).
        beneficiary.transfer(etherOwed);
    }
    
    /// @notice Withdraw (unowed) contract balance.
    function withdrawFreeBalance() external {
        // Calculate the free (unowed) balance. This never underflows, as
        // outstandingEther is guaranteed to be less than or equal to the
        // contract balance.
        uint256 freeBalance = this.balance - outstandingEther;
        
        address deedContractAddress = address(deedContract);

        require(
            msg.sender == owner ||
            msg.sender == deedContractAddress
        );
        
        deedContractAddress.transfer(freeBalance);
    }
}
