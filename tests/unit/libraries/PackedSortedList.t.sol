// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.0;

// import {Test, Vm, console2 as console} from 'forge-std/Test.sol';

// import {Errors} from 'src/libraries/helpers/Errors.sol';
// import {PackedSortedList} from 'src/libraries/PackedSortedList.sol';

// interface IWrapper {
//   function insert(uint256 item) external;
//   function get(uint256 index) external returns (uint256 item);
//   function remove(uint256 index) external;
//   function update(uint256 index, uint256 item) external;
//   function length() external view returns (uint256 length);
//   // for gas profiling
//   function loop() external;
//   function setSnapshotLabel(string memory) external;
// }

// contract Wrapper is IWrapper {
//   using PackedSortedList for PackedSortedList.List;
//   PackedSortedList.List internal list;
//   string internal snapshotLabel;

//   // @dev We do not use `snapGasLastCall` since we want this library to remain internal.
//   Vm internal constant vm = Vm(address(uint160(uint256(keccak256('hevm cheat code')))));

//   function get(uint256 index) external returns (uint256) {
//     vm.startSnapshotGas(_getLabel('get'));
//     uint256 item = list.unsafeGet(index);
//     vm.stopSnapshotGas();
//     return item;
//   }

//   function insert(uint256 item) external {
//     vm.startSnapshotGas(_getLabel('insert'));
//     list.insert(item);
//     vm.stopSnapshotGas();
//   }

//   function remove(uint256 index) external {
//     vm.startSnapshotGas(_getLabel('remove'));
//     list.remove(index);
//     vm.stopSnapshotGas();
//   }

//   function update(uint256 index, uint256 item) external {
//     vm.startSnapshotGas(_getLabel('update'));
//     list.update(index, item);
//     vm.stopSnapshotGas();
//   }

//   function length() external view returns (uint256) {
//     return list.length();
//   }

//   /// @dev for gas profiling, it's how this will be used in spoke
//   function loop() external {
//     uint256 idx;
//     vm.startSnapshotGas(_getLabel('loop'));
//     uint256 len = list.length();
//     while (idx < len) {
//       list.unsafeGet(idx);
//       idx++;
//     }
//     vm.stopSnapshotGas();
//   }

//   /// @dev for gas profiling
//   function setSnapshotLabel(string memory _label) external {
//     snapshotLabel = _label;
//   }

//   function _getLabel(string memory key) private view returns (string memory) {
//     return string.concat(snapshotLabel, key);
//   }
// }

// /// @dev run with `--isolate` to cool sload, or wait for `vm.cool` https://github.com/foundry-rs/foundry/pull/5852
// contract PackedSortedListTest is Test {
//   uint256 internal constant MAX_ITEM = PackedSortedList._ITEM_MASK;
//   uint256 internal seed;

//   IWrapper internal w;

//   modifier resetStateAfterRun() {
//     uint256 snapshotId = vm.snapshotState();
//     _;
//     vm.revertToState(snapshotId);
//   }

//   function setUp() public {
//     w = IWrapper(address(new Wrapper()));
//     w.setSnapshotLabel(_keyLabel(10));
//   }

//   function test_insert() public {
//     _runInsert(10);
//     _runInsert(50);
//     _runInsert(100);
//   }

//   /// forge-config: default.fuzz.runs = 256
//   function test_fuzz_insert(uint256[] memory items) public {
//     for (uint256 i; i < items.length; ++i) {
//       w.insert(bound(items[i], 0, MAX_ITEM));
//       _assertSorted();
//     }
//   }

//   function test_insert_revertsWith_maxKeyOrValueExceeded(uint256 item) public {
//     vm.expectRevert(Errors.ItemOverflow.selector);
//     w.insert(bound(item, MAX_ITEM + 1, type(uint256).max));
//     vm.stopSnapshotGas();
//   }

//   function test_remove() public {
//     _runRemove(10);
//     _runRemove(50);
//     _runRemove(100);
//   }

//   function test_update() public {
//     _runUpdate(10);
//     _runUpdate(50);
//     _runUpdate(100);
//   }

//   function _runUpdate(uint256 count) internal resetStateAfterRun {
//     w.setSnapshotLabel(_keyLabel(count));
//     _insertUpTo(count);

//     uint256[4] memory idxToUpdate = [count - 1, 1, count / 2 + 1, count / 3];
//     for (uint256 i; i < idxToUpdate.length; ++i) {
//       uint256 newItem = vm.randomUint(0, MAX_ITEM);
//       w.update(idxToUpdate[i], newItem);

//       assertEq(w.get(idxToUpdate[i]), newItem);
//       _assertSorted();
//     }
//   }

//   function _runInsert(uint256 count) internal resetStateAfterRun {
//     w.setSnapshotLabel(_keyLabel(count));
//     _insertUpTo(count);
//     w.loop();
//     _assertSorted();
//     if (count == 10) _log();
//   }

//   function _runRemove(uint256 count) internal resetStateAfterRun {
//     w.setSnapshotLabel(_keyLabel(count));
//     _insertUpTo(count);

//     uint256[4] memory idxToRemove = [count - 1, 1, count / 2 + 1, count / 3];
//     for (uint256 i; i < idxToRemove.length; ++i) {
//       uint256 itemToRemove = w.get(idxToRemove[i]);
//       uint256 frequency = _getFrequency(itemToRemove);

//       w.remove(idxToRemove[i]);

//       assertEq(_getFrequency(itemToRemove), frequency - 1);
//       assertEq(w.length(), count - i - 1);
//       _assertSorted();
//     }
//   }

//   function _insertUpTo(uint256 count) internal {
//     for (uint256 i; i < count; ++i) {
//       w.insert(vm.randomUint(0, MAX_ITEM));
//       _assertSorted();
//     }
//   }

//   function _assertSorted() internal {
//     uint256 prevItem;
//     for (uint256 i; i < w.length(); ++i) {
//       uint256 item = w.get(i);
//       assertLe(prevItem, item);
//       prevItem = item;
//     }
//   }

//   // we use this over `vm.randomUint()` for deterministic snapshots.
//   function _randomUint(uint256 max) internal returns (uint256) {
//     return uint256(keccak256(abi.encode(seed++))) % max;
//   }

//   function _getFrequency(uint256 item) internal returns (uint256) {
//     uint256 count;
//     uint256 len = w.length();
//     for (uint256 i; i < len; ++i) if (w.get(i) == item) count++;
//     return count;
//   }

//   function _keyLabel(uint256 keyCount) internal pure virtual returns (string memory) {
//     return string.concat(vm.toString(keyCount), '_keys: ');
//   }

//   function _log() internal {
//     uint256 i;
//     uint256 len = w.length();
//     while (i < len) {
//       console.log(i, w.get(i++));
//     }
//   }
// }
