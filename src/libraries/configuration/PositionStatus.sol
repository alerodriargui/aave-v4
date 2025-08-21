// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {LibBit} from 'src/dependencies/solady/LibBit.sol';
import {DataTypes} from 'src/libraries/types/DataTypes.sol';

/**
 * @title PositionStatus
 * @author Aave Labs
 * @notice Implements the bitmap logic to handle the user configuration.
 */
library PositionStatus {
  using PositionStatus for *;
  using LibBit for uint256;

  uint256 internal constant NOT_FOUND = type(uint256).max;

  uint256 internal constant BORROWING_MASK =
    0x5555555555555555555555555555555555555555555555555555555555555555;
  uint256 internal constant COLLATERAL_MASK =
    0xAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA;

  /**
   * @dev Sets if the user is borrowing the reserve identified by reserveId.
   * @param self The configuration object.
   * @param reserveId The index of the reserve in the bitmap.
   * @param borrowing True if the user is borrowing the reserve, false otherwise.
   */
  function setBorrowing(
    DataTypes.PositionStatus storage self,
    uint256 reserveId,
    bool borrowing
  ) internal {
    unchecked {
      uint256 bit = 1 << ((reserveId % 128) << 1);
      if (borrowing) {
        self.map[reserveId >> 7] |= bit;
      } else {
        self.map[reserveId >> 7] &= ~bit;
      }
    }
  }

  /**
   * @dev Sets if the user is using as collateral the reserve identified by reserveId.
   * @param self The configuration object.
   * @param reserveId The index of the reserve in the bitmap.
   * @param usingAsCollateral True if the user is using the reserve as collateral, false otherwise.
   */
  function setUsingAsCollateral(
    DataTypes.PositionStatus storage self,
    uint256 reserveId,
    bool usingAsCollateral
  ) internal {
    unchecked {
      uint256 bit = 1 << (((reserveId % 128) << 1) + 1);
      if (usingAsCollateral) {
        self.map[reserveId >> 7] |= bit;
      } else {
        self.map[reserveId >> 7] &= ~bit;
      }
    }
  }

  /**
   * @dev Returns if a user is using the reserve for borrowing or as collateral.
   * @param self The configuration object.
   * @param reserveId The index of the reserve in the bitmap.
   * @return True if the user is using a reserve for borrowing or as collateral, false otherwise.
   */
  function isUsingAsCollateralOrBorrowing(
    DataTypes.PositionStatus storage self,
    uint256 reserveId
  ) internal view returns (bool) {
    unchecked {
      return (self.getBucketWord(reserveId) >> ((reserveId % 128) << 1)) & 3 != 0;
    }
  }

  /**
   * @dev Returns if a user is using the reserve for borrowing.
   * @param self The configuration object.
   * @param reserveId The index of the reserve in the bitmap.
   * @return True if the user is using a reserve for borrowing, false otherwise.
   */
  function isBorrowing(
    DataTypes.PositionStatus storage self,
    uint256 reserveId
  ) internal view returns (bool) {
    unchecked {
      return (self.getBucketWord(reserveId) >> ((reserveId % 128) << 1)) & 1 != 0;
    }
  }

  /**
   * @dev Returns if a user is using the reserve as collateral.
   * @param self The configuration object.
   * @param reserveId The index of the reserve in the bitmap.
   * @return True if the user is using a reserve as collateral, false otherwise.
   */
  function isUsingAsCollateral(
    DataTypes.PositionStatus storage self,
    uint256 reserveId
  ) internal view returns (bool) {
    unchecked {
      return (self.getBucketWord(reserveId) >> (((reserveId % 128) << 1) + 1)) & 1 != 0;
    }
  }

  /**
   * @dev Counts the number of reserves enabled as collateral.
   * @dev Disregards potential dirty bits set after `reserveCount`.
   * @param self The configuration object.
   * @param reserveCount The current reserveCount, to avoid reading uninitialized buckets.
   */
  function collateralCount(
    DataTypes.PositionStatus storage self,
    uint256 reserveCount
  ) internal view returns (uint256) {
    unchecked {
      uint256 bucket = reserveCount.bucketId();
      uint256 count = self.map[bucket].isolateCollateralUntil(reserveCount).popCount();
      while (bucket != 0) {
        count += self.map[--bucket].isolateCollateral().popCount();
      }
      return count;
    }
  }

  function next(
    DataTypes.PositionStatus storage self,
    uint256 startReserveId,
    uint256 reserveCount
  ) internal view returns (uint256, bool, bool) {
    unchecked {
      uint256 endBucket = reserveCount.bucketId();
      uint256 bucket = startReserveId.bucketId();
      uint256 map = self.map[bucket];
      uint256 setBitId = map.isolateFrom(startReserveId).ffs();
      while (setBitId == 256 && bucket != endBucket) {
        map = self.map[++bucket];
        setBitId = map.ffs();
      }
      if (setBitId == 256) {
        return (NOT_FOUND, false, false);
      } else {
        uint256 word = map >> ((setBitId >> 1) << 1);
        return (setBitId.fromBitId(bucket), word & 1 != 0, word & 2 != 0);
      }
    }
  }

  function nextBorrowing(
    DataTypes.PositionStatus storage self,
    uint256 startReserveId,
    uint256 reserveCount
  ) internal view returns (uint256 reserveId) {
    unchecked {
      uint256 endBucket = reserveCount.bucketId();
      uint256 bucket = startReserveId.bucketId();
      uint256 setBitId = self.map[bucket].isolateBorrowingFrom(startReserveId).ffs();
      while (setBitId == 256 && bucket != endBucket) {
        setBitId = self.map[++bucket].isolateBorrowing().ffs();
      }
      return setBitId == 256 ? NOT_FOUND : setBitId.fromBitId(bucket);
    }
  }

  function nextCollateral(
    DataTypes.PositionStatus storage self,
    uint256 startReserveId,
    uint256 reserveCount
  ) internal view returns (uint256 reserveId) {
    unchecked {
      uint256 endBucket = reserveCount.bucketId();
      uint256 bucket = startReserveId.bucketId();
      uint256 setBitId = self.map[bucket].isolateCollateralFrom(startReserveId).ffs();
      while (setBitId == 256 && bucket != endBucket) {
        setBitId = self.map[++bucket].isolateBorrowing().ffs();
      }
      return setBitId == 256 ? NOT_FOUND : setBitId.fromBitId(bucket);
    }
  }

  /**
   * @dev Returns the word containing the reserve state in the bitmap.
   * @param self The configuration object.
   * @return The word containing the state of the reserve.
   */
  function getBucketWord(
    DataTypes.PositionStatus storage self,
    uint256 reserveId
  ) internal view returns (uint256) {
    return self.map[reserveId.bucketId()];
  }

  function bucketId(uint256 reserveId) internal pure returns (uint256 wordId) {
    assembly ('memory-safe') {
      wordId := shr(7, reserveId)
    }
  }

  function fromBitId(uint256 bitId, uint256 bucket) internal pure returns (uint256 reserveId) {
    assembly ('memory-safe') {
      reserveId := add(shr(1, bitId), shl(7, bucket))
    }
  }

  function isolateBorrowing(uint256 word) internal pure returns (uint256 ret) {
    assembly ('memory-safe') {
      ret := and(word, BORROWING_MASK)
    }
  }

  // disregard bits before `reserveId`
  function isolateBorrowingFrom(
    uint256 word,
    uint256 reserveId
  ) internal pure returns (uint256 ret) {
    // ret = word & (BORROWING_MASK << ((reserveId % 128) << 1));
    assembly ('memory-safe') {
      ret := and(word, shl(shl(1, mod(reserveId, 128)), BORROWING_MASK))
    }
  }

  // disregard bits before `reserveId`
  function isolateFrom(uint256 word, uint256 reserveId) internal pure returns (uint256 ret) {
    // ret = word & (type(uint256).max << ((reserveId % 128) << 1));
    assembly ('memory-safe') {
      ret := and(word, shl(shl(1, mod(reserveId, 128)), not(0)))
    }
  }

  function isolateCollateral(uint256 word) internal pure returns (uint256 ret) {
    assembly ('memory-safe') {
      ret := and(word, COLLATERAL_MASK)
    }
  }

  // disregard bits before `reserveId`
  function isolateCollateralFrom(
    uint256 word,
    uint256 reserveId
  ) internal pure returns (uint256 ret) {
    // ret = word & (COLLATERAL_MASK << ((reserveId % 128) << 1));
    assembly ('memory-safe') {
      ret := and(word, shl(shl(1, mod(reserveId, 128)), COLLATERAL_MASK))
    }
  }

  // disregard bits after `reserveCount`
  function isolateCollateralUntil(
    uint256 word,
    uint256 reserveCount
  ) internal pure returns (uint256 ret) {
    // ret = word & (COLLATERAL_MASK >> (256 - ((reserveCount % 128) << 1)));
    assembly ('memory-safe') {
      ret := and(word, shr(sub(256, shl(1, mod(reserveCount, 128))), COLLATERAL_MASK))
    }
  }
}
