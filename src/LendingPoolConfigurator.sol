// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.16;

import {LendingPoolCore} from "src/LendingPoolCore.sol";
import {AToken} from "src/tokenization/AToken.sol";

contract LendingPoolConfigurator {
  LendingPoolCore private core;

  constructor(LendingPoolCore _core) {
    core = _core;
  }

  function initReserve(
    address _reserve,
    string memory _aTokenName,
    string memory _aTokenSymbol,
    uint8 _underlyingAssetDecimals,
    address _interestRateStrategyAddress
  ) external {
    initReserveWithData(
      _reserve,
      _aTokenName,
      _aTokenSymbol,
      _underlyingAssetDecimals,
      _interestRateStrategyAddress
    );
  }

  function initReserveWithData(
    address _reserve,
    string memory _aTokenName,
    string memory _aTokenSymbol,
    uint8 _underlyingAssetDecimals,
    address _interestRateStrategyAddress
  ) public {
    AToken aTokenInstance = new AToken(
      _reserve,
      _aTokenName,
      _aTokenSymbol,
      core
    );

    core.initReserve(
      _reserve,
      address(aTokenInstance),
      _underlyingAssetDecimals,
      _interestRateStrategyAddress
    );
  }
}