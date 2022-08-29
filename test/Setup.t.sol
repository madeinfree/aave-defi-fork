// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import {Setup} from "src/Setup.sol";

import {AToken} from "src/tokenization/AToken.sol";

contract LendingPoolTest is Test {
    Setup setup;

    address ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    function setUp() public {
        setup = new Setup();
    }

    function testShouldDeposit() public {
        setup.lendingPoolConfigurator().initReserve(
            ETH,
            "AAVE ETH",
            "aETH",
            18,
            address(setup.defaultReserveInterestRateStrategy())
        );

        setup.lendingPool().deposit{value: 10 ether}(
            ETH,
            10 ether
        );

        AToken aETH = AToken(setup.lendingPoolCore().getReserveATokenAddress(ETH));

        assertEq(setup.lendingPoolCore().getReserveAvailableLiquidity(ETH), aETH.balanceOf(address(this)));
    }
}