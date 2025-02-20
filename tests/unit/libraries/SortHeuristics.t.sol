pragma solidity ^0.8.0;

import {Test, console2 as console} from 'forge-std/Test.sol';

import {PackedSortedKeyList} from 'src/libraries/PackedSortedKeyList.sol';
import {PackedKeyList} from 'src/libraries/PackedKeyList.sol';
import {LibBit} from 'src/dependencies/solady/LibBit.sol';
import {LibSort} from 'src/dependencies/solady/LibSort.sol';
import {Arrays} from 'src/dependencies/openzeppelin/Arrays.sol';
import {Heap} from 'src/dependencies/openzeppelin/Heap.sol';
import {TransientFrequencyMap} from 'src/libraries/TransientFrequencyMap.sol';

contract SortingHeuristics is Test {
  using PackedSortedKeyList for PackedSortedKeyList.KeyList;
  using PackedSortedKeyList for uint256;
  using PackedSortedKeyList for PackedSortedKeyList.ValueMap;
  using Heap for Heap.Uint256Heap;

  struct LiquidityPremiumWithId {
    uint128 reserveId;
    uint128 liquidityPremium;
  }

  uint256 internal constant MAX_VALUE = 1000_00;
  bool internal constant DEBUG = false;

  PackedSortedKeyList.KeyList internal list;
  PackedSortedKeyList.ValueMap internal map;

  function test_packedList() public {
    _run(10, _buildBitmap([1, 3, 5, 7, 9]));
    _run(128, _buildBitmap([1, 4]));

    _run(5, _buildBitmap(1, 10));
    _run(10, _buildBitmap(1, 10));
    _run(10, _buildBitmap(6, 10));
    _run(50, _buildBitmap(1, 10));
    _run(50, _buildBitmap(3, 10));
    _run(128, _buildBitmap(3, 128));
    _run(128, _buildBitmap(10, 128));
  }

  uint256 internal constant min = 110;
  uint256 internal constant max = 128;

  function test_collectData() public {
    for (uint256 x = min; x <= max; ++x) {
      for (uint256 i = 1; i <= x; ++i) {
        _run(x, _buildBitmap(i, x));
      }
    }
  }

  function test_split1() public {
    for (uint256 x = min; x <= max; ++x) {
      for (uint256 i = 1; i <= x; ++i) {
        uint256 numAssets = x;
        uint256 userBitMap = _buildBitmap(i, x);

        uint256 snapshotId = vm.snapshotState();
        _fillUpTo(numAssets);
        this.runPreSorted(numAssets, userBitMap);
        vm.revertToStateAndDelete(snapshotId);
      }
    }
  }

  function _run(uint256 numAssets, uint256 userBitMap) internal {
    uint256 snapshotId = vm.snapshotState();
    _fillUpTo(numAssets);

    // run with `--isolate`
    this.runPreSorted(numAssets, userBitMap);
    this.runRuntimeSort(numAssets, userBitMap);
    // this.runRuntimeSortHeap(numAssets, userBitMap);
    this.runRuntimeSortTransient(numAssets, userBitMap);

    vm.revertToStateAndDelete(snapshotId);
  }

  function _buildBitmap(uint256[] memory supplied) internal pure returns (uint256) {
    uint256 bitmap;
    for (uint256 i; i < supplied.length; ++i) {
      bitmap |= 1 << supplied[i];
    }
    return bitmap;
  }

  function runPreSorted(uint256 reserveCount, uint256 userBitMap) external {
    if (DEBUG) console.log('\nPreSort\n');

    vm.startSnapshotGas('preSorted', _buildLabel(reserveCount, userBitMap));

    uint256 idx;
    uint256 cache;
    uint256 reserveId;

    while (idx < reserveCount) {
      if (idx != 0 && cache.hasIndex(idx)) {
        reserveId = cache.extractKey(idx);
      } else (cache, reserveId) = list.getWithCache(idx);

      if (_isSupplying(userBitMap, reserveId)) {
        uint256 liquidityPremium = _getLiquidityPremium(reserveId);

        if (DEBUG) console.log('supplying    ', idx, reserveId, liquidityPremium);
      } else {
        if (DEBUG) console.log('not supplying', idx, reserveId, _getLiquidityPremium(reserveId));
      }

      idx++;
    }

    vm.stopSnapshotGas();
  }

  // ! does not support same premium multiple reserves
  function runRuntimeSortTransient(uint256 reserveCount, uint256 userBitMap) external {
    if (DEBUG) console.log('\nRunTimeSortTransient\n');

    vm.startSnapshotGas('runtimeSortTransient', _buildLabel(reserveCount, userBitMap));

    uint256 reserveId = 0;
    uint256 suppliedCount = LibBit.popCount(userBitMap);
    uint256 suppliedReserveIdx = 0;
    uint256[] memory suppliedPremiums = new uint256[](suppliedCount);

    while (reserveId < reserveCount) {
      if (_isSupplying(userBitMap, reserveId)) {
        uint256 liquidityPremium = _getLiquidityPremium(reserveId);
        suppliedPremiums[suppliedReserveIdx++] = liquidityPremium;
        TransientFrequencyMap.put(liquidityPremium, reserveId); // impl packed array here to support same premium multiple reserves

        if (DEBUG) console.log('supplying    ', reserveId, liquidityPremium);
      } else {
        if (DEBUG) console.log('not supplying', reserveId, _getLiquidityPremium(reserveId));
      }

      reserveId++;
    }

    LibSort.sort(suppliedPremiums); // solady sort
    // Arrays.sort(suppliedPremiums); // oz sort
    suppliedReserveIdx = 0;
    while (suppliedReserveIdx < suppliedCount) {
      uint256 riskPremium = suppliedPremiums[suppliedReserveIdx];
      uint256 reserveId = TransientFrequencyMap.get(riskPremium);

      if (DEBUG) console.log('sorted       ', suppliedReserveIdx, reserveId, riskPremium);

      suppliedReserveIdx++;
    }

    vm.stopSnapshotGas();
  }

  function runRuntimeSort(uint256 reserveCount, uint256 userBitMap) external {
    if (DEBUG) console.log('\nRuntimeSort\n');

    vm.startSnapshotGas('runtimeSort', _buildLabel(reserveCount, userBitMap));

    uint256 reserveId = 0;
    uint256 suppliedCount = LibBit.popCount(userBitMap);
    uint256 suppliedReserveIdx = 0;
    uint256[] memory suppliedReserves = new uint256[](suppliedCount);

    while (reserveId < reserveCount) {
      if (_isSupplying(userBitMap, reserveId)) {
        uint256 liquidityPremium = _getLiquidityPremium(reserveId);
        suppliedReserves[suppliedReserveIdx++] = _pack(reserveId, liquidityPremium);

        if (DEBUG) console.log('supplying    ', reserveId, liquidityPremium);
      } else {
        if (DEBUG) console.log('not supplying', reserveId, _getLiquidityPremium(reserveId));
      }

      reserveId++;
    }

    Arrays.sort(suppliedReserves, _packedValueComparator); // oz sort

    suppliedReserveIdx = 0;
    while (suppliedReserveIdx < suppliedCount) {
      (uint256 reserveId, uint256 riskPremium) = _unpack(suppliedReserves[suppliedReserveIdx]);

      if (DEBUG) console.log('sorted       ', suppliedReserveIdx, reserveId, riskPremium);

      suppliedReserveIdx++;
    }

    vm.stopSnapshotGas();
  }

  // @dev need to implement memory version since solidity doesn't support dynamic arrays in memory
  // https://forum.soliditylang.org/t/add-the-ability-to-make-dynamic-arrays-in-memory/1867/13
  //   function runRuntimeSortHeap(uint256 reserveCount, uint256 userBitMap) external {
  //     if (DEBUG) console.log('\nRuntimeSortHeap\n');

  //     vm.startSnapshotGas('runtimeSortHeap', _buildLabel(reserveCount, userBitMap));

  //     uint256 reserveId = 0;
  //     uint256 suppliedCount = LibBit.popCount(userBitMap);

  //     Heap.Uint256Heap memory suppliedReserves;

  //     uint256[] memory suppliedReserves = new uint256[](suppliedCount);

  //     while (reserveId < reserveCount) {
  //       if (_isSupplying(userBitMap, reserveId)) {
  //         uint256 liquidityPremium = _getLiquidityPremium(reserveId);
  //         suppliedReserves.insert(_pack(reserveId, liquidityPremium), _packedValueComparator);

  //         if (DEBUG) console.log('supplying    ', reserveId, liquidityPremium);
  //       } else {
  //         if (DEBUG) console.log('not supplying', reserveId, _getLiquidityPremium(reserveId));
  //       }

  //       reserveId++;
  //     }

  //     while (suppliedReserves.length) {
  //       (uint256 reserveId, uint256 riskPremium) = _unpack(
  //         suppliedReserves.pop(_packedValueComparator)
  //       );

  //       if (DEBUG) console.log('sorted       ', reserveId, riskPremium);
  //     }

  //     vm.stopSnapshotGas();
  //   }

  /// @dev omits key, value ceil check
  function _pack(uint256 key, uint256 value) internal pure returns (uint256) {
    return (key << 128) | value;
  }

  function _unpackValue(uint256 data) internal pure returns (uint256) {
    return data & ((1 << 128) - 1);
  }

  function _unpack(uint256 data) internal pure returns (uint256, uint256) {
    return (data >> 128, _unpackValue(data));
  }

  function _packedValueComparator(uint256 a, uint256 b) internal pure returns (bool) {
    return _unpackValue(a) < _unpackValue(b);
  }

  function _getLiquidityPremium(uint256 key) internal view returns (uint256) {
    return map.getValue(key);
  }

  function _fillUpTo(uint256 n) internal {
    for (uint256 i; i < n; ++i) {
      PackedSortedKeyList.insert(list, map, _random(i) % MAX_VALUE);
    }
  }

  function _random(uint256 seed) internal pure returns (uint256) {
    // return vm.randomUint() ^ seed;
    return uint256(keccak256(abi.encode(seed)));
  }

  function _isSupplying(uint256 bitmap, uint256 idx) internal pure returns (bool) {
    return (bitmap & (1 << idx)) != 0;
  }

  function _buildBitmap(uint256 numSupplied, uint256 numAssets) internal returns (uint256) {
    require(numSupplied <= numAssets, 'too many supplied');
    uint256 bitMap;
    while (numSupplied > 0) {
      uint256 pos = vm.randomUint() % numAssets;
      if ((bitMap & (1 << pos)) == 0) {
        bitMap |= (1 << pos);
        numSupplied--;
      }
    }
    return bitMap;
  }

  function _buildBitmap(uint8[1] memory supplied) internal pure returns (uint256) {
    uint8[] memory _supplied = new uint8[](supplied.length);
    for (uint256 i; i < supplied.length; ++i) {
      _supplied[i] = supplied[i];
    }
    return _buildBitmap(_supplied);
  }

  function _buildBitmap(uint8[2] memory supplied) internal pure returns (uint256) {
    uint8[] memory _supplied = new uint8[](supplied.length);
    for (uint256 i; i < supplied.length; ++i) {
      _supplied[i] = supplied[i];
    }
    return _buildBitmap(_supplied);
  }

  function _buildBitmap(uint8[3] memory supplied) internal pure returns (uint256) {
    uint8[] memory _supplied = new uint8[](supplied.length);
    for (uint256 i; i < supplied.length; ++i) {
      _supplied[i] = supplied[i];
    }
    return _buildBitmap(_supplied);
  }

  function _buildBitmap(uint8[4] memory supplied) internal pure returns (uint256) {
    uint8[] memory _supplied = new uint8[](supplied.length);
    for (uint256 i; i < supplied.length; ++i) {
      _supplied[i] = supplied[i];
    }
    return _buildBitmap(_supplied);
  }

  function _buildBitmap(uint8[5] memory supplied) internal pure returns (uint256) {
    uint8[] memory _supplied = new uint8[](supplied.length);
    for (uint256 i; i < supplied.length; ++i) {
      _supplied[i] = supplied[i];
    }
    return _buildBitmap(_supplied);
  }
  function _buildBitmap(uint8[] memory supplied) internal pure returns (uint256) {
    uint256 bitmap;
    for (uint256 i; i < supplied.length; ++i) {
      bitmap |= 1 << supplied[i];
    }
    return bitmap;
  }

  function _buildLabel(
    uint256 numAssets,
    uint256 userBitMap
  ) internal pure returns (string memory) {
    return
      string.concat(
        'numAssets_',
        vm.toString(numAssets),
        '_numSupplied_',
        vm.toString(LibBit.popCount(userBitMap))
      );
  }

  function _clear() internal {
    while (list.length() != 0) {
      PackedSortedKeyList.remove(list, map, 0);
    }
    console.log('list length', list.length());
  }
}
