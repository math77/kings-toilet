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

  enum Winner {
    Undefined,
    FirstDuelist,
    SecondDuelist
  }

  struct King {
    string name;
    address kingAddress;
  }

  struct Dethrone {
    King king;
    uint64 tomatoes; // for dethrone
    uint64 flowers; // against dethrone
    uint64 trialStart;
    uint64 trialEnd;
    address proposer;
    address newKing;
    bool trialActive;
  }

  struct Reign {
    King king;
    address successorAddress;
    address weekWinner;
    uint64 reignStart;
    uint64 reignEnd;
    uint64 entryDeadline;
    uint64 amountDuels;
  }

  struct Duelist {
    string name;
    uint256 totalDuelWins;
    uint256 totalDuelDefeats;
    uint256 totalWeeklyWins;
    uint256 currentReignWins;
    uint256 veggies;
    bool dueling;
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
    Winner winner;
    DuelStage duelStage;
  }

  struct Bet {
    uint256 duelId;
    uint256 reignId;
    address bettingOn;
    address owner;
    uint96 betAmount;
  }

  /* EVENTS */

  event CreatedDethroneProposal(
    uint256 indexed proposalId,
    address indexed proposer,
    address indexed kingToDethrone
  ); 

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
    address newKing
  );

  event UpdatedKingBio();

  /* ERRORS */


  error AlreadySubmittedError();

  error WrongPriceError();

  error AddressCannotBeZeroError();

  error InvalidDeposeVoteError();

  error ExistAnActiveDethroneTrialError();

  error CannotMakeDethroneProposalError();

  error DethroneProposalFinishedError();

  error DethroneProposalVotePeriodOpenError();

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

  function updateKingName(
    string calldata name
  ) external;

  function submitDuelEntry(
    uint256 duelId, 
    string memory name,
    string memory symbol,
    string memory uri, 
    string memory description
  ) external;

  function createDuel(
    string calldata title,
    string calldata description,
    uint256 duration
  ) external;

  function crownTheKing(string calldata kingName) external;

  function dethroneKingProposal(address newKing) external;

  function voteOnDethroneProposal(uint256 dethroneProposalId, uint64 amountVotes, uint256 voteType) external payable;

  function finishDethroneProposal(uint256 dethroneProposalId) external;

  function currentReignId() external view returns (uint256);

  function duelDetails(uint256 reignId, uint256 duelId) external view returns (Duel memory);

  function duelistDetails(address duelist) external view returns (Duelist memory);

  function reignDetails(uint256 reignId) external view returns (Reign memory);

  function isKing(address user) external returns (bool);

}
