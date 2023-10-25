// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;


interface IDuelistDropFunds {

  error WithdrawNotAllowed();
  error YouArePoorSorry();

  function initialize(
    uint256 reignId,
    uint256 duelId,
    address payable kingsToiletContract
  ) external;

  function withdrawFunds() external;
}
