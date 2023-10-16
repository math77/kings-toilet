// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;


interface IDuelistDropFunds {

  error WithdrawNotAllowed();
  error YouArePoorSorry();

  function initialize(
    address kingAddress,
    address duelistAddress
  ) external;

  function withdrawFunds() external;
}
