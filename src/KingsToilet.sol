// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {ERC721} from "openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";
import {Ownable} from "solady/src/auth/Ownable.sol";
import {ReentrancyGuard} from "openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";

import {ERC721Drop} from "zora/src/ERC721Drop.sol";
import {IERC721Drop} from "zora/src/interfaces/IERC721Drop.sol";
import {ZoraNFTCreatorV1} from "zora/src/ZoraNFTCreatorV1.sol";

import {SSTORE2} from "solady/src/utils/SSTORE2.sol";
import {LibString} from "solady/src/utils/LibString.sol";

import {KingsToiletPrizes} from "./KingsToiletPrizes.sol";
import {DuelistDropFundsFactory} from "./DuelistDropFundsFactory.sol";

import {IKingsToilet} from "./interfaces/IKingsToilet.sol";


contract KingsToilet is IKingsToilet, ERC721, ReentrancyGuard, Ownable {

  uint256 private _tokenId;
  uint256 private _duelId;
  uint256 private _reignId;

  ZoraNFTCreatorV1 public immutable zoraNftCreator;  
  KingsToiletPrizes private _kingsToiletPrizes;
  DuelistDropFundsFactory private _dropFundsFactory;

  uint256 public openEditionPrice;
  uint256 public maxNumberDuelsByReign;

  mapping(address => Duelist) private _duelists;
  //reignId => 
  mapping(uint256 => Reign) private _reigns;
  //reignId => duelId
  mapping(uint256 => mapping(uint256 => Duel)) private _duels;

  //duelId => duelist => submission
  mapping(uint256 => mapping(address => ERC721Drop)) private _duelSubmissions;


  receive() external payable {}
  fallback() external payable {}

  constructor(
    KingsToiletPrizes kingsToiletPrizes,
    ZoraNFTCreatorV1 nftCreator
  ) ERC721("KINGS TOILET", "KINGSTOILET") {
    _kingsToiletPrizes = kingsToiletPrizes;
    zoraNftCreator = nftCreator;

    maxNumberDuelsByReign = 1;
    openEditionPrice = 0.00060 ether;

    _initializeOwner(msg.sender);
  }
  

  modifier onlyKing() { 
    if(msg.sender != _reigns[_reignId].kingAddress) revert NotTheKingError(); 
    _; 
  }

  modifier isTheKing(address user) { 
    if (isKing(user)) revert IsTheKingError(); 
    _; 
  }

  modifier onlyDuelist() { 
    if (!_duelists[msg.sender].allowed) revert NotADuelistError(); 
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

    if (_reigns[_reignId].numberDuels == maxNumberDuelsByReign) revert MaxNumberDuelsReachedError();

    address dropProceeds = _dropFundsFactory.deployDuelistDropFunds(
      _reignId,
      ++_duelId
    );

    Duel memory duel;
    duel.title = title;
    duel.description = SSTORE2.write(bytes(description));
    duel.dropProceeds = dropProceeds;
    duel.entryStart = uint64(block.timestamp);
    duel.entryEnd = _reigns[_reignId].entryDeadline;

    _duels[_reignId][_duelId] = duel;
    _reigns[_reignId].numberDuels += 1;

    emit DuelCreated({
      duelId: _duelId,
      reignId: _reignId
    });
  }

  function crownTheKing() external {

    /*

      HOW TO DEAL WITH SUCCESSION AND TAKING THE THRONE?
      
      each king determines a successor during his reign
      after the current king's reign is over the successor has 36 hours
      to claim the throne (if there is a definite successor)
      if he does not claim the throne, the throne is open for anyone to
      take


    */

    Reign memory oldReign = _reigns[_reignId];

    if (block.timestamp < oldReign.reignEnd) revert NotTimeForNewKingError();
    if (msg.sender == oldReign.kingAddress) revert CannotCrownYourselfError();

    if ((block.timestamp > oldReign.reignEnd && block.timestamp < oldReign.reignEnd + 36 hours) && oldReign.successorAddress != address(0)) {
      if (msg.sender != oldReign.successorAddress) revert NotSuccessorError();
    }

    Reign memory reign;
    reign.kingAddress = msg.sender;
    reign.reignStart = uint64(block.timestamp);
    reign.reignEnd = uint64(block.timestamp + 7 days);
    reign.entryDeadline = uint64(block.timestamp + 5 days);

    _reigns[++_reignId] = reign;

    _mint(msg.sender, ++_tokenId);

    emit NewKingCrowned({
      reignId: _reignId,
      oldKing: oldReign.kingAddress,
      newKing: msg.sender
    });
  }

  function submitDuelEntry(
    uint256 duelId,
    string memory name,
    string memory symbol, 
    string memory imageURI, 
    string memory description
  ) external onlyDuelist {
    Duel storage duel = _duels[_reignId][duelId];

    if (block.timestamp > duel.entryEnd) revert DuelEntryDeadlineReachedError();

    if (duel.finished) revert DuelFinishedError();
    if (address(_duelSubmissions[duelId][msg.sender]) != address(0)) revert AlreadySubmittedError();

    ERC721Drop drop = ERC721Drop(
      payable(
        zoraNftCreator.createEditionWithReferral({
          name: name,
          symbol: symbol,
          editionSize: type(uint64).max,
          royaltyBPS: 0,
          fundsRecipient: payable(duel.dropProceeds),
          defaultAdmin: address(this),
          saleConfig: IERC721Drop.SalesConfiguration({
            publicSalePrice: uint104(openEditionPrice),
            maxSalePurchasePerAddress: type(uint32).max,
            publicSaleStart: uint64(block.timestamp),
            publicSaleEnd: duel.entryEnd + 2 days,
            presaleStart: 0,
            presaleEnd: 0,
            presaleMerkleRoot: 0x0
          }),
          description: description,
          animationURI: "",
          imageURI: imageURI,
          createReferral: owner()
        })
      )
    );

    duel.participants.push(msg.sender);
    _duelSubmissions[duelId][msg.sender] = drop;


    drop.setOwner(msg.sender);
    //the king gets the first token
    drop.mintWithRewards(
      _reigns[_reignId].kingAddress,
      1,
      "",
      owner() //mintReferral
    );

    emit DuelEntrySubmitted({
      duelist: msg.sender,
      dropAddress: drop,
      duelId: duelId
    });
  }

  function finishDuel(uint256 reignId, uint256 duelId) external {
    Duel storage duel = _duels[reignId][duelId];

    if (duel.finished) revert DuelFinishedError();
    if (block.timestamp < duel.entryEnd) revert NotFinishTimeError();

    duel.finished = true;

    uint256 maxTotalSupply;

    uint256[] memory supplies = new uint256[](duel.participants.length);
    for (uint256 i; i < duel.participants.length; i++) {
      ERC721Drop drop = _duelSubmissions[duelId][duel.participants[i]];
      supplies[i] = drop.totalSupply();      
      if (supplies[i] > maxTotalSupply) {
        maxTotalSupply = supplies[i];
      }
    }

    for (uint256 i; i < duel.participants.length; i++) {
      if (supplies[i] == maxTotalSupply) {
        duel.winners[i] = duel.participants[i];
        _duelists[duel.participants[i]].totalDuelWins += 1;

        //mint winner nft
        _kingsToiletPrizes.mint(duel.participants[i], duelId, 1);

        emit DuelFinished({
          duelist: duel.participants[i],
          duelId: duelId
        });
      }
    }
  }

  function addSuccessor(address successor) external onlyKing {
    if (successor == address(0)) revert AddressCannotBeZeroError();
    if (successor == _reigns[_reignId].kingAddress) revert CannotCrownYourselfError();

    _reigns[_reignId].successorAddress = successor;

    emit SuccessorAdded({
      reignId: _reignId,
      successor: successor
    });
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

  function duelSubmission(uint256 duelId, address duelist) external view returns (ERC721Drop) {
    return _duelSubmissions[duelId][duelist];
  }

  function readStore(address pointer) external view returns (string memory) {
    return string(SSTORE2.read(pointer));
  }

  //MINT KING PFP
  function tokenURI(uint256 tokenId) public view override returns (string memory) {
    _requireMinted(tokenId);

    return "ipfs://bafkreicwjb4knvsb5jskoq6kuyzctftctcmswjhpo2dwawcntsblh2evia";
  }

  function updateOpenEditionPrice(uint256 newPrice) external onlyOwner {
    openEditionPrice = newPrice;

    emit OpenEditionPriceUpdated();
  }

  function updateMaxNumberDuels(uint256 newNumber) external onlyOwner {
    maxNumberDuelsByReign = newNumber;

    emit MaxNumberDuelsUpdated();
  }

  function setDropFundsFactoryAddress(DuelistDropFundsFactory newAddress) external onlyOwner {
    _dropFundsFactory = newAddress;
  }

  function setFirstKing(address king) external onlyOwner {
    if (_reignId > 1) revert();

    Reign memory reign;
    reign.kingAddress = king;
    reign.reignStart = uint64(block.timestamp);
    reign.reignEnd = uint64(block.timestamp + 7 days);
    reign.entryDeadline = uint64(block.timestamp + 5 days);

    _reigns[++_reignId] = reign;

    _mint(king, ++_tokenId);

    emit FirstKingCrowned({
      reignId: _reignId,
      king: king
    });
  }

  function isKing(address user) public view returns (bool) {
    return user == _reigns[_reignId].kingAddress;
  }
}
