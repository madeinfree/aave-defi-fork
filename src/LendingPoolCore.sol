// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.16;

import {CoreLibrary} from "./libraries/CoreLibrary.sol";

contract LendingPoolCore {

  mapping(address => CoreLibrary.ReserveData) internal reserves;

  function getReserveATokenAddress(address _reserve)  public view returns (address) {
    CoreLibrary.ReserveData memory reserve = reserves[_reserve];
    return reserve.aTokenAddress;
  } 
}