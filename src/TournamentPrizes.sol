// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {ERC1155} from "openzeppelin-contracts/contracts/token/ERC1155/ERC1155.sol";
import {Strings} from "openzeppelin-contracts/contracts/utils/Strings.sol";
import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";

import {Tournament} from "./Tournament.sol";


contract TournamentPrizes is ERC1155, Ownable {

  uint256 private _tokenId;

  Tournament private _tournamentContract;

  mapping(uint256 => string) private _uris;


  event CreatedPrizes(uint256 weekPrizeId, uint256 duelPrizeId); 
  event UpdatedTournamentContract();
  event UpdatedURIs();

  error CallerNotTournamentContractError();
  error URICannotBeEmptyError();
  error IsNotTheKingError();

  modifier onlyTournament() { 
    if(msg.sender != address(_tournamentContract)) revert CallerNotTournamentContractError(); 
    _; 
  }
  
  constructor() ERC1155("") Ownable() {}

  function mint(address user, uint256 id, uint256 amount) external onlyTournament {
    _mint(user, id, amount, "");
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

  function currentTokenId() external view returns (uint256) {
    return _tokenId;
  }

  function setTournamentAddress(Tournament tournament) external onlyOwner {
    _tournamentContract = tournament;

    emit UpdatedTournamentContract();
  }

  function uri(uint256 id) public view override returns (string memory) {
    return _uris[id];
  }

  function contractURI() public view returns (string memory) {
    return "ipfs://bafyreifi6jsi4hhjkprdvyxeadpnhivftb2wfiqs4rmvrud37ez3xebb2e/metadata.json";
  }

}
