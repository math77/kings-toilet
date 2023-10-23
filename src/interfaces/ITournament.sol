// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {IERC721Drop} from "zora/src/interfaces/IERC721Drop.sol";
import {ERC721Drop} from "zora/src/ERC721Drop.sol";

interface ITournament {

  enum DuelStage {
    AwaitingSubmissions,
    AwaitingJudgment,
    Finished
  }

  struct Dethrone {
    address kingAddress;
    uint64 tomatoes; // for dethrone
    uint64 flowers; // against dethrone
    uint64 trialStart;
    uint64 trialEnd;
    address proposer;
    address newKing;
    bool trialActive;
  }

  struct Reign {
    address kingAddress;
    address successorAddress;
    address weekWinner;
    uint64 reignStart;
    uint64 reignEnd;
    uint64 entryDeadline;
    uint64 amountDuels;
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
    DuelStage duelStage;
  }

  /* EVENTS */

  event DuelistAdded(address duelist);

  event DuelCreated(
    uint256 indexed duelId,
    uint256 indexed reignId
  );

  event DuelFinished(
    address duelist,
    uint256 prize,
    uint256 duelId
  );

  event PickedSuccessor(
    uint256 indexed reignId,
    address indexed successor
  );

  event DuelEntrySubmitted(
    address duelist,
    ERC721Drop dropAddress,
    uint256 duelId
  );

  event CrownedNewKing(
    uint256 indexed reignId,
    address indexed oldKing,
    address indexed newKing
  );

  event UpdatedKingBio();

  /* ERRORS */


  error AlreadySubmittedError();

  error WrongPriceError();

  error AddressCannotBeZeroError();

  error IsTheKingError();

  error NotTheKingError();

  error NotADuelistError();

  error InvalidDuelError();

  error InvalidReignError();

  error DuelFinishedError();

  error DuelAwaitingJudgementError();

  error NotFinishTimeError();

  error CannotCrownYourselfError();

  error NotTimeForNewKingError();

  error NotSuccessorError();

  error EntryDeadlineExpiredError();

  error DuelEntryDeadlineReachedError();

  error MaxAmountOfDuelsReachedError();


  function setDuelists(address[] memory duelists) external;

  function submitDuelEntry(
    uint256 duelId, 
    string memory name,
    string memory symbol,
    string memory uri, 
    string memory description
  ) external;

  function createDuel(
    string calldata title,
    string calldata description
  ) external;

  function crownTheKing() external;

  function currentReignId() external view returns (uint256);

  function duelDetails(uint256 reignId, uint256 duelId) external view returns (Duel memory);

  function duelistDetails(address duelist) external view returns (Duelist memory);

  function reignDetails(uint256 reignId) external view returns (Reign memory);

  function duelSubmission(uint256 duelId, address duelist) external view returns (ERC721Drop);

  function isKing(address user) external returns (bool);

}
