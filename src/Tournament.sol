// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {ERC721} from "openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";
import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";

import {ERC721Drop} from "zora/src/ERC721Drop.sol";
import {IERC721Drop} from "zora/src/interfaces/IERC721Drop.sol";
import {ZoraNFTCreatorV1} from "zora/src/ZoraNFTCreatorV1.sol";

import {SSTORE2} from "solady/src/utils/SSTORE2.sol";
import {LibString} from "solady/src/utils/LibString.sol";

import {TournamentPrizes} from "./TournamentPrizes.sol";
import {TournamentBetSystem} from "./TournamentBetSystem.sol";

import {ITournament} from "./interfaces/ITournament.sol";


contract Tournament is ITournament, ERC721, ReentrancyGuard, Ownable {

  uint256 private _tokenId;
  uint256 private _contestId;
  uint256 private _duelId;
  uint256 private _reignId;
  uint256 private _dethroneId;

  ZoraNFTCreatorV1 public immutable zoraNftCreator;  
  TournamentPrizes private _tournamentPrizes;
  TournamentBetSystem private _tournamentBetSystem;

  uint256 private constant DUEL_MIN_BEAT = 0.006 ether;
  uint256 private constant DUELIST_REGISTER_FEE = 0.008 ether;

  //tokenId
  mapping(uint256 => TokenURIs) private _tokenURIs;
  
  mapping(address => Duelist) private _duelists;
  mapping(address => bool) private _isDuelist;
  //contestId =>
  mapping(uint256 => Contest) private _contests;
  //reignId => 
  mapping(uint256 => Reign) private _reigns;

  //reignId => user address => is minister?
  mapping(uint256 => mapping(address => bool)) _reignMinisters;

  //reignId => duelId
  mapping(uint256 => mapping(uint256 => Duel)) private _duels;

  //dethroneId
  mapping(uint256 => Dethrone) private _dethroneProposals;

  constructor(
    TournamentPrizes tournamentPrizes, 
    TournamentBetSystem tournamentBetSystem,
    ZoraNFTCreatorV1 nftCreator
  ) ERC721("TOURNAMENT", "TOURNAMENT") Ownable() {
    _tournamentPrizes = tournamentPrizes;
    _tournamentBetSystem = tournamentBetSystem;
    zoraNftCreator = nftCreator;
  }
  

  modifier onlyKing() { 
    if(msg.sender != _reigns[_reignId].king.kingAddress) revert NotTheKingError(); 
    _; 
  }

  modifier isTheKing(address user) { 
    if (isKing(user)) revert IsTheKingError(); 
    _; 
  }

  modifier onlyKingOrMinisters() { 
    if (
      msg.sender != _reigns[_reignId].king.kingAddress &&
      !_reignMinisters[_reignId][msg.sender]
    ) revert NotTheKingOrMinisterError(); 
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


    Duel memory duel;
    duel.challenger = msg.sender;
    duel.challenged = challenged;
    duel.contestId = contestId;
    duel.winner = Winner.Undefined;
    duel.duelStage = DuelStage.AwaitingResponse;

    _duels[_reignId][++_duelId] = duel;

    emit CreatedAskForDuel({
      challenger: msg.sender,
      challenged: challenged,
      duelId: _duelId,
      contestId: contestId
    });

  }

  function acceptDuel(uint256 duelId) external {
    Duel storage duel = _duels[_reignId][duelId];

    if (msg.sender != duel.challenged) revert NotRegisteredForThisDuelError();
    if (block.timestamp > _reigns[_reignId].entryDeadline) revert AcceptDuelTimeExpiredError();

    duel.duelStage = DuelStage.Accepted;

    _duelists[duel.challenger].dueling = true;
    _duelists[duel.challenged].dueling = true;

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
    if (msg.sender == _reigns[_reignId].king.kingAddress) revert CannotCrownYourselfError();

    //24hours and has successor
    address successor = _reigns[_reignId].successorAddress;

    if ((block.timestamp > reignEnd && block.timestamp < reignEnd + 24 hours) && successor != address(0)) {
      if (msg.sender != successor) revert NotSuccessorError();
    }

    Reign memory reign;
    reign.king.name = kingName;
    reign.king.kingAddress = msg.sender;
    reign.reignStart = uint64(block.timestamp);
    reign.reignEnd = uint64(block.timestamp + 7 days);
    reign.entryDeadline = uint64(block.timestamp + 5 days);

    _reigns[++_reignId] = reign;

    //call the another contract to mint nft
    _tournamentPrizes.mint(msg.sender, 1, 1);

    emit CrownedNewKing({
      reignId: _reignId,
      newKing: msg.sender
    });
  }

  function createContest(string calldata name, string calldata description) external onlyKingOrMinisters {
    _contests[++_contestId] = Contest({
      name: name,
      description: description, // save with sstore too?
      reignId: _reignId
    });

    _reigns[_reignId].amountContests += 1;

    emit CreatedContest({contestId: _contestId});
  }

  function pickDuelWinner(uint256 duelId, address winner) external onlyKingOrMinisters {
    if (!_isDuelist[winner]) revert NotADuelistError();
    if (duelId == 0 || duelId > _duelId) revert InvalidDuelError();

    Duel storage duel = _duels[_reignId][duelId];

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


    uint256 winnerTokenId;
    uint256 loserTokenId;

    if (winner == duel.challenger) {
      winnerTokenId = duel.challengerEntryId;
      loserTokenId = duel.challengedEntryId;
    } else {
      loserTokenId = duel.challengerEntryId;
      winnerTokenId = duel.challengedEntryId;
    }

    _duelists[winner].dueling = false;
    _duelists[loser].dueling = false;

    //reclaim nft for the king
    
    _transfer(winner, _reigns[_reignId].king.kingAddress, winnerTokenId);

    //send loser for the toilet
    _burn(loserTokenId);

    //call another contract to mint medal nft
    _tournamentPrizes.mint(winner, _tournamentPrizes.currentTokenId(), 1);

    _createDuelistDrop(winner, duelId, _tokenURIs[winnerTokenId].dropUri);

    emit PickedDuelWinner({
      winner: winner,
      judgedBy: msg.sender,
      duelId: duelId
    });

  }

  function createDuelEntry(
    string calldata uri,
    string calldata dropUri, 
    uint256 duelId
  ) external payable {

    if (block.timestamp > _reigns[_reignId].entryDeadline) revert EntryDeadlineExpiredError();

    Duel storage duel = _duels[_reignId][duelId];

    if (duel.duelStage == DuelStage.Finished) revert DuelFinishedError();
    if (duel.duelStage == DuelStage.Declined) revert DuelDeclinedError();
    if (duel.duelStage == DuelStage.AwaitingResponse) revert DuelAwaitingResponseError();

    _tokenURIs[++_tokenId] = TokenURIs({
      metadataUri: uri,
      dropUri: dropUri
    });

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

  function updateKingNameAndBio(
    string calldata name,
    bytes calldata bio
  ) external onlyKing {

    _reigns[_reignId].king.name = name;
    _reigns[_reignId].king.biography = SSTORE2.write(bio);

    emit UpdatedKingBio();
  }

  function pickSuccessor(address successor) external onlyKing {
    if (successor == address(0)) revert AddressCannotBeZeroError();
    if (successor == _reigns[_reignId].king.kingAddress) revert CannotCrownYourselfError();

    _reigns[_reignId].successorAddress = successor;

    emit PickedSuccessor({
      reignId: _reignId,
      successor: successor
    });
  }

  function addMinister(address minister) external onlyKing {
    if (minister == address(0)) revert AddressCannotBeZeroError();

    _reignMinisters[_reignId][minister] = true;

    emit AddedMinister({ minister: minister }); 
  }

  function removeMinister(address minister) external onlyKing {
    delete _reignMinisters[_reignId][minister];

    emit RemovedMinister({minister: minister});
  }

  function cutDuelistHead(address duelist) external onlyKing {

    if (!_isDuelist[duelist]) revert NotADuelistError();
    if (_duelists[duelist].dueling) revert CurrentlyDuelingError();
    if (_duelists[duelist].guillotined) revert HeadGuillotinedError();

    _duelists[duelist].guillotined = true;
    _reigns[_reignId].amountGuillotined += 1;

    //call another contract to mint nft
    _tournamentPrizes.mint(duelist, 3, 1);

    emit CuttedDuelistHead();
  }

  function dethroneKingProposal(address newKing) external {
    if (newKing == address(0)) revert AddressCannotBeZeroError();
    if (_dethroneProposals[_dethroneId].trialActive) revert ExistAnActiveDethroneTrialError();

    _dethroneProposals[++_dethroneId] = Dethrone({
      king: _reigns[_reignId].king,
      tomatoes: 0,
      flowers: 0,
      trialStart: uint64(block.timestamp),
      trialEnd: uint64(block.timestamp + 12 hours),
      proposer: msg.sender,
      newKing: newKing,
      trialActive: true
    });

    emit CreatedDethroneProposal({
      proposalId: _dethroneId,
      proposer: msg.sender,
      kingToDethrone: _reigns[_reignId].king.kingAddress
    });
  }
  /*
    1 - tomatoes (dethrone the king)
    2 - flowers (keep the king)

    $1 -> 10 tomatoes or flowers
  */
  function voteOnDethroneProposal(uint256 dethroneProposalId, uint64 amountVotes, uint256 voteType) external payable {
    if (voteType == 0 || voteType > 2) revert InvalidDeposeVoteError();

    if (voteType == 1) {
      _dethroneProposals[dethroneProposalId].tomatoes += amountVotes;
    } else {
      _dethroneProposals[dethroneProposalId].flowers += amountVotes;
    }

  }

  //function finishDethroneProposal(uint256 dethroneProposalId) external {}

  function betOnDuel(uint256 duelId, address bettingOn) external payable {
    Duel storage duel = _duels[_reignId][duelId];

    if (duel.duelStage != DuelStage.Accepted && duel.duelStage != DuelStage.AwaitingJudgment) revert CannotBetError();
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

  function cancelBet(uint256 duelId, uint256 betId) external {
    Duel storage duel = _duels[_reignId][duelId];

    if (duel.duelStage == DuelStage.AwaitingJudgment) revert CannotCancelBetError();


    ITournament.Bet memory bet = _tournamentBetSystem.betDetails(betId);

    if (duel.challenger == bet.bettingOn) {
      duel.challengerTotalBetted -= bet.betAmount;
    } else {
      duel.challengedTotalBetted -= bet.betAmount;
    }

    _tournamentBetSystem.cancelBet(betId);
  }

  function currentReignId() external view returns (uint256) {
    return _reignId;
  }

  function duelDetails(uint256 duelId, uint256 reignId) external view returns (Duel memory) {
    return _duels[reignId][duelId];
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

    string memory _tokenURI = _tokenURIs[tokenId].metadataUri;
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
    return user == _reigns[_reignId].king.kingAddress;
  }

  function isMinister(address user, uint256 reignId) public view returns (bool) {
    return _reignMinisters[reignId][user];
  }
  
  function _createDuelistDrop(address duelist, uint256 duelId, string memory dropUri) internal {

    (
      string memory name,
      string memory symbol,
      string memory description
    ) = _createDropAttributes(duelId);

    ERC721Drop drop = ERC721Drop(
      payable(
        zoraNftCreator.createEditionWithReferral({
          name: name,
          symbol: symbol,
          editionSize: type(uint64).max,
          royaltyBPS: 0,
          fundsRecipient: payable(duelist),
          defaultAdmin: address(this),
          saleConfig: IERC721Drop.SalesConfiguration({
            publicSalePrice: 0,
            maxSalePurchasePerAddress: type(uint32).max,
            publicSaleStart: uint64(block.timestamp),
            publicSaleEnd: uint64(block.timestamp +  3 days),
            presaleStart: 0,
            presaleEnd: 0,
            presaleMerkleRoot: 0x0
          }),
          description: description,
          animationURI: "",
          imageURI: dropUri, // ????
          createReferral: address(this)
        })
      )
    );

    _duels[_reignId][duelId].winnerDrop = drop;
  }

  function _createDropAttributes(uint256 duelId) internal view returns (string memory name, string memory symbol, string memory description) {
    Duel memory duel = _duels[_reignId][duelId];

    uint256 winningEntry = duel.winnerDuelist == duel.challenger ? duel.challengerEntryId : duel.challengedEntryId;

    name = string(
      abi.encodePacked(
        _duelists[duel.challenger].name,
        " X ",
        _duelists[duel.challenged].name
      )
    );

    symbol = string(
      abi.encodePacked(
        "$",
        LibString.slice(_duelists[duel.challenger].name, 0, 1),
        LibString.slice(_duelists[duel.challenged].name, 0, 1),
        "D"
      )
    );

    description = string(
      abi.encodePacked(
        "The duelist ",
        _duelists[duel.challenger].name,
        " challenged duelist ",
        _duelists[duel.challenged].name,
        " to a duel in the contest: ",
        _contests[duel.contestId].name,
        ". The duelist ",
        _duelists[duel.winnerDuelist].name,
        " won with submission number #",
        winningEntry
      )
    );
  }

  function _burn(uint256 tokenId) internal virtual override {
    super._burn(tokenId);

    if (bytes(_tokenURIs[tokenId].metadataUri).length != 0) {
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

    if (from != address(0) && (to != address(0) && to != _reigns[_reignId].king.kingAddress)) {
      revert CannotTransferError();
    }
  }

}
