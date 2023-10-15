// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;


import {Initializable} from "openzeppelin-contracts/contracts/proxy/utils/Initializable.sol";
import {ProtocolRewards} from "@zoralabs/protocol-rewards/src/ProtocolRewards.sol";

import {IDuelistDropFunds} from "./interfaces/IDuelistDropFunds.sol";

//
contract DuelistDropFunds is Initializable, IDuelistDropFunds {

  address public kingAddress;
  address public duelistAddress;


  ProtocolRewards public rewardsContract;

  receive() external payable {}
  fallback() external payable {}
  

  modifier isAllowed() { 
    if (msg.sender != kingAddress && msg.sender != duelistAddress) {
      revert WithdrawNotAllowed();
    }
    _; 
  }

  function initialize(address _kingAddress, address _duelistAddress) external initializer {
    kingAddress = _kingAddress;
    duelistAddress = _duelistAddress;
    rewardsContract = ProtocolRewards(0x7777777F279eba3d3Ad8F4E708545291A6fDBA8B);
  }

  function withdrawFunds() external isAllowed {
    uint256 amountAvailable = rewardsContract.balanceOf(msg.sender);

    if (amountAvailable == 0) {
      revert YouArePoorSorry();
    }

    uint256 amountToWithdraw;
    if (msg.sender == kingAddress) {
      amountToWithdraw = (amountAvailable / 100) * 10;
    } else {
      amountToWithdraw = (amountAvailable / 100) * 90;
    }

    rewardsContract.withdraw(msg.sender, amountToWithdraw);    
  }
}
