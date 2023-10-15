// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {ProtocolRewards} from "@zoralabs/protocol-rewards/src/ProtocolRewards.sol";

//
contract DuelistDropFunds {

  address private immutable KING_ADDRESS;
  address private immutable DUELIST_ADDRESS;


  ProtocolRewards public rewardsContract;


  error WithdrawNotAllowed();
  error YouArePoorSorry();

  receive() external payable {}
  fallback() external payable {}

  constructor() {}

  

  modifier isAllowed() { 
    if (msg.sender != KING_ADDRESS && msg.sender != DUELIST_ADDRESS) {
      revert WithdrawNotAllowed();
    }
    _; 
  }

  function withdrawFunds() external isAllowed {
    uint256 amountAvailable = rewardsContract.balanceOf(msg.sender);

    if (amountAvailable == 0) {
      revert YouArePoorSorry();
    }

    uint256 amountToWithdraw;
    if (msg.sender == KING_ADDRESS) {
      amountToWithdraw = (amountAvailable / 100 ) * 10;
    } else {
      amountToWithdraw = (amountAvailable / 100) * 90;
    }

    rewardsContract.withdraw(msg.sender, amountToWithdraw);    
  }
}
