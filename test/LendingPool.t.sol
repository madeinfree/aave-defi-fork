// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import {LendingPool} from "src/LendingPool.sol";

contract LendingPoolTest is Test {
    LendingPool lendingPool;
    function setUp() public {
        lendingPool = new LendingPool();
    }
}
