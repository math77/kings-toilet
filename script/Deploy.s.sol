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
    
    uint256 deployer = vm.envUint("DEPLOYER_KEY");

    vm.startBroadcast(deployer);

    KingsToiletPrizes prizes = KingsToiletPrizes(0x1Cf125bC22ADD95fF09993FE882fC1f66Df10BF8);
    ZoraNFTCreatorV1 zoraNFTCreatorV1 = ZoraNFTCreatorV1(0x489f8fFbd5f5eA8875c2EbC5CA9ED1214BD77F42);

    KingsToilet kingsToilet = new KingsToilet(
      prizes,
      zoraNFTCreatorV1
    );

    DuelistDropFunds dropFunds = DuelistDropFunds(payable(0x27678F4B1657d8D3819a67248bA3D44aea52EAE0));
    

    DuelistDropFundsFactory dropFundsFactory = new DuelistDropFundsFactory(address(dropFunds), address(kingsToilet));

    kingsToilet.setDropFundsFactoryAddress(dropFundsFactory);
    prizes.setKingsToiletAddress(kingsToilet);

    console2.log("--------- CONTRACTS ADDRESSES ---------");
    console2.log(address(prizes));
    console2.log(address(kingsToilet));
    console2.log(address(dropFunds));
    console2.log(address(dropFundsFactory));

    vm.stopBroadcast();
  }
}
