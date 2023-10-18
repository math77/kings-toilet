// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import {Ownable} from "openzeppelin-contracts/contracts/access/Ownable.sol";

import {Tournament} from "./Tournament.sol";

import {ITournament} from "./interfaces/ITournament.sol";

import "forge-std/console.sol";


contract TournamentBetSystem is Ownable {

  uint256 private _betId;
  uint256 private _balance;

  Tournament private _tournamentContract;

  mapping(uint256 => ITournament.Bet) private _bets;

  event UpdatedTournamentContract();
  event ProfitWithdrawn();

  error CallerNotTournamentContractError();
  error DuelNotFinishedError();
  error WithdrawBetProfitsError();
  error NotBetOwnerError();
  error NoProfitsForTakeError();

  modifier onlyTournament() {
    if(msg.sender != address(_tournamentContract)) revert CallerNotTournamentContractError();
    _; 
  }

  receive() external payable {}
  fallback() external payable {}

  constructor() {}


  function storeBet(uint256 duelId, uint256 reignId, address bettingOn, address owner) external payable onlyTournament {
    uint256 betAmount = msg.value;

    uint256 fee = (betAmount / 100) * 10;

    _balance += fee;

    _bets[++_betId] = ITournament.Bet({
      duelId: duelId,
      reignId: reignId,
      bettingOn: bettingOn,
      owner: owner,
      betAmount: uint96(betAmount - fee)
    });
  }


  function cancelBet(uint256 betId) external onlyTournament {

    ITournament.Bet memory bet = _bets[betId];

    delete _bets[betId];

    (bool sent, ) = bet.owner.call{value: bet.betAmount}("");

    if(!sent) revert WithdrawBetProfitsError();
  }

  function withdrawBetProfit(uint256 betId) external {
    ITournament.Bet memory bet = _bets[betId];

    if (bet.owner != msg.sender) revert NotBetOwnerError();

    ITournament.Duel memory duel = _tournamentContract.duelDetails(bet.duelId, bet.reignId);

    if (duel.duelStage != ITournament.DuelStage.Finished) revert DuelNotFinishedError();

    if (bet.bettingOn != duel.winnerDuelist) revert NoProfitsForTakeError();

    console.log("CHALLENGER TOTAL BETTED: ", duel.firstDuelistTotalBetted);
    console.log("CHALLENGEND TOTAL BETTED: ", duel.secondDuelistTotalBetted);

    uint256 profit;
    if (duel.winner == ITournament.Winner.Challenger) {
      profit = betProfit(bet.betAmount, duel.firstDuelistTotalBetted, duel.secondDuelistTotalBetted);
    } else {
      profit = betProfit(bet.betAmount, duel.secondDuelistTotalBetted, duel.firstDuelistTotalBetted);
    }

    console.log("PROFIT: ", profit);

    uint256 finalAmount = bet.betAmount + profit;

    console.log("FINAL PROFIT: ", finalAmount);

    (bool sent, ) = bet.owner.call{value: finalAmount}("");

    if(!sent) revert WithdrawBetProfitsError();

    emit ProfitWithdrawn();

  }

  function betDetails(uint256 betId) external view returns (ITournament.Bet memory) {
    return _bets[betId];
  }

  function setTournamentAddress(Tournament tournament) external onlyOwner {
    _tournamentContract = tournament;

    emit UpdatedTournamentContract();
  }

  function withdrawBalance() external onlyOwner {
    uint256 b = _balance;
    _balance = 0;

    (bool sent, ) = payable(msg.sender).call{value: b}("");
    require(sent, "Withdraw fees error");
  }

  /*

  A -> win duelist
  B -> loser duelist

  profit = (amount bet on A / total amount bet on A) x amount lost by B bettors

  */
  
  function betProfit(uint96 betAmount, uint96 winnerTotalBetted, uint96 loserTotalBetted) pure public returns (uint256) {
    uint256 scaledBetAmount = uint256(betAmount) * 1e18;  // Scaling ETH value by 1e18 (1 ETH = 1e18 wei)
    uint256 scaledWinnerTotalBetted = uint256(winnerTotalBetted) * 1e18;
    uint256 scaledLoserTotalBetted = uint256(loserTotalBetted) * 1e18;
        
    uint256 product = scaledBetAmount * scaledLoserTotalBetted;
    uint256 profit = product / scaledWinnerTotalBetted;
        
    return profit / 1e18;  // Scaling back to ETH value
  }

}
