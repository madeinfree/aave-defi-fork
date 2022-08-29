// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.16;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {CoreLibrary} from "./libraries/CoreLibrary.sol";
import {IReserveInterestRateStrategy} from "./interfaces/IReserveInterestRateStrategy.sol";

contract LendingPoolCore {

  using SafeERC20 for ERC20;
  using CoreLibrary for CoreLibrary.ReserveData;
  using CoreLibrary for CoreLibrary.UserReserveData;

  mapping(address => CoreLibrary.ReserveData) internal reserves;
  mapping(address => mapping(address => CoreLibrary.UserReserveData)) internal usersReserveData;

  address[] public reservesList;

  function updateStateOnDeposit(
    address _reserve,
    address _user,
    uint256 _amount,
    bool _isFirstDeposit
  ) external {
    // 更新累積利息
    reserves[_reserve].updateCumulativeIndexes();
    // 更新內部儲備利率和時間戳
    updateReserveInterestRatesAndTimestampInternal(_reserve, _amount, 0);

    // 第一次抵押，啟用抵押品
    if (_isFirstDeposit) {
      setUserUseReserveAsCollateral(_reserve, _user, true);
    }
  }

  function updateReserveInterestRatesAndTimestampInternal(
    address _reserve,
    uint256 _liquidityAdded,
    uint256 _liquidityTaken
  ) internal {
    CoreLibrary.ReserveData storage reserve = reserves[_reserve];

    (uint256 newLiquidityRate, uint256 newStableRate, uint256 newVariableRate) = IReserveInterestRateStrategy(
      reserve.interestRateStrategyAddress
    ).calculateInterestRates(
      _reserve,
      getReserveAvailableLiquidity(_reserve) + _liquidityAdded - _liquidityTaken,
      reserve.totalBorrowsStable,
      reserve.totalBorrowsVariable,
      reserve.currentAverageStableBorrowRate 
    );

    // 更新 reserve 最新狀態
    reserve.currentLiquidityRate = newLiquidityRate;
    reserve.currentStableBorrowRate = newStableRate;
    reserve.currentVariableBorrowRate = newVariableRate;

    // 最後更新時間
    reserve.lastUpdateTimestamp = uint40(block.timestamp);
  }

  /**
    @dev 初始化新儲備資產
   */
  function initReserve(
    address _reserve,
    address _aTokenAddress,
    uint256 _decimals,
    address _interestRateStrategyAddress
  ) external {
    reserves[_reserve].init(_aTokenAddress, _decimals, _interestRateStrategyAddress);
    addReserveToListInternal(_reserve);
  }

  /**
    @dev 啟用或禁用儲備作為抵押品
   */
  function setUserUseReserveAsCollateral(address _reserve, address _user, bool _useAsCollateral) public {
    CoreLibrary.UserReserveData storage user = usersReserveData[_user][_reserve];
    user.useAsCollateral = _useAsCollateral;
  }

  /**
    @dev 獲得儲備中的可用流動性，可用流動性是核心合約的餘額。
   */
  function getReserveAvailableLiquidity(address _reserve) public view returns (uint256) {
    uint256 balance = 0;

    if (_reserve == address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE)) {
      balance = address(this).balance;
    } else {
      balance = IERC20(_reserve).balanceOf(address(this));
    }

    return balance;
  }

  function getReserveATokenAddress(address _reserve)  public view returns (address) {
    CoreLibrary.ReserveData memory reserve = reserves[_reserve];
    return reserve.aTokenAddress;
  } 

  /**
    @dev 得到準備金的歸一化收益。值 1e27 表示沒有收入。值 2e27 表示已經有100%的收入了。
   */
  function getReserveNormalizedIncome(address _reserve) external view returns (uint256) {
    CoreLibrary.ReserveData storage reserve = reserves[_reserve];
    return reserve.getNormalizedIncome();
  }

  /**
    @dev 將金額從用戶轉移到目的地儲備
   */
  function transferToReserve(address _reserve, address payable _user, uint256 _amount) external payable {
      if (_reserve != address(0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE)) {
          require(msg.value == 0, "User is sending ETH along with the ERC20 transfer.");
          ERC20(_reserve).safeTransferFrom(_user, address(this), _amount);
      } else {
          require(msg.value >= _amount, "The amount and the value sent to deposit do not match");
          if (msg.value > _amount) {
              // send back excess ETH
              uint256 excessAmount = msg.value - _amount;
              (bool result, ) = _user.call{
                value: excessAmount,
                gas: 50000
              }("");
              require(result, "Transfer of ETH failed");
          }
      }
  }

  /**
    @dev 在儲備金地址的數組中添加儲備金
   */
  function addReserveToListInternal(address _reserve) internal {
    bool reserveAlreadyAdded = false;
    for (uint256 i; i < reservesList.length; i++) {
      if (reservesList[i] == _reserve) {
        reserveAlreadyAdded = true;
      }
    }
    if (!reserveAlreadyAdded) reservesList.push(_reserve);
  }
}