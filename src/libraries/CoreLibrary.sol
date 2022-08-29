// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.16;

import "./WadRayMath.sol";

library CoreLibrary {

  using WadRayMath for uint256;

  uint256 internal constant SECONDS_PER_YEAR = 365 days;

  struct UserReserveData {
    // 用戶借入的本金
    uint256 principalBorrowBalance;
    // 用戶的累積變量借用指數。以 ray 表示
    uint256 lastVariableBorrowCumulativeIndex;
    // 用戶累計的發起費
    uint256 originationFee;
    // 用戶借款的穩定借款利率。以 ray 表示
    uint256 stableBorrowRate;
    uint40 lastUpdateTimestamp;
    // 定義是否應將特定存款用作借款的抵押品
    bool useAsCollateral; 
  }

  struct ReserveData {
    /**
    * @dev refer to the whitepaper, section 1.1 basic concepts for a formal description of these properties.
    **/
    //the liquidity index. Expressed in ray
    uint256 lastLiquidityCumulativeIndex;
    //the current supply rate. Expressed in ray
    uint256 currentLiquidityRate;
    //the total borrows of the reserve at a stable rate. Expressed in the currency decimals
    uint256 totalBorrowsStable;
    //the total borrows of the reserve at a variable rate. Expressed in the currency decimals
    uint256 totalBorrowsVariable;
    //the current variable borrow rate. Expressed in ray
    uint256 currentVariableBorrowRate;
    //the current stable borrow rate. Expressed in ray
    uint256 currentStableBorrowRate;
    //the current average stable borrow rate (weighted average of all the different stable rate loans). Expressed in ray
    uint256 currentAverageStableBorrowRate;
    //variable borrow index. Expressed in ray
    uint256 lastVariableBorrowCumulativeIndex;
    //the ltv of the reserve. Expressed in percentage (0-100)
    uint256 baseLTVasCollateral;
    //the liquidation threshold of the reserve. Expressed in percentage (0-100)
    uint256 liquidationThreshold;
    //the liquidation bonus of the reserve. Expressed in percentage
    uint256 liquidationBonus;
    //the decimals of the reserve asset
    uint256 decimals;
    /**
    * @dev address of the aToken representing the asset
    **/
    address aTokenAddress;
    /**
    * @dev address of the interest rate strategy contract
    **/
    address interestRateStrategyAddress;
    uint40 lastUpdateTimestamp;
    // borrowingEnabled = true means users can borrow from this reserve
    bool borrowingEnabled;
    // usageAsCollateralEnabled = true means users can use this reserve as collateral
    bool usageAsCollateralEnabled;
    // isStableBorrowRateEnabled = true means users can borrow at a stable rate
    bool isStableBorrowRateEnabled;
    // isActive = true means the reserve has been activated and properly configured
    bool isActive;
    // isFreezed = true means the reserve only allows repays and redeems, but not deposits, new borrowings or rate swap
    bool isFreezed;
  }

  /**
    @dev 初始化儲備金
   */
  function init(
    ReserveData storage _self,
    address _aTokenAddress,
    uint256 _decimals,
    address _interestRateStrategyAddress
  ) external {
    require(_self.aTokenAddress == address(0), "Reserve has already been initialized");

    // 初始化為 ray 單位
    if (_self.lastLiquidityCumulativeIndex == 0) {
      _self.lastLiquidityCumulativeIndex = WadRayMath.ray();
    }

    // 初始化為 ray 單位
    if (_self.lastVariableBorrowCumulativeIndex == 0) {
      _self.lastVariableBorrowCumulativeIndex = WadRayMath.ray();
    }

    // 設定 aToken
    _self.aTokenAddress = _aTokenAddress;
    // 設定精度
    _self.decimals = _decimals;

    // 設定利率策略
    _self.interestRateStrategyAddress = _interestRateStrategyAddress;
    // 設定開放
    _self.isActive = true;
    // 設定凍結
    _self.isFreezed = false;
  }

  /**
    @dev 返回準備金的持續標準化收入，值 1e27 表示沒有收入。
         隨著時間的推移，收入是累積的，值為 2*1e27 表示準備金的收入是初始金額的兩倍。
   */

  function updateCumulativeIndexes(ReserveData storage _self) internal {
    uint256 totalBorrows = getTotalBorrows(_self);

    // 如果儲備量 > 0
    if (totalBorrows > 0) {
      // 如果有利息，就計算累積利息
      // cumulated 累積
      uint256 cumulatedLiquidityInterest = calculateLinearInterest(
        _self.currentLiquidityRate, // 流動性利息
        _self.lastUpdateTimestamp // 最後更新時間
      );

      // 最後流動性累積指數加上利息
      _self.lastLiquidityCumulativeIndex = cumulatedLiquidityInterest.rayMul(
        _self.lastLiquidityCumulativeIndex
      );

      uint256 cumulatedVariableBorrowInterest = calculateCompoundedInterest(
        _self.currentVariableBorrowRate,
        _self.lastUpdateTimestamp
      );

      // 最後一個可變借款累積指數
      _self.lastVariableBorrowCumulativeIndex = cumulatedVariableBorrowInterest.rayMul(
        _self.lastVariableBorrowCumulativeIndex
      );
    }
  }
  
  /**
    @dev 以線性公式，計算利息
   */
  function calculateLinearInterest(uint256 _rate, uint40 _lastUpdateTimestamp) internal view returns (uint256) {
    // 檢查時間差距
    uint256 timeDifference = block.timestamp - uint256(_lastUpdateTimestamp);
    // 計算變化
    uint256 timeDelta = timeDifference.wadToRay().rayDiv(SECONDS_PER_YEAR.wadToRay());

    return _rate.rayMul(timeDelta) + WadRayMath.ray();
  }

  /**
    @dev 使用複利公式計算利息的函數 
  */
  function calculateCompoundedInterest(uint256 _rate, uint40 _lastUpdateTimestamp) internal view returns (uint256) {
    // 檢查時間差距
    uint256 timeDifference = block.timestamp - uint256(_lastUpdateTimestamp);
    // 計算利息
    uint256 ratePerSecond = _rate / SECONDS_PER_YEAR;

    return (ratePerSecond + WadRayMath.ray()).rayPow(timeDifference);
  }

  /**
    @dev 總借款總額計算
   */
  function getTotalBorrows(
    CoreLibrary.ReserveData storage _reserve
  ) internal view returns (uint256) {
    // 計算浮動利率儲備量與固定利率儲備量
    return _reserve.totalBorrowsStable + _reserve.totalBorrowsVariable;
  }

  /**
    @dev 獲得標準化收入
  */
  function getNormalizedIncome(CoreLibrary.ReserveData storage _reserve) internal view returns (uint256) {
    uint256 cumulated = calculateLinearInterest(
      _reserve.currentLiquidityRate,
      _reserve.lastUpdateTimestamp
    ).rayMul(_reserve.lastLiquidityCumulativeIndex);

    return cumulated;
  }
}