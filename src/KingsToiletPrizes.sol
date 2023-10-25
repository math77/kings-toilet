// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {ERC1155} from "openzeppelin-contracts/contracts/token/ERC1155/ERC1155.sol";
import {Ownable} from "solady/src/auth/Ownable.sol";

import {KingsToilet} from "./KingsToilet.sol";


contract KingsToiletPrizes is ERC1155, Ownable {

  KingsToilet private _kingsToiletContract;

  mapping(uint256 => string) private _uris;


  event DuelPrizeAdded(
    uint256 duelId, 
    uint256 reignId
  );
  event KingsToiletContractUpdated();

  error CallerNotKingsToiletContractError();
  error URICannotBeEmptyError();
  error NotTheKingError();
  error DuelFinishedError();

  modifier onlyKingsToilet() { 
    if(msg.sender != address(_kingsToiletContract)) revert CallerNotKingsToiletContractError(); 
    _; 
  }

  modifier onlyKing() {
    if (!_kingsToiletContract.isKing(msg.sender)) revert NotTheKingError();
    _;
  }
  
  constructor() ERC1155("") {
    _initializeOwner(msg.sender);
  }

  function mint(address user, uint256 id, uint256 amount) external onlyKingsToilet {
    _mint(user, id, amount, "");
  }


  function addDuelPrize(uint256 duelId, string calldata imageURI) external onlyKing {
    uint256 reignId = _kingsToiletContract.currentReignId();

    if (_kingsToiletContract.duelDetails(reignId, duelId).finished) revert DuelFinishedError();
    if (bytes(imageURI).length == 0) revert URICannotBeEmptyError();
    
    _uris[duelId] = imageURI;

    emit DuelPrizeAdded({
      duelId: duelId,
      reignId: reignId
    });
  }

  function setKingsToiletAddress(KingsToilet kingsToilet) external onlyOwner {
    _kingsToiletContract = kingsToilet;

    emit KingsToiletContractUpdated();
  }

  function uri(uint256 id) public view override returns (string memory) {
    return _uris[id];
  }

  function contractURI() public view returns (string memory) {
    return "ipfs://bafyreifi6jsi4hhjkprdvyxeadpnhivftb2wfiqs4rmvrud37ez3xebb2e/metadata.json";
  }

}
