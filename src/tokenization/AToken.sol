// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.16;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import {LendingPoolCore} from "../LendingPoolCore.sol";
import "../libraries/WadRayMath.sol";

contract AToken is ERC20 {
  using WadRayMath for uint256;

  mapping (address => uint256) private userIndexes;
  mapping (address => address) private interestRedirectionAddresses;
  mapping (address => uint256) private redirectedBalances;

  address public underlyingAssetAddress;
  
  LendingPoolCore private core;

  constructor(
    address _underlyingAssetAddress,
    string memory _name,
    string memory _symbol,
    LendingPoolCore _lendingPoolCoreAddress
  ) ERC20(_name, _symbol) {
    underlyingAssetAddress = _underlyingAssetAddress;
    core = _lendingPoolCoreAddress;
  }

  function mintOnDeposit(address _account, uint256 _amount) external {

    // 計算累積餘額
    (,, uint256 balanceIncrease,)  = cumulateBalanceInternal(_account);

    // 更新重新定向的利息
    updateRedirectedBalanceOfRedirectionAddressInternal(_account, balanceIncrease + _amount, 0);

    // 鑄造等量代幣
    _mint(_account, _amount);
  }

  /**
    @dev 計算累積餘額
   */
  function cumulateBalanceInternal(address _user) internal returns (uint256, uint256, uint256, uint256)        {
    uint256 previousPrincipalBalance = super.balanceOf(_user);

    uint256 balanceIncrease = balanceOf(_user) - previousPrincipalBalance;

    _mint(_user, balanceIncrease);

    uint256 index = userIndexes[_user] = core.getReserveNormalizedIncome(underlyingAssetAddress);

    return (
      previousPrincipalBalance,
      previousPrincipalBalance + balanceIncrease,
      balanceIncrease,
      index
    );
  }

  function balanceOf(address _user) public override view returns (uint256) {
    // 取得現在餘額
    uint256 currentPrincipalBalance = super.balanceOf(_user);
    uint256 redirectedBalance = redirectedBalances[_user];

    // 只要都為 0 就回傳 0
    if (currentPrincipalBalance == 0 && redirectedBalance == 0) {
      return 0;
    }

    // 檢查是否有把利息發給地址
    // 如果沒有發給其他地址則執行以下
    if (interestRedirectionAddresses[_user] == address(0)) {
      return calculateCumulatedBalanceInternal(
        _user, currentPrincipalBalance + redirectedBalance
      ) - redirectedBalance;
    } else {
      return currentPrincipalBalance + calculateCumulatedBalanceInternal(
        _user, redirectedBalance
      ) - redirectedBalance;
    }
  }

  /**
    @dev 計算累積餘額
   */
  function calculateCumulatedBalanceInternal(
    address _user,
    uint256 _balance
  ) internal view returns (uint256) {
    return _balance
            .wadToRay()
            .rayMul(core.getReserveNormalizedIncome(underlyingAssetAddress))
            .rayDiv(userIndexes[_user])
            .rayToWad();
  }

  /**
    @dev 更新用戶的重定向餘額。如果用戶沒有重定向他的利息，不執行任何操作。
   */
  function updateRedirectedBalanceOfRedirectionAddressInternal(
    address _user,
    uint256 _balanceToAdd,
    uint256 _balanceToRemove
  ) internal {
    address redirectionAddress = interestRedirectionAddresses[_user];

    // 如果沒有重新定向，則不執行
    if (redirectionAddress == address(0)) {
      return;
    }

    // 重新計算重新定向地址餘額
    (,,uint256 balanceIncrease,) = cumulateBalanceInternal(redirectionAddress);

    // 更新重新定向餘額
    redirectedBalances[redirectionAddress] = redirectedBalances[redirectionAddress] + _balanceToAdd - _balanceToRemove;

    // 如果 redirectionAddress 的利息也在被重定向，我們需要通過增加餘額來更新重定向目標的重定向餘額
    address targetOfRedirectionAddress = interestRedirectionAddresses[redirectionAddress];

    if(targetOfRedirectionAddress != address(0)){
      redirectedBalances[targetOfRedirectionAddress] = redirectedBalances[targetOfRedirectionAddress] + balanceIncrease;
    }
  }
}