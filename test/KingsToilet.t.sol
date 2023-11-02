// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {StdStyle} from "forge-std/StdStyle.sol";
import {KingsToilet} from "../src/KingsToilet.sol";
import {KingsToiletPrizes} from "../src/KingsToiletPrizes.sol";
import {DuelistDropFundsFactory} from "../src/DuelistDropFundsFactory.sol";
import {DuelistDropFunds} from "../src/DuelistDropFunds.sol";
import {IDuelistDropFunds} from "../src/interfaces/IDuelistDropFunds.sol";

import {ZoraNFTCreatorV1} from "zora/src/ZoraNFTCreatorV1.sol";
import {ERC721Drop} from "zora/src/ERC721Drop.sol";
import {ProtocolRewards} from "@zoralabs/protocol-rewards/src/ProtocolRewards.sol";
import {IKingsToilet} from "../src/interfaces/IKingsToilet.sol";
import {IERC721Drop} from "zora/src/interfaces/IERC721Drop.sol";

import "forge-std/console.sol";

//NEVER DO THIS MONOLITHIC :)
contract KingsToiletTest is Test {
  KingsToilet public kingsToilet;
  KingsToiletPrizes public prizes;
  DuelistDropFunds public dropFunds;
  DuelistDropFundsFactory public dropFundsFactory;
  ZoraNFTCreatorV1 public zoraNFTCreatorV1;
  ProtocolRewards public rewardsContract;


  ERC721Drop public dropp;


  address duelist1 = address(1234);
  address duelist2 = address(5678);
  address duelist3 = address(1111);

  address king = address(9234);

  address user1 = address(4312);
  address user2 = address(1409);
  address user3 = address(7712);
  address user4 = address(7971);

  address[] duelists = [duelist1, duelist2, duelist3];

  event DuelistAdded(address indexed duelist);
  event DuelCreated(
    uint256 indexed duelId,
    uint256 indexed reignId
  );
  event DuelFinished(
    address indexed duelist,
    uint256 indexed duelId
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

  event DuelPrizeAdded(
    uint256 duelId, 
    uint256 reignId
  );
  event KingsToiletContractUpdated();

  error CallerNotKingsToiletContractError();
  error URICannotBeEmptyError();
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
  error DuelistCannotBeKingError();

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

    rewardsContract = ProtocolRewards(0x7777777F279eba3d3Ad8F4E708545291A6fDBA8B);

    kingsToilet.setDropFundsFactoryAddress(dropFundsFactory);
    kingsToilet.setFirstKing(king);
    kingsToilet.setDuelists(duelists);

    prizes.setKingsToiletAddress(kingsToilet);

    vm.deal(address(kingsToilet), 1 ether);
    vm.deal(user3, 5 ether);
    vm.deal(user4, 4 ether);
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

  function testAddSuccessorCannotBeDuelist() public {
    vm.startPrank(king);
    vm.expectRevert(abi.encodeWithSelector(DuelistCannotBeKingError.selector));
    kingsToilet.addSuccessor(duelist1);
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

  function testSubmitDuelEntry() public {
    vm.startPrank(king);
    //vm.expectEmit();
    //emit DuelCreated(1, 1);
    kingsToilet.createDuel("Duel test", "The first duel of test.");
    vm.stopPrank();

    vm.startPrank(duelist1);
    vm.expectEmit(true, false, true, false);
    emit DuelEntrySubmitted(
      duelist1,
      dropp,
      1
    );
    kingsToilet.submitDuelEntry(
      1,
      "name",
      "symbol",
      "uri",
      "description"
    );
    vm.stopPrank();
  }

  function testUpdateOpenEditionPrice() public {
    vm.expectEmit();
    emit OpenEditionPriceUpdated();
    kingsToilet.updateOpenEditionPrice(0.5 ether);
  }

  function testUpdateKingBadge() public {
    kingsToilet.updateKingBadge("newBadge");
    string memory tokenURI = kingsToilet.tokenURI(1);
    assertEq(tokenURI, "newBadge");
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

  function testCrownTheKingCannotBeDuelist() public {
    vm.startPrank(duelist1);
    vm.warp(block.timestamp + 7 days + 4 hours);
    vm.expectRevert(abi.encodeWithSelector(DuelistCannotBeKingError.selector));
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

  function testMintDrop() public {
    
    /* CREATE DUEL */
    vm.startPrank(king);
    vm.expectEmit();
    emit DuelCreated(1, 1);
    kingsToilet.createDuel("Duel test", "The first duel of test.");
    vm.stopPrank();

    /* SUBMIT DUEL ENTRY */
    vm.startPrank(duelist1);
    vm.expectEmit(true, false, true, false);
    emit DuelEntrySubmitted(
      duelist1,
      dropp,
      1
    );
    kingsToilet.submitDuelEntry(
      1,
      "name",
      "symbol",
      "uri",
      "description"
    );
    vm.stopPrank();


    /* GET SUBMISSION DROP ADDRESS */
    ERC721Drop dropAddress = kingsToilet.duelSubmission(1, duelist1);

    uint256 toPay = (3 * 0.00060 ether) + (3 * 0.000777 ether);

    /* MINT SOME TOKENS */
    vm.startPrank(user3);
    dropAddress.purchase{value: toPay}(3);
    vm.stopPrank();

    IERC721Drop.AddressMintDetails memory result = dropAddress.mintedPerAddress(user3);
    assertEq(result.publicMints, 3);
  }


  function testFinishDuel() public {

    /* CREATE DUEL */
    vm.startPrank(king);
    vm.expectEmit();
    emit DuelCreated(1, 1);
    kingsToilet.createDuel("Duel test", "The first duel of test.");
    vm.stopPrank();

    /* SUBMIT DUEL ENTRY */
    vm.startPrank(duelist1);
    vm.expectEmit(true, false, true, false);
    emit DuelEntrySubmitted(
      duelist1,
      dropp,
      1
    );
    kingsToilet.submitDuelEntry(
      1,
      "name",
      "symbol",
      "uri",
      "description"
    );
    vm.stopPrank();

    /* SUBMIT DUEL ENTRY 2 */
    vm.startPrank(duelist2);
    vm.expectEmit(true, false, true, false);
    emit DuelEntrySubmitted(
      duelist2,
      dropp,
      1
    );
    kingsToilet.submitDuelEntry(
      1,
      "name2",
      "symbol2",
      "uri2",
      "description2"
    );
    vm.stopPrank();

    /* SUBMIT DUEL ENTRY 3 */
    vm.startPrank(duelist3);
    vm.expectEmit(true, false, true, false);
    emit DuelEntrySubmitted(
      duelist3,
      dropp,
      1
    );
    kingsToilet.submitDuelEntry(
      1,
      "name3",
      "symbol3",
      "uri3",
      "description3"
    );
    vm.stopPrank();


    IKingsToilet.Duel memory result = kingsToilet.duelDetails(1, 1);
    console.log("PARTICIPANTS (test finish duel");

    for (uint256 i; i < result.participants.length; i++) {
      console.log(StdStyle.blue(result.participants[i]));
    }
    

    /* GET SUBMISSION DROP ADDRESS */
    ERC721Drop dropAddress = kingsToilet.duelSubmission(1, duelist1);
    ERC721Drop dropAddress2 = kingsToilet.duelSubmission(1, duelist2);
    ERC721Drop dropAddress3 = kingsToilet.duelSubmission(1, duelist3);

    uint256 toPay = (3 * 0.00060 ether) + (3 * 0.000777 ether);

    /* MINT SOME TOKENS */
    vm.startPrank(user3);
    dropAddress.purchase{value: toPay}(3);
    vm.stopPrank();

    /* MINT SOME TOKENS */
    vm.startPrank(user4);
    dropAddress2.purchase{value: toPay}(3);
    dropAddress3.purchase{value:  0.00060 ether + 0.000777 ether}(1);
    vm.stopPrank();


    /* FINISH DUEL */

    vm.warp(block.timestamp + 7 days + 10 hours);

    for (uint256 i; i < 2; i++) {
      vm.expectEmit();
      emit DuelFinished(duelists[i], 1);
    }

    kingsToilet.finishDuel(1, 1);

    IKingsToilet.Duel memory result2 = kingsToilet.duelDetails(1, 1);

    console.log("WINNERS (test finish duel)");
    for (uint256 i; i < result2.winners.length; i++) {
      console.log(StdStyle.blue(result2.winners[i]));
    }

    assertEq(result2.finished, true);
  }

  function testWithdrawPrize() public {
    /* CREATE DUEL */
    vm.startPrank(king);
    vm.expectEmit();
    emit DuelCreated(1, 1);
    kingsToilet.createDuel("Duel test", "The first duel of test.");
    vm.stopPrank();

    /* SUBMIT DUEL ENTRY */
    vm.startPrank(duelist1);
    vm.expectEmit(true, false, true, false);
    emit DuelEntrySubmitted(
      duelist1,
      dropp,
      1
    );
    kingsToilet.submitDuelEntry(
      1,
      "name",
      "symbol",
      "uri",
      "description"
    );
    vm.stopPrank();

    /* SUBMIT DUEL ENTRY 2 */
    vm.startPrank(duelist2);
    vm.expectEmit(true, false, true, false);
    emit DuelEntrySubmitted(
      duelist2,
      dropp,
      1
    );
    kingsToilet.submitDuelEntry(
      1,
      "name2",
      "symbol2",
      "uri2",
      "description2"
    );
    vm.stopPrank();

    /* SUBMIT DUEL ENTRY 3 */
    vm.startPrank(duelist3);
    vm.expectEmit(true, false, true, false);
    emit DuelEntrySubmitted(
      duelist3,
      dropp,
      1
    );
    kingsToilet.submitDuelEntry(
      1,
      "name3",
      "symbol3",
      "uri3",
      "description3"
    );
    vm.stopPrank();

    /* GET SUBMISSION DROP ADDRESS */
    ERC721Drop dropAddress = kingsToilet.duelSubmission(1, duelist1);
    ERC721Drop dropAddress2 = kingsToilet.duelSubmission(1, duelist2);
    ERC721Drop dropAddress3 = kingsToilet.duelSubmission(1, duelist3);

    uint256 toPay = (6 * 0.00060 ether) + (6 * 0.000777 ether);

    /* MINT SOME TOKENS */
    vm.startPrank(user3);
    dropAddress.purchase{value: toPay}(6);
    vm.stopPrank();

    /* MINT SOME TOKENS */
    vm.startPrank(user4);
    //dropAddress2.purchase{value: toPay}(3);
    dropAddress3.purchase{value:  0.00060 ether + 0.000777 ether}(1);
    vm.stopPrank();


    /* FINISH DUEL */

    vm.warp(block.timestamp + 7 days + 10 hours);

    for (uint256 i; i < 1; i++) {
      vm.expectEmit();
      emit DuelFinished(duelists[i], 1);
    }

    kingsToilet.finishDuel(1, 1);

    IKingsToilet.Duel memory result = kingsToilet.duelDetails(1, 1);

    console.log("WINNERS (test withdraw prize)");
    for (uint256 i; i < result.winners.length; i++) {
      console.log(StdStyle.blue(result.winners[i]));
    }

    address dropProceeds = result.dropProceeds;


    console.log("PROCEEDS TOTAL AMOUNT");
    uint256 amount = rewardsContract.balanceOf(dropProceeds);
    console.log(amount);

    console.log("PREVIOUS BALANCES");
    console.log(duelist1.balance);
    console.log(duelist2.balance);
    console.log(king.balance);

    IDuelistDropFunds(dropProceeds).withdrawFunds();

    console.log("NEW BALANCES");
    console.log(duelist1.balance);
    console.log(duelist2.balance);
    console.log(king.balance);
  }

  function testAddNFTPrize() public {

    vm.startPrank(king);
    vm.expectEmit();
    emit DuelCreated(1, 1);
    kingsToilet.createDuel("Duel test", "The first duel of test.");

    vm.expectEmit();
    emit DuelPrizeAdded(1, 1);
    prizes.addDuelPrize(1, "uri");
    vm.stopPrank();
  }

  function testAddNFTPrizeRevertFinished() public {
    vm.startPrank(king);
    vm.expectEmit();
    emit DuelCreated(1, 1);
    kingsToilet.createDuel("Duel test", "The first duel of test.");

    vm.expectEmit();
    emit DuelPrizeAdded(1, 1);
    prizes.addDuelPrize(1, "uri");

    vm.warp(block.timestamp + 7 days + 10 hours);

    vm.expectEmit();
    emit DuelFinished(address(0), 1);
    kingsToilet.finishDuel(1, 1);

    vm.expectRevert(abi.encodeWithSelector(DuelFinishedError.selector));
    prizes.addDuelPrize(1, "uri");
    vm.stopPrank();
  }

  function testAddNFTPrizeRevertURICannotBeEmpty() public {
    vm.startPrank(king);
    vm.expectEmit();
    emit DuelCreated(1, 1);
    kingsToilet.createDuel("Duel test", "The first duel of test.");

    vm.expectRevert(abi.encodeWithSelector(URICannotBeEmptyError.selector));
    prizes.addDuelPrize(1, "");
    vm.stopPrank();
  }

  function testAddNFTPrizeRevertNotTheKing() public {
    vm.startPrank(king);
    vm.expectEmit();
    emit DuelCreated(1, 1);
    kingsToilet.createDuel("Duel test", "The first duel of test.");
    vm.stopPrank();

    vm.expectRevert(abi.encodeWithSelector(NotTheKingError.selector));
    prizes.addDuelPrize(1, "");
  }
}
