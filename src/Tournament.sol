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
import {DuelistDropFundsFactory} from "./DuelistDropFundsFactory.sol";

import {ITournament} from "./interfaces/ITournament.sol";


contract Tournament is ITournament, ERC721, ReentrancyGuard, Ownable {

  uint256 private _tokenId;
  uint256 private _duelId;
  uint256 private _reignId;
  uint256 private _dethroneId;

  ZoraNFTCreatorV1 public immutable zoraNftCreator;  
  TournamentPrizes private _tournamentPrizes;
  TournamentBetSystem private _tournamentBetSystem;
  DuelistDropFundsFactory private _dropFundsFactory;

  uint256 private constant DUEL_MIN_BEAT = 0.006 ether;
  uint256 private constant DETHRONE_VOTE_FEE = 0.00003 ether;

  uint256 public openEditionPrice;
  uint256 public constant MAX_AMOUNT_DUELS_BY_REIGN = 3;

  //tokenId
  mapping(uint256 => TokenURIs) private _tokenURIs;
  mapping(address => Duelist) private _duelists;
  //reignId => 
  mapping(uint256 => Reign) private _reigns;
  //reignId => duelId
  mapping(uint256 => mapping(uint256 => Duel)) private _duels;
  //dethroneId
  mapping(uint256 => Dethrone) private _dethroneProposals;

  receive() external payable {}
  fallback() external payable {}

  constructor(
    TournamentPrizes tournamentPrizes, 
    TournamentBetSystem tournamentBetSystem,
    DuelistDropFundsFactory dropFundsFactory,
    ZoraNFTCreatorV1 nftCreator
  ) ERC721("TOURNAMENT", "TOURNAMENT") Ownable() {
    _tournamentPrizes = tournamentPrizes;
    _tournamentBetSystem = tournamentBetSystem;
    _dropFundsFactory = dropFundsFactory;
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
  
  function setDuelists(address[] memory duelists) external onlyOwner {

    for (uint256 i; i < duelists.length; i++) {
      _duelists[duelists[i]].allowed = true;

      emit DuelistAdded(duelists[i]);
    }
  }

  function createDuel(
    string calldata title,
    string calldata description
  ) external onlyKing {

    if (_reigns[_reignId].amountDuels == MAX_AMOUNT_DUELS_BY_REIGN) revert MaxAmountOfDuelsReachedError();

    Duel memory duel;
    duel.title = title;
    duel.description = SSTORE2.write(bytes(description));
    duel.winner = Winner.Undefined;
    duel.duelStage = DuelStage.AwaitingSubmissions;

    _duels[_reignId][++_duelId] = duel;
    _reigns[_reignId].amountDuels += 1;

    emit DuelCreated({
      duelId: _duelId,
      reignId: _reignId
    });
  }

  /*

    Each reign lasts 7 days
    The duelists have 5 days of battle to challenge
    and send submissions for their challenges
    The king can judge the submissions as they come in
    and +2 days to judge the remaining submissions


    After the reign current time is over the week prize is available to claim

  */

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

  //the current king can judge others kingdoms not judged submissions
  function pickDuelWinner(uint256 reignId, uint256 duelId, address winner) external onlyKing {
    if (duel.duelStage == DuelStage.Finished) revert DuelFinishedError();
    if (!_duelists[winner].allowed) revert NotADuelistError();
    if (duelId == 0 || duelId > _duelId) revert InvalidDuelError();
    if (reignId == 0 || reignId > _reignId) revert InvalidReignError();

    Duel storage duel = _duels[reignId][duelId];

    if (duel.duelStage != DuelStage.AwaitingJudgment) revert NotTimeOfPickWinnerError();

    duel.winnerDuelist = winner;
    duel.duelStage = DuelStage.Finished;

    uint256 winnerTokenId;
    uint256 loserTokenId;
    address loser;

    if (winner == duel.firstDuelist) {
      winnerTokenId = duel.firstDuelistEntryId;
      loserTokenId = duel.secondDuelistEntryId;
      loser = duel.secondDuelist;
    } else {
      winnerTokenId = duel.secondDuelistEntryId;
      loserTokenId = duel.firstDuelistEntryId;
      loser = duel.firstDuelist;
    }

    unchecked {
      _duelists[winner].totalDuelWins += 1;
      _duelists[loser].totalDuelDefeats += 1;
    }

    //reclaim nft for the king
    //the current king gets the NFT
    _transfer(winner, _reigns[_reignId].king.kingAddress, winnerTokenId);

    //send loser for the toilet
    _burn(loserTokenId);

    //call another contract to mint medal nft
    _tournamentPrizes.mint(winner, _tournamentPrizes.currentTokenId(), 1);

    _createDuelistDrop(winner, duelId, _tokenURIs[winnerTokenId].dropUri);

    emit PickedDuelWinner({
      winner: winner,
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
    if (duel.duelStage == DuelStage.AwaitingJudgment) revert DuelAwaitingJudgementError();

    _tokenURIs[++_tokenId] = TokenURIs({
      metadataUri: uri,
      dropUri: dropUri
    });

    if (msg.sender == duel.firstDuelist) {
      duel.firstDuelistEntryId = _tokenId;
    } else if (msg.sender == duel.secondDuelist) {
      duel.secondDuelistEntryId = _tokenId;
    } else {
      revert NotADuelistError();
    }

    if (duel.firstDuelistEntryId > 0 &&
      duel.secondDuelistEntryId > 0) {

      duel.duelStage = DuelStage.AwaitingJudgment;
    }

    _mint(msg.sender, _tokenId);

    emit CreatedDuelEntry({
      duelist: msg.sender,
      duelId: duelId,
      entryId: _tokenId
    });
  }

  function updateKingName(
    string calldata name
  ) external onlyKing {

    _reigns[_reignId].king.name = name;

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

  function dethroneKingProposal(address newKing) external {
    if (block.timestamp > _reigns[_reignId].entryDeadline) revert CannotMakeDethroneProposalError();
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

    amountOfVotes -> amount in batch (*) of 10
  */
  function voteOnDethroneProposal(uint256 dethroneProposalId, uint64 amountVotes, uint256 voteType) external payable {
    if (voteType == 0 || voteType > 2) revert InvalidDeposeVoteError();
    if (msg.value * amountVotes != DETHRONE_VOTE_FEE) revert WrongPriceError();

    if (voteType == 1) {
      _dethroneProposals[dethroneProposalId].tomatoes += amountVotes * 10;
    } else {
      _dethroneProposals[dethroneProposalId].flowers += amountVotes * 10;
    }

  }
  /*
    
    replace the successor or the current king?

  */
  function finishDethroneProposal(uint256 dethroneProposalId) external {
    Dethrone storage dethrone = _dethroneProposals[dethroneProposalId];

    if (dethrone.trialEnd > block.timestamp) revert DethroneProposalVotePeriodOpenError();
    if (dethrone.trialActive) revert DethroneProposalFinishedError();


  }

  function betOnDuel(uint256 duelId, address bettingOn) external payable {
    Duel storage duel = _duels[_reignId][duelId];

    if (duel.duelStage == DuelStage.Finished) revert CannotBetError();
    if (bettingOn != duel.firstDuelist && bettingOn != duel.secondDuelist) revert NotADuelistError();
    if (msg.value < DUEL_MIN_BEAT) revert ValueSentLowerThanMinBetError();

    uint96 fee = uint96((msg.value / 100) * 10);
    uint96 finalBetAmount = uint96(msg.value - fee); 

    if (duel.firstDuelist == bettingOn) {
      duel.firstDuelistTotalBetted += finalBetAmount;
    } else {
      duel.secondDuelistTotalBetted += finalBetAmount;
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

    if (duel.firstDuelist == bet.bettingOn) {
      duel.firstDuelistTotalBetted -= bet.betAmount;
    } else {
      duel.secondDuelistTotalBetted -= bet.betAmount;
    }

    _tournamentBetSystem.cancelBet(betId);
  }

  function currentReignId() external view returns (uint256) {
    return _reignId;
  }

  function duelDetails(uint256 reignId, uint256 duelId) external view returns (Duel memory) {
    return _duels[reignId][duelId];
  }

  function duelistDetails(address duelist) external view returns (Duelist memory) {
    return _duelists[duelist];
  }

  function reignDetails(uint256 reignId) external view returns (Reign memory) {
    return _reigns[reignId];
  }

  function readStore(address pointer) external view returns (string memory) {
    return string(SSTORE2.read(pointer));
  }

  function tokenURI(uint256 tokenId) public view override returns (string memory) {
    _requireMinted(tokenId);

    return _tokenURIs[tokenId].metadataUri;
  }

  function contractURI() public view returns (string memory) {
    return "ipfs://";
  }

  function isKing(address user) public view returns (bool) {
    return user == _reigns[_reignId].king.kingAddress;
  }
  
  function _createDuelistDrop(address duelist, uint256 duelId, string memory dropUri) internal {

    (
      string memory name,
      string memory symbol,
      string memory description
    ) = _createDropAttributes(duelId);

    //deploy funds contract

    address fundsAddress = _dropFundsFactory.deployDuelistDropFunds(
      _reigns[_reignId].king.kingAddress,
      duelist
    );


    ERC721Drop drop = ERC721Drop(
      payable(
        zoraNftCreator.createEditionWithReferral({
          name: name,
          symbol: symbol,
          editionSize: type(uint64).max,
          royaltyBPS: 0,
          fundsRecipient: payable(fundsAddress), //CHANGE FOR A DEPLOYED FUNDS CONTRACT SPECIFIC FOR THIS DUEL (implementation)
          defaultAdmin: address(this),
          saleConfig: IERC721Drop.SalesConfiguration({
            publicSalePrice: uint104(openEditionPrice),
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
          createReferral: address(this) //put my own addres
        })
      )
    );

    _duels[_reignId][duelId].winnerDrop = drop;
  }

  function _createDropAttributes(uint256 duelId) internal view returns (string memory name, string memory symbol, string memory description) {
    Duel memory duel = _duels[_reignId][duelId];

    uint256 winningEntry = duel.winnerDuelist == duel.firstDuelist ? duel.firstDuelistEntryId : duel.secondDuelistEntryId;

    name = string(
      abi.encodePacked(
        _duelists[duel.firstDuelist].name,
        " X ",
        _duelists[duel.secondDuelist].name
      )
    );

    symbol = string(
      abi.encodePacked(
        "$",
        LibString.slice(_duelists[duel.firstDuelist].name, 0, 1),
        LibString.slice(_duelists[duel.secondDuelist].name, 0, 1),
        "D"
      )
    );

    description = string(
      abi.encodePacked(
        "The duelist ",
        _duelists[duel.firstDuelist].name,
        " and the duelist ",
        _duelists[duel.secondDuelist].name,
        " battled in the duel: ",
        duel.title,
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
