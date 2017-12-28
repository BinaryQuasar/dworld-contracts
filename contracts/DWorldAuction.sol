pragma solidity ^0.4.18;

import "./DWorldMinting.sol";

/// @dev Implements DWorld auction functionality.
contract DWorldAuction is DWorldMinting {
    uint256 public outstandingEther = 0 ether;
    mapping (address => uint256) addressToEtherOwed;
    
    function withdrawAuctionBalance() external {
        uint256 etherOwed = addressToEtherOwed[msg.sender];
        
        // Ensure ether is owed to the sender
        require(etherOwed > 0);
         
        // Set ether owed to 0   
        addressToEtherOwed[msg.sender] = 0;
        
        // Subtract from outstanding balance. etherOwed is guaranteed
        // to be less than or equal to outstandingEther, so this cannot
        // underflow.
        outstandingEther -= etherOwed;
        
        // Transfer ether owed to sender (not susceptible to re-entry attack, as
        // the ether owed is set to 0 before the transfer takes place).
        msg.sender.transfer(etherOwed);
    }
}
