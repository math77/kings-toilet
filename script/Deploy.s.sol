// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";

import {KingsToilet} from "../src/KingsToilet.sol";
import {KingsToiletPrizes} from "../src/KingsToiletPrizes.sol";
import {DuelistDropFundsFactory} from "../src/DuelistDropFundsFactory.sol";
import {DuelistDropFunds} from "../src/DuelistDropFunds.sol";
import {ZoraNFTCreatorV1} from "zora/src/ZoraNFTCreatorV1.sol";
import {ERC721Drop} from "zora/src/ERC721Drop.sol";


contract Deploy is Script {

  function run() public {
    console2.log("Setup contracts ---");
    
    address deployer = vm.envAddress("DEPLOYER_KEY");

    vm.startBroadcast(deployer);

    //KingsToilet kingsToilet = new KingsToilet();
    //KingsToiletPrizes prizes = new KingsToiletPrizes();
    


  }
}
