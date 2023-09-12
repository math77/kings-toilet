// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import {ERC721Drop} from "packages/zora-721-contracts/src/ERC721Drop.sol";

import {TournamentPrizes} from "./TournamentPrizes.sol";
import {TournamentBetSystem} from "./TournamentBetSystem.sol";

import {ITournament} from "./interfaces/ITournament.sol";


import {SSTORE2} from "solady/src/utils/SSTORE2.sol";


contract Tournament is ITournament, ERC721, ReentrancyGuard, Ownable {

  uint256 private _tokenId;
  uint256 private _contestId;
  uint256 private _duelId;
  uint256 private _reignId;

  TournamentPrizes private _tournamentPrizes;
  TournamentBetSystem private _tournamentBetSystem;

  uint256 private constant DUEL_MIN_BEAT = 0.006 ether;
  uint256 private constant DUELIST_REGISTER_FEE = 0.008 ether;

  mapping(uint256 tokenId => string uri) private _tokenURIs;
  
  mapping(address => Duelist) private _duelists;
  mapping(address => bool) private _isDuelist;
  mapping(uint256 contestId => Contest) private _contests;
  //mapping(uint256 duelId => Duel) private _duels;
  mapping(uint256 reignId => Reign) private _reigns;

  mapping(uint256 duelId => mapping(uint256 reignId => Duel)) private _duels;


  constructor(TournamentPrizes tournamentPrizes, TournamentBetSystem tournamentBetSystem) ERC721("TOURNAMENT", "TOURNAMENT") Ownable() {
    _tournamentPrizes = tournamentPrizes;
    _tournamentBetSystem = tournamentBetSystem;
  }


  modifier onlyKing() { 
    if(msg.sender != _reigns[_reignId].kingAddr) revert NotTheKingError(); 
    _; 
  }

  modifier isTheKing(address user) { 
    if (isKing(user)) revert IsTheKingError(); 
    _; 
  }
  
  
  function duelistRegister(string calldata duelistName) external payable isTheKing(msg.sender) {
    if (_isDuelist[msg.sender]) revert AlreadyRegisteredAsDuelistError();
    if (_duelists[msg.sender].guillotined) revert HeadGuillotinedError();
    if (msg.value != DUELIST_REGISTER_FEE) revert WrongPriceError();

    Duelist memory duelist;
    duelist.name = duelistName;

    _duelists[msg.sender] = duelist;
    _isDuelist[msg.sender] = true;

    _tournamentPrizes.mint(msg.sender, 2, 1);

    emit RegisteredDuelist();
  }

  //HOW "CALCULATE" THE DUELIST WINNER FROM THE WEEK?
  //HOW TO DEAL WITH A TIE BETWEEN THE DUELISTS?

  /*

    Each reign lasts 7 days
    The duelists have 5 days of battle to challenge
    and send submissions for their challenges
    The king can judge the submissions as they come in
    and +2 days to judge the remaining submissions


    After the reign current time is over the week prize is available to claim
    check if the claimer is the folk most win
    in case of tie, check number of veggies
    in case of remain tie, check number of defeats (least win)

  */

  function askForDuel(
    address challenged, 
    uint256 contestId
  ) external 
    isTheKing(msg.sender) //challenger 
    isTheKing(challenged) 
  {

    if (contestId == 0 || contestId > _contestId) revert InvalidContestError();
    if (!_isDuelist[msg.sender] || !_isDuelist[challenged]) revert NotADuelistError();
    if (_duelists[msg.sender].guillotined || _duelists[challenged].guillotined) revert HeadGuillotinedError();

    if (block.timestamp > _reigns[_reignId].entryDeadline) revert AskForDuelTimeExpiredError();


    _duels[++_duelId][_reignId] = Duel({
      challenger: msg.sender,
      challenged: challenged,
      contestId: contestId,
      betAmount: 0,
      challengerEntryId: 0,
      challengedEntryId: 0,
      challengerTotalBetted: 0,
      challengedTotalBetted: 0,
      winnerDuelist: address(0),
      winner: Winner.Undefined,
      duelStage: DuelStage.AwaitingResponse
    });

    emit CreatedAskForDuel({
      challenger: msg.sender,
      challenged: challenged,
      duelId: _duelId,
      contestId: contestId
    });

  }

  function acceptDuel(uint256 duelId) external {
    Duel storage duel = _duels[duelId][_reignId];

    if (msg.sender != duel.challenged) revert NotRegisteredForThisDuelError();
    if (block.timestamp > _reigns[_reignId].entryDeadline) revert AcceptDuelTimeExpiredError();

    duel.duelStage = DuelStage.Accepted;

    emit DuelAccepted({duelId: duelId});
  }

  function crownTheKing(string calldata kingName) external {

    /*

      HOW TO DEAL WITH SUCCESSION AND TAKING THE THRONE?
      
      each king determines a successor during his reign
      after the current king's reign is over the successor has 24 hours
      to claim the throne (if there is a definite successor)
      if he does not claim the throne, the throne is open for anyone to
      take


    */

    uint64 reignEnd = _reigns[_reignId].reignEnd;

    if (block.timestamp < reignEnd) revert NotTimeForNewKingError();
    if (msg.sender == _reigns[_reignId].kingAddr) revert CannotCrownYourselfError();

    //24hours and has successor
    address successor = _reigns[_reignId].successorAddr;

    if ((block.timestamp > reignEnd && block.timestamp < reignEnd + 24 hours) && successor != address(0)) {
      if (msg.sender != successor) revert NotSuccessorError();
    }

    Reign memory reign;
    reign.kingName = kingName;
    reign.kingAddr = msg.sender;
    reign.reignStart = uint64(block.timestamp);
    reign.reignEnd = uint64(block.timestamp + 7 days);
    reign.entryDeadline = uint64(block.timestamp + 5 days);

    _reigns[++_reignId] = reign;


    /*
    _reigns[++_reignId] = Reign({
      kingName: kingName,
      kingAddr: msg.sender,
      successorAddr: address(0),
      pointerToKingBio: address(0),
      winner: address(0),
      reignStart: uint64(block.timestamp),
      reignEnd: uint64(block.timestamp + 7 days),
      entryDeadline: uint64(block.timestamp + 5 days),
      amountCollected: 0,
      amountDuels: 0,
      amountWins: 0,
      amountGuillotined: 0,
      amountContests: 0,
      currentTreasure: _reigns[_reignId].currentTreasure
    });
    */

    //call the another contract to mint nft
    _tournamentPrizes.mint(msg.sender, 1, 1);

    emit CrownedNewKing({
      reignId: _reignId,
      newKing: msg.sender
    });
  }

  function createContest(string calldata contestDescription) external onlyKing {
    _contests[++_contestId] = Contest({
      description: contestDescription,
      reignId: _reignId
    });

    _reigns[_reignId].amountContests += 1;

    emit CreatedContest({contestId: _contestId});
  }

  function pickDuelWinner(uint256 duelId, address winner) external onlyKing {
    if (!_isDuelist[winner]) revert NotADuelistError();
    if (duelId == 0 || duelId > _duelId) revert InvalidDuelError();

    Duel storage duel = _duels[duelId][_reignId];

    if (duel.duelStage != DuelStage.AwaitingJudgment) revert NotTimeOfPickWinnerError();

    if (winner != duel.challenger && winner != duel.challenged) revert NotRegisteredForThisDuelError();

    duel.winnerDuelist = winner;
    duel.duelStage = DuelStage.Finished;

    address loser = duel.challenger == winner ? duel.challenged : duel.challenger;

    unchecked {

      _duelists[winner].totalDuelWins += 1;
      _duelists[loser].totalDuelDefeats += 1;
      _reigns[_reignId].amountWins += 1;
      _reigns[_reignId].amountDuels += 1;
    }


    uint256 winTokenId;
    uint256 loserTokenId;

    if (winner == duel.challenger) {
      winTokenId = duel.challengerEntryId;
      loserTokenId = duel.challengedEntryId;
    } else {
      loserTokenId = duel.challengerEntryId;
      winTokenId = duel.challengedEntryId;
    }

    //reclaim nft for the king
    
    _transfer(winner, _reigns[_reignId].kingAddr, winTokenId);

    //send loser for the toilet
    _burn(loserTokenId);

    //call another contract to mint medal nft
    _tournamentPrizes.mint(winner, _tournamentPrizes.currentTokenId(), 1);

    emit PickedDuelWinner({
      winner: winner,
      duelId: duelId
    });

  }

  function createDuelEntry(string calldata uri, uint256 duelId) external payable {

    if (block.timestamp > _reigns[_reignId].entryDeadline) revert EntryDeadlineExpiredError();

    Duel storage duel = _duels[duelId][_reignId];

    if (duel.duelStage == DuelStage.Finished) revert DuelFinishedError();
    if (duel.duelStage == DuelStage.Declined) revert DuelDeclinedError();
    if (duel.duelStage == DuelStage.AwaitingResponse) revert DuelAwaitingResponseError();
    

    _tokenURIs[++_tokenId] = uri;

    if (msg.sender == duel.challenger) {
      duel.challengerEntryId = _tokenId;
    } else if (msg.sender == duel.challenged) {
      duel.challengedEntryId = _tokenId;
    } else {
      revert NotRegisteredForThisDuelError();
    }

    if (duel.challengedEntryId > 0 &&
      duel.challengerEntryId > 0) {

      duel.duelStage = DuelStage.AwaitingJudgment;
    }

    _mint(msg.sender, _tokenId);

    emit CreatedDuelEntry({
      duelist: msg.sender,
      duelId: duelId,
      entryId: _tokenId
    });
  }

  function updateKingBio(string calldata bio) external onlyKing {

    _reigns[_reignId].pointerToKingBio = SSTORE2.write(bytes(bio));

    emit UpdatedKingBio();
  }

  function cutDuelistHead(address duelist) external onlyKing {

    //check if duelist is in a duel????
    if (!_isDuelist[duelist]) revert NotADuelistError();

    if (_duelists[duelist].guillotined) revert HeadGuillotinedError();

    _duelists[duelist].guillotined = true;
    _reigns[_reignId].amountGuillotined += 1;

    //call another contract to mint nft
    _tournamentPrizes.mint(duelist, 3, 1);

    emit CuttedDuelistHead();
  }

  //replace that for an event emitted?
  function throwVeggies(address duelist, uint256 amount) external {
    Duelist storage d = _duelists[duelist];

    if (d.guillotined) revert HeadGuillotinedError();

    d.veggies += amount;

    //USE EXTERNAL FUNCTION WITH EMIT EVENT INSTEAD OF STORAGE THE DATA?
  }

  function betOnDuel(uint256 duelId, address bettingOn) external payable {
    Duel storage duel = _duels[duelId][_reignId];

    if (duel.duelStage != DuelStage.Accepted && duel.duelStage != DuelStage.AwaitingJudgment) revert CannotBet();
    if (bettingOn != duel.challenger && bettingOn != duel.challenged) revert DuelistNotDuelParticipantError();
    if (msg.value < DUEL_MIN_BEAT) revert ValueSentLowerThanMinBetError();

    uint96 fee = uint96((msg.value / 100) * 10);
    uint96 finalBetAmount = uint96(msg.value - fee); 

    if (duel.challenger == bettingOn) {
      duel.challengerTotalBetted += finalBetAmount;
    } else {
      duel.challengedTotalBetted += finalBetAmount;
    }

    _tournamentBetSystem.storeBet{value: msg.value}(duelId, _reignId, bettingOn, msg.sender);

    emit CreatedDuelBet({
      duelId: duelId
    });
  }

  function currentReignId() external view returns (uint256) {
    return _reignId;
  }

  function duelDetails(uint256 duelId, uint256 reignId) external view returns (Duel memory) {
    return _duels[duelId][reignId];
  }

  function duelistDetails(address duelist) external view returns (Duelist memory) {
    return _duelists[duelist];
  }

  function contestDetails(uint256 contestId) external view returns (Contest memory) {
    return _contests[contestId];
  }

  function reignDetails(uint256 reignId) external view returns (Reign memory) {
    return _reigns[reignId];
  }

  function tokenURI(uint256 tokenId) public view override returns (string memory) {
    _requireMinted(tokenId);

    string memory _tokenURI = _tokenURIs[tokenId];
    string memory base = _baseURI();

    // If there is no base URI, return the token URI.
    if (bytes(base).length == 0) {
      return _tokenURI;
    }
    // If both are set, concatenate the baseURI and tokenURI (via abi.encodePacked).
    if (bytes(_tokenURI).length > 0) {
      return string(abi.encodePacked(base, _tokenURI));
    }

  }

  function contractURI() public view returns (string memory) {
    return "ipfs://";
  }

  function isKing(address user) public view returns (bool) {
    return user == _reigns[_reignId].kingAddr;
  }

  function _burn(uint256 tokenId) internal virtual override {
    super._burn(tokenId);

    if (bytes(_tokenURIs[tokenId]).length != 0) {
      delete _tokenURIs[tokenId];
    }
  }

  /*

  FIX THIS
  */

  function _beforeTokenTransfer(
    address from, 
    address to, 
    uint256 /*firstTokenId*/,
    uint256 /*batchSize*/
  ) internal virtual override {

    if (from != address(0) && (to != address(0) && to != _reigns[_reignId].kingAddr)) {
      revert CannotTransferError();
    }
  }

}
