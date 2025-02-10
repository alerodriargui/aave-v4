// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test, Vm, console2 as console} from 'forge-std/Test.sol';

import {Errors} from 'src/libraries/helpers/Errors.sol';
import {PackedSortedList} from 'src/libraries/PackedSortedList.sol';

interface IWrapper {
  function insert(uint256 key, uint256 value) external;
  function get(uint256 index) external returns (uint256 key, uint256 value);
  function removeKey(uint256 key) external;
  function updateKey(uint256 key, uint256 value) external;
  function length() external view returns (uint256 length);
  function searchForIndex(uint256 key) external returns (uint256 index);
  // for gas profiling
  function loop() external;
  function setSnapshotLabel(string memory) external;
}

contract Wrapper is IWrapper {
  using PackedSortedList for PackedSortedList.List;
  PackedSortedList.List internal list;
  string internal snapshotLabel;

  // @dev We do not use `snapGasLastCall` since we want this library to remain internal.
  Vm internal constant vm = Vm(address(uint160(uint256(keccak256('hevm cheat code')))));

  function get(uint256 index) external returns (uint256, uint256) {
    vm.startSnapshotGas(_getLabel('get'));
    (uint256 key, uint256 value) = list.get(index);
    vm.stopSnapshotGas();
    return (key, value);
  }

  function insert(uint256 key, uint256 value) external {
    vm.startSnapshotGas(_getLabel('insert'));
    list.insert(key, value);
    vm.stopSnapshotGas();
  }

  function removeKey(uint256 key) external {
    uint256 index = searchForIndex(key);

    vm.startSnapshotGas(_getLabel('remove'));
    list.remove(index);
    vm.stopSnapshotGas();
  }

  function updateKey(uint256 key, uint256 value) external {
    uint256 index = searchForIndex(key);

    vm.startSnapshotGas(_getLabel('update'));
    list.update(index, value);
    vm.stopSnapshotGas();
  }

  function length() external view returns (uint256) {
    return list.length();
  }

  /// @dev for gas profiling, it's how this will be used in spoke
  function loop() external {
    uint256 idx;
    vm.startSnapshotGas(_getLabel('loop'));
    uint256 len = list.length();
    while (idx < len) {
      list.get(idx); // returns (uint256 reserveId, uint256 liquidityPremium)
      idx++;
    }
    vm.stopSnapshotGas();
  }

  /// @dev for gas profiling
  function setSnapshotLabel(string memory _label) external {
    snapshotLabel = _label;
  }

  // ? find better way to find index but also note it can be computed offchain.
  // ? b+ tree optimization possible which compromises `get` efficiency (or rb-tree with extra bit storing red/black node)
  function searchForIndex(uint256 key) public returns (uint256) {
    uint256 i;
    uint256 len = list.length();
    vm.startSnapshotGas(_getLabel('searchForIndex'));
    for (; i < len; ++i) {
      (uint256 k, ) = list.get(i);
      if (k == key) break;
    }
    vm.stopSnapshotGas();
    return i < len ? i : type(uint256).max;
  }

  function _getLabel(string memory key) private view returns (string memory) {
    return string.concat(snapshotLabel, key);
  }
}

