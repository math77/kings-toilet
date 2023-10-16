// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {IERC721Drop} from "zora/src/interfaces/IERC721Drop.sol";

interface ITournament {

  enum DuelStage {
    AwaitingResponse,
    AwaitingJudgment,
    Declined,
    Accepted,
    Finished
  }

  enum Winner {
    Undefined,
    Challenger,
    Challenged
  }

  struct King {
    string name;
    address kingAddress;
    address biography;
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
    address winner;
    uint64 reignStart;
    uint64 reignEnd;
    uint64 entryDeadline;
    uint64 amountCollected;
    uint64 amountDuels; //finished
    uint64 amountWins;
    uint64 amountGuillotined;
    uint64 amountContests;
    uint96 currentTreasure;
  }
  
  struct Contest {
    string name;
    string description;
    uint256 reignId;
  }

  struct Duelist {
    string name;
    uint256 totalDuelWins;
    uint256 duelWinsByWO;
    uint256 totalDuelDefeats;
    uint256 duelDefeatsByWO;
    uint256 weeklyWins;
    uint256 currentReignWins;
    uint256 treasure;
    uint256 veggies;
    bool guillotined;
    bool dueling;
  }

  struct Duel {
    address challenger;
    address challenged;
    uint256 contestId;
    uint256 betAmount;
    uint256 challengerEntryId;
    uint256 challengedEntryId;
    uint96 challengerTotalBetted;
    uint96 challengedTotalBetted;
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

  event RegisteredDuelist();

  event CreatedAskForDuel(
    address indexed challenger,
    address indexed challenged,
    uint256 indexed duelId,
    uint256 contestId
  );

  event DuelAccepted(
    uint256 duelId
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
    address judgedBy,
    uint256 duelId
  );
  
  event CuttedDuelistHead();

  event CreatedContest(
    uint256 indexed contestId
  );

  event CrownedNewKing(
    uint256 indexed reignId,
    address newKing
  );

  event CreatedDuelBet(
    uint256 duelId
  );

  event AddedMinister(
    address minister
  );

  event RemovedMinister(
    address minister
  );

  event UpdatedKingBio();

  /* ERRORS */

  error InvalidDeposeVoteError();

  error ExistAnActiveDethroneTrialError();

  error CannotMakeDethroneProposalError();

  error DethroneProposalFinishedError();

  error DethroneProposalVotePeriodOpenError();

  error AddressCannotBeZeroError();

  error MinisterCannotBeDuelistError();

  error WrongPriceError();

  error AlreadyRegisteredAsDuelistError();

  error IsTheKingError();

  error NotTheKingError();

  error NotTheKingOrMinisterError();

  error NotADuelistError();

  error InvalidDuelError();

  error InvalidReignError();

  error InvalidContestError();

  error HeadGuillotinedError();

  error CurrentlyDuelingError();

  error DuelFinishedError();

  error DuelDeclinedError();

  error DuelAwaitingResponseError();

  error DuelNotAcceptedError();

  error NotRegisteredForThisDuelError();

  error NotTimeOfPickWinnerError();

  error CannotCrownYourselfError();

  error CannotTransferError();

  error NotTimeForNewKingError();

  error NotSuccessorError();

  error AskForDuelTimeExpiredError();

  error AcceptDuelTimeExpiredError();

  error EntryDeadlineExpiredError();

  error ValueSentLowerThanMinBetError();

  error DuelistNotDuelParticipantError();

  error CannotBetError();

  error CannotCancelBetError();

  error MaxAmountOfContestsReachedError();


  function duelistRegister(string calldata name) external payable;

  function updateKingNameAndBio(
    string calldata name,
    bytes calldata bio
  ) external;

  function addMinister(address minister) external;

  function removeMinister(address minister) external;

  function askForDuel(
    address challenged,
    uint256 contestId
  ) external;

  function acceptDuel(
    uint256 duelId
  ) external;

  function createDuelEntry(
    string calldata uri,
    string calldata dropUri,
    uint256 duelId
  ) payable external;

  function createContest(
    string calldata name,
    string calldata description
  ) external;

  function crownTheKing(string calldata kingName) external;

  function pickDuelWinner(uint256 reignId, uint256 duelId, address winner) external;

  function cutDuelistHead(address duelist) external;

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

  function duelDetails(uint256 duelId, uint256 reignId) external view returns (Duel memory);

  function duelistDetails(address duelist) external view returns (Duelist memory);

  function contestDetails(uint256 reignId, uint256 contestId) external view returns (Contest memory);

  function reignDetails(uint256 reignId) external view returns (Reign memory);

  function isKing(address user) external returns (bool);

}
