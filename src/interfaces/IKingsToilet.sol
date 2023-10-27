// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {IERC721Drop} from "zora/src/interfaces/IERC721Drop.sol";
import {ERC721Drop} from "zora/src/ERC721Drop.sol";

interface IKingsToilet {

  struct Reign {
    address kingAddress;
    address successorAddress;
    uint64 reignStart;
    uint64 reignEnd;
    uint64 entryDeadline;
    uint64 numberDuels;
  }

  struct Duelist {
    uint256 totalDuelWins;
    bool allowed;
  }

  struct Duel {
    string title;
    address description; //sstore pointer
    uint64 entryStart;
    uint64 entryEnd;
    address dropProceeds;
    address[] participants;
    address[] winners;
    bool finished;
  }

  /* EVENTS */

  event FirstKingCrowned(
    uint256 indexed reignId,
    address indexed king
  );

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

  /* ERRORS */

  error AlreadySubmittedError();

  error AddressCannotBeZeroError();

  error IsTheKingError();

  error NotTheKingError();

  error NotADuelistError();

  error InvalidDuelError();

  error InvalidReignError();

  error DuelFinishedError();

  error NotFinishTimeError();

  error CannotCrownYourselfError();

  error NotTimeForNewKingError();

  error NotSuccessorError();

  error EntryDeadlineExpiredError();

  error DuelEntryDeadlineReachedError();

  error MaxNumberDuelsReachedError();


  /* FUNCTIONS */

  function setDuelists(address[] memory duelists) external;

  function submitDuelEntry(
    uint256 duelId, 
    string memory name,
    string memory symbol,
    string memory imageURI, 
    string memory description
  ) external;

  function createDuel(
    string calldata title,
    string calldata description
  ) external;

  function addSuccessor(address successor) external;

  function crownTheKing() external;

  function currentReignId() external view returns (uint256);

  function duelDetails(uint256 reignId, uint256 duelId) external view returns (Duel memory);

  function duelistDetails(address duelist) external view returns (Duelist memory);

  function reignDetails(uint256 reignId) external view returns (Reign memory);

  function duelSubmission(uint256 duelId, address duelist) external view returns (ERC721Drop);

  function isKing(address user) external returns (bool);

}
