// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.16;

import {LendingPoolCore} from "./LendingPoolCore.sol";

contract LendingPool {
    LendingPoolCore public core;
    
    event Deposit(
        address indexed _reserve,
        address indexed _user,
        uint256 _amount,
        uint16 indexed _referral,
        uint256 _timestamp
    );

    function deposit(address _reserve, uint256 _amount)
        external
        payable
    {
        AToken aToken = Atoken(core.getReserveATokenAddress(_reserve));
    }
}
