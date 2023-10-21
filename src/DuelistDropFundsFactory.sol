// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;


import {Clones} from "openzeppelin-contracts/contracts/proxy/Clones.sol";
import {IDuelistDropFunds} from "./interfaces/IDuelistDropFunds.sol";


contract DuelistDropFundsFactory {
  using Clones for address;

  address public immutable implementation;

  event DuelistDropFundsCreated();
  
  constructor(address _implementation) {
    implementation = _implementation;
  }

  function deployDuelistDropFunds(
    uint256 _reignId,
    uint256 _duelId
  ) external returns (address) {
    address _dropFunds = implementation.clone();

    IDuelistDropFunds(_dropFunds).initialize(
      _reignId,
      _duelId
    );

    emit DuelistDropFundsCreated();

    return _dropFunds;
  }
}
