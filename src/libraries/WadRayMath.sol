// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.16;

/**
  @dev 為wads（精度為18位的十進制數）和ray（精度為27位的十進制數）提供 mul 和 div 函數
       A wad 是一個十進位制數，精度為 18 位，表示為整數。
       A ray 是一個精度為 27 位的十進位制數，表示為整數。
 */
library WadRayMath {
  uint256 internal constant WAD = 1e18;
  uint256 internal constant halfWAD = WAD / 2;

  uint256 internal constant RAY = 1e27;
  uint256 internal constant halfRAY = RAY / 2;

  uint256 internal constant WAD_RAY_RATIO = 1e9;

  function ray() internal pure returns (uint256) {
      return RAY;
  }
  function wad() internal pure returns (uint256) {
      return WAD;
  }

  function halfRay() internal pure returns (uint256) {
      return halfRAY;
  }

  function halfWad() internal pure returns (uint256) {
      return halfWAD;
  }

  function wadMul(uint256 a, uint256 b) internal pure returns (uint256) {
      return (halfWAD + a * b) / WAD;
  }

  function wadDiv(uint256 a, uint256 b) internal pure returns (uint256) {
      uint256 halfB = b / 2;

      return (halfB + a * WAD) / b;
  }

  function rayMul(uint256 a, uint256 b) internal pure returns (uint256) {
      return (halfRAY + a * b) / RAY;
  }

  function rayDiv(uint256 a, uint256 b) internal pure returns (uint256) {
      uint256 halfB = b / 2;

      return (halfB + a * RAY) / b;
  }

  function rayToWad(uint256 a) internal pure returns (uint256) {
      uint256 halfRatio = WAD_RAY_RATIO / 2;

      return (halfRatio + a) / WAD_RAY_RATIO;
  }

  function wadToRay(uint256 a) internal pure returns (uint256) {
      return a * WAD_RAY_RATIO;
  }

  function rayPow(uint256 x, uint256 n) internal pure returns (uint256 z) {

      z = n % 2 != 0 ? x : RAY;

      for (n /= 2; n != 0; n /= 2) {
          x = rayMul(x, x);

          if (n % 2 != 0) {
              z = rayMul(z, x);
          }
      }
  }

}