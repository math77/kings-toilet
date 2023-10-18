// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {ERC1155} from "openzeppelin-contracts/contracts/token/ERC1155/ERC1155.sol";
import {Strings} from "openzeppelin-contracts/contracts/utils/Strings.sol";
import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";

import {Tournament} from "./Tournament.sol";


contract TournamentPrizes is ERC1155, Ownable {

  enum DuelStage {
    AwaitingSubmissions,
    AwaitingJudgment,
    Finished
  }

  Tournament private _tournamentContract;

  mapping(uint256 => string) private _uris;


  event DuelPrizeAdded(
    uint256 duelId, 
    uint256 reignId
  );

  event WeekPrizeAdded(
    uint256 duelId, 
    uint256 reignId
  );

  event TournamentContractUpdated();

  error CallerNotTournamentContractError();
  error URICannotBeEmptyError();
  error NotTheKingError();
  error DuelFinishedError();

  modifier onlyTournament() { 
    if(msg.sender != address(_tournamentContract)) revert CallerNotTournamentContractError(); 
    _; 
  }

  modifier onlyKing() {
    if (!_tournamentContract.isKing(msg.sender)) revert NotTheKingError();
    _;
  }
  
  constructor() ERC1155("") Ownable() {}

  function mint(address user, uint256 id, uint256 amount) external onlyTournament {
    _mint(user, id, amount, "");
  }


  function addDuelPrize(uint256 duelId, string calldata uri) external onlyKing {
    uint256 reignId = _tournamentContract.currentReignId();

    if (_tournamentContract.duelDetails(reignId, duelId).duelStage == DuelStage.Finished) revert DuelFinishedError();
    if (bytes(uri).length == 0) revert URICannotBeEmptyError();
    
    _uris[duelId] = uri;

    emit DuelPrizeAdded({
      duelId: duelId,
      reignId: reignId
    });
  }

  function addWeekPrize() external onlyKing {

  }

  function addPrizes(
    string calldata weekPrizeUri,
    string calldata duelPrizeUri
  ) external {

    if (!_tournamentContract.isKing(msg.sender)) revert IsNotTheKingError();

    if (bytes(duelPrizeUri).length == 0 || bytes(weekPrizeUri).length == 0) revert URICannotBeEmptyError();

    _uris[++_tokenId] = weekPrizeUri;
    _uris[++_tokenId] = duelPrizeUri;

    emit CreatedPrizes({
      weekPrizeId: _tokenId - 1,
      duelPrizeId: _tokenId
    });
  }

  function addURIs(
    string calldata kingUri, 
    string calldata registerDuelistUri,
    string calldata guillotineUri
  ) external onlyOwner {

    unchecked {
      _uris[++_tokenId] = kingUri;
      _uris[++_tokenId] = registerDuelistUri;
      _uris[++_tokenId] = guillotineUri;
    }

    emit UpdatedURIs();

  }

  function setTournamentAddress(Tournament tournament) external onlyOwner {
    _tournamentContract = tournament;

    emit TournamentContract();
  }

  function uri(uint256 id) public view override returns (string memory) {
    return _uris[id];
  }

  function contractURI() public view returns (string memory) {
    return "ipfs://bafyreifi6jsi4hhjkprdvyxeadpnhivftb2wfiqs4rmvrud37ez3xebb2e/metadata.json";
  }

}
