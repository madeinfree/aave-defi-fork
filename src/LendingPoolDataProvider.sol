// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.16;

import "src/libraries/WadRayMath.sol";
import "src/LendingPoolCore.sol";

contract LendingPoolDataProvider {
  struct UserGlobalDataLocalVars {
    uint256 reserveUnitPrice;
    uint256 tokenUnit;
    uint256 compoundedLiquidityBalance;
    uint256 compoundedBorrowBalance;
    uint256 reserveDecimals;
    uint256 baseLtv;
    uint256 liquidationThreshold;
    uint256 originationFee;
    bool usageAsCollateralEnabled;
    bool userUsesReserveAsCollateral;
    address currentReserve;
  }

  using WadRayMath for uint256;

  LendingPoolCore public core;

  constructor(LendingPoolCore _core) {
    core = _core;
  }

  /**
    @dev 取得 User 帳戶資訊
   */
  function getUserAccountData(address _user)
    external
    view
    returns (uint256 totalLiquidityETH, uint256 totalCollateralETH) {
      (totalLiquidityETH, totalCollateralETH) = calculateUserGlobalData(_user);
  }

  /**
    @dev 計算 User Data
   */
  function calculateUserGlobalData(address _user)
    public
    view
    returns (
      uint256 totalLiquidityBalanceETH,
      uint256 totalCollateralBalanceETH
    ) {
      UserGlobalDataLocalVars memory vars;
      address[] memory reserves = core.getReserves();

      for(uint256 i; i < reserves.length; i++) {
        vars.currentReserve = reserves[i];

        (
          vars.compoundedLiquidityBalance,
          vars.compoundedBorrowBalance,
          vars.originationFee,
          vars.userUsesReserveAsCollateral
        ) = core.getUserBasicReserveData(vars.currentReserve, _user);

        if (vars.compoundedLiquidityBalance == 0 && vars.compoundedBorrowBalance == 0) {
          continue;
        }

        vars.tokenUnit = 10 ** vars.reserveDecimals;
        vars.reserveUnitPrice = 1;

        if (vars.compoundedLiquidityBalance > 0) {
          uint256 liquidityBalanceETH = vars.reserveUnitPrice * vars.compoundedLiquidityBalance / vars.tokenUnit;
          totalLiquidityBalanceETH = totalLiquidityBalanceETH + liquidityBalanceETH;

          if (vars.usageAsCollateralEnabled && vars.userUsesReserveAsCollateral) {
            totalCollateralBalanceETH = totalCollateralBalanceETH + liquidityBalanceETH;
          }
        }
      }
  }
}