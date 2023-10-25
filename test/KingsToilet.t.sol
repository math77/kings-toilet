// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {StdStyle} from "forge-std/StdStyle.sol";
import {KingsToilet} from "../src/KingsToilet.sol";
import {KingsToiletPrizes} from "../src/KingsToiletPrizes.sol";
import {DuelistDropFundsFactory} from "../src/DuelistDropFundsFactory.sol";
import {DuelistDropFunds} from "../src/DuelistDropFunds.sol";
import {ZoraNFTCreatorV1} from "zora/src/ZoraNFTCreatorV1.sol";
import {ERC721Drop} from "zora/src/ERC721Drop.sol";

import {IKingsToilet} from "../src/interfaces/IKingsToilet.sol";

import "forge-std/console.sol";

contract KingsToiletTest is Test {
  KingsToilet public kingsToilet;
  KingsToiletPrizes public prizes;
  DuelistDropFunds public dropFunds;
  DuelistDropFundsFactory public dropFundsFactory;
  ZoraNFTCreatorV1 public zoraNFTCreatorV1;


  address duelist1 = address(1234);
  address duelist2 = address(5678);

  address king = address(9234);
  address user1 = address(4312);
  address user2 = address(1409);

  address[] duelists = [duelist1];

  event DuelistAdded(address indexed duelist);
  event DuelCreated(
    uint256 indexed duelId,
    uint256 indexed reignId
  );
  event SuccessorAdded(
    uint256 indexed reignId,
    address indexed successor
  );
  event DuelEntrySubmitted(
    address indexed duelist,
    ERC721Drop dropAddress,
    uint256 indexed duelId
  );
  event NewKingCrowned(
    uint256 indexed reignId,
    address indexed oldKing,
    address indexed newKing
  );

  event OpenEditionPriceUpdated();
  event MaxNumberDuelsUpdated();

  error NotTheKingError();
  error MaxNumberDuelsReachedError();
  error AddressCannotBeZeroError();
  error CannotCrownYourselfError();
  error DuelEntryDeadlineReachedError();
  error DuelFinishedError();
  error AlreadySubmittedError();
  error NotADuelistError();
  error Unauthorized();
  error NotTimeForNewKingError();
  error NotSuccessorError();

  receive() external payable {}

  function setUp() public {
    prizes = new KingsToiletPrizes();
    dropFunds = new DuelistDropFunds();
    zoraNFTCreatorV1 = ZoraNFTCreatorV1(0x489f8fFbd5f5eA8875c2EbC5CA9ED1214BD77F42);

    kingsToilet = new KingsToilet(
      prizes,
      zoraNFTCreatorV1
    );

    dropFundsFactory = new DuelistDropFundsFactory(address(dropFunds), address(kingsToilet));

    kingsToilet.setDropFundsFactoryAddress(dropFundsFactory);
    kingsToilet.setFirstKing(king);
    kingsToilet.setDuelists(duelists);
  }

  function testSetDuelists() public {
    vm.expectEmit();
    emit DuelistAdded(duelist1);

    kingsToilet.setDuelists(duelists);
  }

  function testCreateDuel() public {
    vm.startPrank(king);
    vm.expectEmit();
    emit DuelCreated(1, 1);
    kingsToilet.createDuel("Duel test", "The first duel of test.");
    vm.stopPrank();
  }

  function testCreateDuelNotTheKing() public {
    vm.startPrank(user1);
    vm.expectRevert(abi.encodeWithSelector(NotTheKingError.selector));
    kingsToilet.createDuel("Duel test", "Another duel");
    vm.stopPrank();
  }

  function testCreateDuelMaxDuelsReached() public {
    vm.startPrank(king);
    vm.expectEmit();
    emit DuelCreated(1, 1);
    kingsToilet.createDuel("Duel test", "The first duel of test.");

    vm.expectRevert(abi.encodeWithSelector(MaxNumberDuelsReachedError.selector));
    kingsToilet.createDuel("Duel test", "Another f*ck duel");
    vm.stopPrank();
  }

  function testAddSuccessor() public {
    vm.startPrank(king);
    vm.expectEmit();
    emit SuccessorAdded(1, user1);
    kingsToilet.addSuccessor(user1);
    vm.stopPrank();
  }

  function testAddSuccessorCannotBeZero() public {
    vm.startPrank(king);
    vm.expectRevert(abi.encodeWithSelector(AddressCannotBeZeroError.selector));
    kingsToilet.addSuccessor(address(0));
    vm.stopPrank();
  }

  function testAddSuccessorCannotCrownYourself() public {
    vm.startPrank(king);
    vm.expectRevert(abi.encodeWithSelector(CannotCrownYourselfError.selector));
    kingsToilet.addSuccessor(king);
    vm.stopPrank();
  }

  function testAddSuccessorNotTheKing() public {
    vm.expectRevert(abi.encodeWithSelector(NotTheKingError.selector));
    kingsToilet.addSuccessor(user1);
  }

  function testSubmitDuelEntryNotDuelist() public {
    vm.expectRevert(abi.encodeWithSelector(NotADuelistError.selector));
    kingsToilet.submitDuelEntry(
      1,
      "name",
      "symbol",
      "uri",
      "description"
    );
  }

  function testSubmitDuelEntryDeadlineReached() public {
    vm.startPrank(king);
    vm.expectEmit();
    emit DuelCreated(1, 1);
    kingsToilet.createDuel("Duel test", "The first duel of test.");
    vm.stopPrank();

    vm.startPrank(duelist1);
    vm.warp(block.timestamp + 10 days);
    vm.expectRevert(abi.encodeWithSelector(DuelEntryDeadlineReachedError.selector));
    kingsToilet.submitDuelEntry(
      1,
      "name",
      "symbol",
      "uri",
      "description"
    );
    vm.stopPrank();
  }

  /*
  function testSubmitDuelEntry() public {
    vm.startPrank(king);
    vm.expectEmit();
    emit DuelCreated(1, 1);
    kingsToilet.createDuel("Duel test", "The first duel of test.");
    vm.stopPrank();

    vm.startPrank(duelist1);
    vm.expectEmit();
    emit DuelEntrySubmitted();
    kingsToilet.submitDuelEntry(
      1,
      "name",
      "symbol",
      "uri",
      "description"
    );
    vm.stopPrank();
  }
  */

  function testUpdateOpenEditionPrice() public {
    vm.expectEmit();
    emit OpenEditionPriceUpdated();
    kingsToilet.updateOpenEditionPrice(0.5 ether);
  }

  function testUpdateMaxNumberDuels() public {
    vm.expectEmit();
    emit MaxNumberDuelsUpdated();
    kingsToilet.updateMaxNumberDuels(3);
  }

  function testUpdateOpenEditionPriceUnauthorized() public {
    vm.startPrank(king);
    vm.expectRevert(abi.encodeWithSelector(Unauthorized.selector));
    kingsToilet.updateOpenEditionPrice(0.5 ether);
    vm.stopPrank();
  }

  function testUpdateMaxNumberDuelsUnauthorized() public {
    vm.startPrank(king);
    vm.expectRevert(abi.encodeWithSelector(Unauthorized.selector));
    kingsToilet.updateMaxNumberDuels(3);
    vm.stopPrank();
  }

  function testCrownTheKingNoTimeForNewKing() public {
    vm.expectRevert(abi.encodeWithSelector(NotTimeForNewKingError.selector));
    kingsToilet.crownTheKing();
  }

  function testCrownTheKingCannotCrownYourself() public {
    vm.startPrank(king);
    vm.warp(block.timestamp + 7 days + 4 hours);
    vm.expectRevert(abi.encodeWithSelector(CannotCrownYourselfError.selector));
    kingsToilet.crownTheKing();
    vm.stopPrank();
  }

  function testCrownTheKingNotSuccessor() public {
    vm.startPrank(king);
    vm.expectEmit();
    emit SuccessorAdded(1, user1);
    kingsToilet.addSuccessor(user1);
    vm.stopPrank();

    vm.startPrank(user2);
    vm.warp(block.timestamp + 7 days + 10 hours);
    vm.expectRevert(abi.encodeWithSelector(NotSuccessorError.selector));
    kingsToilet.crownTheKing();
    vm.stopPrank();
  }

  function testCrownTheKingSuccessor() public {
    vm.startPrank(king);
    vm.expectEmit();
    emit SuccessorAdded(1, user1);
    kingsToilet.addSuccessor(user1);
    vm.stopPrank();

    vm.startPrank(user1);
    vm.warp(block.timestamp + 7 days + 10 hours);
    vm.expectEmit();
    emit NewKingCrowned(
      2,
      king,
      user1
    );
    kingsToilet.crownTheKing();
    vm.stopPrank();
  }

  function testCrownTheKingTakeOver() public {
    vm.startPrank(king);
    vm.expectEmit();
    emit SuccessorAdded(1, user1);
    kingsToilet.addSuccessor(user1);
    vm.stopPrank();

    vm.startPrank(user2);
    vm.warp(block.timestamp + 7 days + 37 hours);
    vm.expectEmit();
    emit NewKingCrowned(
      2,
      king,
      user2
    );
    kingsToilet.crownTheKing();
    vm.stopPrank();
  }

  function testReignDetails() public {
    IKingsToilet.Reign memory result = kingsToilet.reignDetails(1);
    console.log(StdStyle.blue(result.kingAddress));
  }
}
