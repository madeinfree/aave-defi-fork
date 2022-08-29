// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.16;
import {LendingPool} from "src/LendingPool.sol";
import {LendingPoolConfigurator} from "src/LendingPoolConfigurator.sol";
import {LendingPoolCore} from "src/LendingPoolCore.sol";
import {DefaultReserveInterestRateStrategy} from "src/DefaultReserveInterestRateStrategy.sol";
import {AToken} from "src/tokenization/AToken.sol";

contract Setup { 
  LendingPoolCore public lendingPoolCore;
  LendingPoolConfigurator public lendingPoolConfigurator;
  LendingPool public lendingPool;
  DefaultReserveInterestRateStrategy public defaultReserveInterestRateStrategy;
  AToken public atoken;

  constructor() {
    lendingPoolCore = new LendingPoolCore();
    lendingPoolConfigurator = new LendingPoolConfigurator(lendingPoolCore);
    lendingPool = new LendingPool(lendingPoolCore);
    defaultReserveInterestRateStrategy = new DefaultReserveInterestRateStrategy();
  } 
}