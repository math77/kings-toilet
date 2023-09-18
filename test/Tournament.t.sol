// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {StdStyle} from "forge-std/StdStyle.sol";
import {Tournament} from "../src/Tournament.sol";
import "forge-std/console.sol";

contract TournamentTest is Test {
  Tournament public tournament;

  /*
  function setUp() public {
    tournament = new Tournament();
        //counter.setNumber(0);
  }

  function test_Symbol() public {
    string memory result = tournament.symbolCollection();
    console.log(StdStyle.blue(result));
  }
  */
}
