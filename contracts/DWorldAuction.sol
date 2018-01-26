pragma solidity ^0.4.18;

import "./DWorldMinting.sol";
import "./auction/SaleAuction.sol";
import "./auction/RentAuction.sol";

/// @dev Implements DWorld auction functionality.
contract DWorldAuction is DWorldMinting {
    SaleAuction public saleAuctionContract;
    RentAuction public rentAuctionContract;
    
    /// @notice set the contract address of the sale auction.
    /// @param _address The address of the sale auction.
    function setSaleAuctionContractAddress(address _address) external onlyOwner {
        SaleAuction _contract = SaleAuction(_address);
    
        require(_contract.isSaleAuction());
        
        saleAuctionContract = _contract;
    }
    
    /// @notice Set the contract address of the rent auction.
    /// @param _address The address of the rent auction.
    function setRentAuctionContractAddress(address _address) external onlyOwner {
        RentAuction _contract = RentAuction(_address);
    
        require(_contract.isRentAuction());
        
        rentAuctionContract = _contract;
    }
    
    /// @notice Create a sale auction.
    /// @param _tokenId The identifier of the token to create a sale auction for.
    /// @param _startPrice The starting price of the sale auction.
    /// @param _endPrice The ending price of the sale auction.
    /// @param _duration The duration in seconds of the dynamic pricing part of the sale auction.
    function createSaleAuction(uint256 _tokenId, uint256 _startPrice, uint256 _endPrice, uint256 _duration)
        external
        whenNotPaused
    {
        require(_owns(msg.sender, _tokenId));
        
        // Prevent creating a sale auction if no sale auction contract is configured.
        require(address(saleAuctionContract) != address(0));
    
        // Approve the token for transferring to the sale auction.
        _approve(msg.sender, address(saleAuctionContract), _tokenId);
    
        // Auction contract checks input values (throws if invalid) and places the token into escrow.
        saleAuctionContract.createAuction(_tokenId, _startPrice, _endPrice, _duration);
    }
    
    /// @notice Create a rent auction.
    /// @param _tokenId The identifier of the token to create a rent auction for.
    /// @param _startPrice The starting price of the rent auction.
    /// @param _endPrice The ending price of the rent auction.
    /// @param _duration The duration in seconds of the dynamic pricing part of the rent auction.
    /// @param _rentPeriod The rent period in seconds being auctioned.
    function createRentAuction(uint256 _tokenId, uint256 _startPrice, uint256 _endPrice, uint256 _duration, uint256 _rentPeriod)
        external
        whenNotPaused
    {
        require(_owns(msg.sender, _tokenId));
        
        // Prevent creating a rent auction if no rent auction contract is configured.
        require(address(rentAuctionContract) != address(0));
        
        // Approve the token for transferring to the rent auction.
        _approve(msg.sender, address(rentAuctionContract), _tokenId);
        
        // Throws if the auction is invalid (e.g. token is already rented out),
        // and places the token into escrow.
        rentAuctionContract.createAuction(_tokenId, _startPrice, _endPrice, _duration, _rentPeriod);
    }
    
    /// @notice Allow the CFO to capture the free balance available
    /// in the auction contracts.
    function withdrawFreeAuctionBalances() external onlyCFO {
        saleAuctionContract.withdrawFreeBalance();
        rentAuctionContract.withdrawFreeBalance();
    }
    
    /// @notice Allow withdrawing balances from the auction contracts
    /// in a single step.
    function withdrawAuctionBalances() external {
        // Withdraw from the sale contract if the sender is owed Ether.
        if (saleAuctionContract.addressToEtherOwed(msg.sender) > 0) {
            saleAuctionContract.withdrawAuctionBalance(msg.sender);
        }
        
        // Withdraw from the rent contract if the sender is owed Ether.
        if (rentAuctionContract.addressToEtherOwed(msg.sender) > 0) {
            rentAuctionContract.withdrawAuctionBalance(msg.sender);
        }
    }
    
    /// @dev This contract is only payable by the auction contracts.
    function() public payable {
        require(
            msg.sender == address(saleAuctionContract) ||
            msg.sender == address(rentAuctionContract)
        );
    }
}
