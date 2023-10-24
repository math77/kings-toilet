// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;


import {Initializable} from "openzeppelin-contracts/contracts/proxy/utils/Initializable.sol";
import {ProtocolRewards} from "@zoralabs/protocol-rewards/src/ProtocolRewards.sol";

import {IDuelistDropFunds} from "./interfaces/IDuelistDropFunds.sol";
import {Tournament} from "./Tournament.sol";


contract DuelistDropFunds is Initializable, IDuelistDropFunds {

  ProtocolRewards public rewardsContract;
  Tournament public tournamentContract;

  uint256 public reignId;
  uint256 public duelId;

  receive() external payable {}
  fallback() external payable {}

  function initialize(uint256 _reignId, uint256 _duelId) external initializer {
    reignId = _reignId;
    duelId = _duelId;
    rewardsContract = ProtocolRewards(0x7777777F279eba3d3Ad8F4E708545291A6fDBA8B);
  }

  function withdrawFunds() external {
    uint256 amountAvailable = rewardsContract.balanceOf(address(this));

    if (amountAvailable == 0) {
      revert YouArePoorSorry();
    }

    address[] memory winners = tournamentContract.duelDetails(reignId, duelId).winners;
    address kingAddress = tournamentContract.reignDetails(reignId).kingAddress;

    rewardsContract.withdraw(address(this), amountAvailable);

    uint256 kingPayment = (address(this).balance / 100) * 10;
    uint256 prize = (address(this).balance - kingPayment) / winners.length;


    (bool success,) = kingAddress.call{value: kingPayment}("");
    if (!success) revert();

    for (uint256 i; i < winners.length; i++) {
      (bool success,) = winners[i].call{value: prize}("");
      if (!success) revert();
    }    
  }
}
