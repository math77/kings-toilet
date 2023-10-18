// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {IERC721Drop} from "zora/src/interfaces/IERC721Drop.sol";

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
    address firstDuelist;
    address secondDuelist;
    uint256 betAmount;
    uint256 firstDuelistEntryId;
    uint256 secondDuelistEntryId;
    uint96 firstDuelistTotalBetted;
    uint96 secondDuelistTotalBetted;
    address winnerDuelist;
    IERC721Drop winnerDrop;
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

  struct TokenURIs {
    string metadataUri;
    string dropUri;
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

  event PickedSuccessor(
    uint256 indexed reignId,
    address indexed successor
  );

  event CreatedDuelEntry(
    address duelist,
    uint256 duelId,
    uint256 indexed entryId
  );

  event PickedDuelWinner(
    address winner,
    uint256 duelId
  );

  event CrownedNewKing(
    uint256 indexed reignId,
    address newKing
  );

  event CreatedDuelBet(
    uint256 duelId
  );

  event UpdatedKingBio();

  /* ERRORS */

  error InvalidDeposeVoteError();

  error ExistAnActiveDethroneTrialError();

  error CannotMakeDethroneProposalError();

  error DethroneProposalFinishedError();

  error DethroneProposalVotePeriodOpenError();

  error AddressCannotBeZeroError();

  error WrongPriceError();

  error IsTheKingError();

  error NotTheKingError();

  error NotADuelistError();

  error InvalidDuelError();

  error InvalidReignError();

  error DuelFinishedError();

  error DuelAwaitingJudgementError();

  error NotTimeOfPickWinnerError();

  error CannotCrownYourselfError();

  error CannotTransferError();

  error NotTimeForNewKingError();

  error NotSuccessorError();

  error EntryDeadlineExpiredError();

  error ValueSentLowerThanMinBetError();

  error CannotBetError();

  error CannotCancelBetError();

  error MaxAmountOfDuelsReachedError();


  function setDuelists(address[] memory duelists) external;

  function updateKingName(
    string calldata name
  ) external;

  function createDuelEntry(
    string calldata uri,
    string calldata dropUri,
    uint256 duelId
  ) payable external;

  function createDuel(
    string calldata title,
    string calldata description
  ) external;

  function crownTheKing(string calldata kingName) external;

  function pickDuelWinner(uint256 reignId, uint256 duelId, address winner) external;

  function betOnDuel(
    uint256 duelId,
    address bettingOn
  ) payable external;

  function cancelBet(
    uint256 duelId,
    uint256 betId
  ) external;

  function dethroneKingProposal(address newKing) external;

  function voteOnDethroneProposal(uint256 dethroneProposalId, uint64 amountVotes, uint256 voteType) external payable;

  function finishDethroneProposal(uint256 dethroneProposalId) external;

  function currentReignId() external view returns (uint256);

  function duelDetails(uint256 reignId, uint256 duelId) external view returns (Duel memory);

  function duelistDetails(address duelist) external view returns (Duelist memory);

  function reignDetails(uint256 reignId) external view returns (Reign memory);

  function isKing(address user) external returns (bool);

}
