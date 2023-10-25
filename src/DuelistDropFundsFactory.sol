// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Clones} from "openzeppelin-contracts/contracts/proxy/Clones.sol";
import {IDuelistDropFunds} from "./interfaces/IDuelistDropFunds.sol";


contract DuelistDropFundsFactory {
  using Clones for address;

  address public immutable implementation;
  address payable public immutable kingsToiletContract;

  event DuelistDropFundsCreated();
  
  constructor(address _implementation, address _kingsToiletContract) {
    implementation = _implementation;
    kingsToiletContract = payable(_kingsToiletContract);
  }

  function deployDuelistDropFunds(
    uint256 _reignId,
    uint256 _duelId
  ) external returns (address) {
    address _dropFunds = implementation.clone();

    IDuelistDropFunds(_dropFunds).initialize(
      _reignId,
      _duelId,
      kingsToiletContract
    );

    emit DuelistDropFundsCreated();

    return _dropFunds;
  }
}
