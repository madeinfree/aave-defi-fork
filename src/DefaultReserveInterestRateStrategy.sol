// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.16;

import "./interfaces/IReserveInterestRateStrategy.sol";
import "./libraries/WadRayMath.sol";

contract DefaultReserveInterestRateStrategy is IReserveInterestRateStrategy{
  using WadRayMath for uint256;

  /**
    @dev 常數，獲得最具競爭力的借款利率的利用率
   */
  uint256 public constant OPTIMAL_UTILIZATION_RATE = 0.8 * 1e27;
  /**
    @dev 常數，表示高於最優值的超額利用率，它始終等於 1 - 最佳利用率，用於以 ray 表示的氣體優化。
   */
  uint256 public constant EXCESS_UTILIZATION_RATE = 0.2 * 1e27;
  /**
    @dev Utilization rate = 0 時的基本變量借用率，以 ray 表示。
   */
  uint256 public baseVariableBorrowRate;
  /**
    @dev 當利用率 > 0 且 <= OPTIMAL_UTILIZATION_RATE 時，可變利率曲線的斜率。以 ray 表示
   */
  uint256 public variableRateSlope1;
  /**
    @dev 當利用率 > OPTIMAL_UTILIZATION_RATE 時，可變利率曲線的斜率。以 ray 表示
   */
  uint256 public variableRateSlope2;
  /**
    @dev 當利用率 > 0 且 <= OPTIMAL_UTILIZATION_RATE 時，穩定利率曲線的斜率，以 ray 表示。
   */
  uint256 public stableRateSlope1;
  /**
    @dev 當利用率 > OPTIMAL_UTILIZATION_RATE 時，穩定利率曲線的斜率，以 ray 表示。
   */
  uint256 public stableRateSlope2;

  function getBaseVariableBorrowRate() external view returns (uint256) {
    return baseVariableBorrowRate;
  }

  /**
    calculates the interest rates depending on the available liquidity and the total borrowed.
    param _reserve 儲備地址
    param _availableLiquidity 儲備中可用的流動性
    param _totalBorrowsStable 從儲備中借出的總額 - 穩定利率
    param _totalBorrowsVariable 從儲備中借出的總額 - 浮動利率
    param _averageStableBorrowRate 所有穩定利率借款的加權平均值
    returns 根據輸入參數計算的流動性利率、穩定借款利率和可變借款利率
   */
  function calculateInterestRates(
    address,
    uint256 _availableLiquidity,
    uint256 _totalBorrowsStable,
    uint256 _totalBorrowsVariable,
    uint256 _averageStableBorrowRate
  ) external view returns (
    uint256 currentLiquidityRate, // 流動性利率
    uint256 currentStableBorrowRate, // 穩定借款利率
    uint256 currentVariableBorrowRate // 浮動借款利率
  ) {
    // 計算所有穩定借款予浮動借款
    uint256 totalBorrows = _totalBorrowsStable + _totalBorrowsVariable;

    // 利用率 (https://blog.steaker.com/content/images/size/w1000/2022/06/image-69.png)
    uint256 utilizationRate = (totalBorrows == 0 && _availableLiquidity == 0)
      ? 0 
      : totalBorrows.rayDiv(_availableLiquidity + totalBorrows);

    // 此處利用 Market Borrow Rate Oracle，不過我們照目前 DAI 0.1 即可
    // mainnet 地址 0x8A32f49FFbA88aba6EFF96F45D8BD1D4b3f35c7D
    // currentStableBorrowRate = ILendingRateOracle(addressesProvider.getLendingRateOracle())
    //   .getMarketBorrowRate(_reserve);
    currentStableBorrowRate = 100000000000000000000000000;

    if (utilizationRate > OPTIMAL_UTILIZATION_RATE) {
      // 超過的利用率
      uint256 excessUtilizationRateRatio = (utilizationRate - OPTIMAL_UTILIZATION_RATE)
        .rayDiv(EXCESS_UTILIZATION_RATE);

      currentStableBorrowRate = (currentStableBorrowRate + stableRateSlope1 + stableRateSlope2)
        .rayMul(excessUtilizationRateRatio);

      currentVariableBorrowRate = (baseVariableBorrowRate + variableRateSlope1 + variableRateSlope2)
        .rayMul(excessUtilizationRateRatio);
    } else {

      currentStableBorrowRate = currentStableBorrowRate + (
        stableRateSlope1.rayMul(
          utilizationRate.rayDiv(
            OPTIMAL_UTILIZATION_RATE
          )
        )
      );

      currentVariableBorrowRate = (baseVariableBorrowRate + utilizationRate)
        .rayDiv(OPTIMAL_UTILIZATION_RATE)
        .rayMul(variableRateSlope1);
    }

    currentLiquidityRate = getOverallBorrowRateInternal(
      _totalBorrowsStable,
      _totalBorrowsVariable,
      currentVariableBorrowRate,
      _averageStableBorrowRate
    ).rayMul(utilizationRate);
  }

  /**
    @dev 將總借款利率計算為總可變借款和總穩定借款之間的加權平均值。
   */
  function getOverallBorrowRateInternal(
    uint256 _totalBorrowsStable,
    uint256 _totalBorrowsVariable,
    uint256 _currentVariableBorrowRate,
    uint256 _currentAverageStableBorrowRate
  ) internal pure returns (uint256) {
    uint256 totalBorrows = _totalBorrowsStable + _totalBorrowsVariable;

    if (totalBorrows == 0) return 0;

    uint256 weightedVariableRate = _totalBorrowsVariable.wadToRay().rayMul(
      _currentVariableBorrowRate
    );

    uint256 weightedStableRate = _totalBorrowsStable.wadToRay().rayMul(
      _currentAverageStableBorrowRate
    );

    uint256 overallBorrowRate = (weightedVariableRate + weightedStableRate).rayDiv(
      totalBorrows.wadToRay()
    );

    return overallBorrowRate;
  }
}