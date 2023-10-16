// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import {ERC1967Proxy} from "openzeppelin-contracts/contracts/proxy/ERC1967/ERC1967Proxy.sol";


/// @author promatheus
contract Proxy is ERC1967Proxy {
  constructor(address _logic, bytes memory _data) payable ERC1967Proxy(_logic, _data) {}
}