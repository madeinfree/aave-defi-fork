// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.16;

import {LendingPoolCore} from "./LendingPoolCore.sol";
import {AToken} from "./tokenization/AToken.sol";

contract LendingPool {
    LendingPoolCore public core;
    
    event Deposit(
        address indexed _reserve,
        address indexed _user,
        uint256 _amount,
        uint16 indexed _referral,
        uint256 _timestamp
    );

    constructor(LendingPoolCore _lendingPoolCoreAddress) {
        core = _lendingPoolCoreAddress;
    }

    function deposit(address _reserve, uint256 _amount)
        external
        payable
    {
        AToken aToken = AToken(core.getReserveATokenAddress(_reserve));

        bool isFirstDeposit = aToken.balanceOf(msg.sender) == 0;

        core.updateStateOnDeposit(_reserve, msg.sender, _amount, isFirstDeposit);

        // 以特定匯率將 AToken 1:1 鑄造給用戶
        aToken.mintOnDeposit(msg.sender, _amount);

        // 將幣轉移到核心合約
        core.transferToReserve{value: msg.value}(_reserve, payable(msg.sender), _amount);
    }
}