/// @dev run with `--isolate` to cool sload, or wait for `vm.cool` https://github.com/foundry-rs/foundry/pull/5852
/// replace `vm.randomUint()` with a seeded pseudo-random generator or seeded fuzz for deterministic snapshots.
contract PackedSortedListTest is Test {
  uint256 internal constant MAX_KEY = PackedSortedList._KEY_MASK;
  uint256 internal constant MAX_VALUE = PackedSortedList._VALUE_MASK;

  IWrapper internal w;
  uint256 internal seenCacheId;

  modifier resetStateAfterRun() {
    uint256 snapshotId = vm.snapshotState();
    _;
    vm.revertToState(snapshotId);
  }

  function setUp() public {
    w = IWrapper(address(new Wrapper()));
    w.setSnapshotLabel(_keyLabel(10));
  }

  function test_insert() public {
    _runInsert(10);
    _runInsert(50);
    _runInsert(100);
  }

  /// forge-config: default.fuzz.runs = 256
  function test_fuzz_insert(uint256[] memory pairs) public {
    for (uint i; i < pairs.length; ++i) {
      (uint256 key, uint256 value) = PackedSortedList.unpack(uint32(pairs[i]));
      key = bound(key, 0, MAX_KEY);
      value = bound(value, 0, MAX_VALUE);
      w.insert(key, value);
    }
    _assertSortedByValue();
  }

  function test_insert_revertsWith_maxKeyOrValueExceeded() public {
    uint256 key = vm.randomUint(MAX_KEY, type(uint256).max);
    uint256 value = vm.randomUint(MAX_VALUE, type(uint256).max);

    vm.expectRevert(Errors.MaxKeyExceeded.selector);
    w.insert(key, value);
    vm.stopSnapshotGas();
    vm.expectRevert(Errors.MaxValueExceeded.selector);
    w.insert(1, value);
    vm.stopSnapshotGas();
  }

  function test_remove() public {
    _runRemove(10);
    _runRemove(50);
    _runRemove(100);
  }

  function test_update() public {
    _runUpdate(10);
    _runUpdate(50);
    _runUpdate(100);
  }

  function _runUpdate(uint256 count) internal resetStateAfterRun {
    w.setSnapshotLabel(_keyLabel(count));
    _insertUpTo(count);

    uint256[4] memory keysToUpdate = [count - 1, 1, count / 2 + 1, count / 3];
    for (uint256 i; i < keysToUpdate.length; ++i) {
      (uint256 key, uint256 value) = w.get(w.searchForIndex(keysToUpdate[i]));
      assertEq(key, keysToUpdate[i]);

      uint256 newValue = vm.randomUint(0, MAX_VALUE);
      w.updateKey(key, newValue);

      (key, value) = w.get(w.searchForIndex(keysToUpdate[i]));
      assertEq(value, newValue);
      assertEq(key, keysToUpdate[i]);

      _assertSortedByValueAndNoKeyDuplication();
    }
  }

  function _runInsert(uint256 count) internal resetStateAfterRun {
    w.setSnapshotLabel(_keyLabel(count));
    _insertUpTo(count);
    w.loop();
    _assertSortedByValueAndNoKeyDuplication();
    // if (count == 10) _log();
  }

  function _runRemove(uint256 count) internal resetStateAfterRun {
    w.setSnapshotLabel(_keyLabel(count));
    _insertUpTo(count);

    uint256[4] memory keysToRemove = [count - 1, 1, count / 2 + 1, count / 3];
    for (uint256 i; i < keysToRemove.length; ++i) {
      uint256 key = keysToRemove[i];
      assertNotEq(w.searchForIndex(key), type(uint256).max);
      w.removeKey(key);
      assertEq(w.searchForIndex(key), type(uint256).max);
      assertEq(w.length(), count - i - 1);
      _assertSortedByValueAndNoKeyDuplication();
    }
  }

  function _insertUpTo(uint256 count) internal {
    for (uint256 i; i < count; ++i) {
      uint256 value = vm.randomUint(0, MAX_VALUE);
      w.insert(i, value);
    }
  }

  function _assertSortedByValueAndNoKeyDuplication() internal {
    _assertSortedByValue();
    _assertNoKeyDuplication();
  }

  function _assertSortedByValue() internal {
    uint256 prevValue;
    for (uint256 i; i < w.length(); ++i) {
      (, uint256 value) = w.get(i);
      assertLe(prevValue, value);
      prevValue = value;
    }
  }

  function _assertNoKeyDuplication() internal {
    seenCacheId++;
    for (uint256 i; i < w.length(); ++i) {
      (uint256 key, ) = w.get(i);
      _markKeyAsSeen(key);
    }
  }

  function _markKeyAsSeen(uint256 key) internal {
    bool seen;
    bytes32 cacheSlot = keccak256(abi.encode(seenCacheId, key));
    assembly {
      seen := sload(cacheSlot)
      sstore(cacheSlot, 1)
    }
    assertFalse(seen, string.concat('key duplicated - ', vm.toString(key)));
  }

  function _keyLabel(uint256 keyCount) internal pure virtual returns (string memory) {
    return string.concat(vm.toString(keyCount), '_keys: ');
  }

  function _log() internal {
    uint256 i;
    uint256 len = w.length();
    while (i < len) {
      (uint256 key, uint256 value) = w.get(i++);
      console.log(key, value);
    }
  }
}
