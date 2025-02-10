// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Errors} from 'src/libraries/helpers/Errors.sol';

/// @dev sorted by value in ascending order (key ignored).
/// @dev `update` assumes `key`s remain static, & hence only updates value.
library PackedSortedKVList {
  /// @dev we use a static array to save on dynamic array slot computation cost.
  // ? (can it be made dynamic since cost is only on `update` & `insert`)
  struct List {
    uint256[150] slots;
    uint256 count; /// @dev don't maintain count for re-usability.
  }

  uint256 internal constant _KEY_BITS = 7;
  uint256 internal constant _VALUE_BITS = 10;
  uint256 internal constant _PAIR_BITS = _KEY_BITS + _VALUE_BITS;
  /// @dev 15 pairs per slot, 1 bit remaining in slot. can be re-used for b+ tree update optimization
  uint256 internal constant _PAIRS_PER_SLOT = 256 / _PAIR_BITS;

  /// @dev bit masks (aka ceiling values)
  uint256 internal constant _KEY_MASK = (1 << _KEY_BITS) - 1;
  uint256 internal constant _VALUE_MASK = (1 << _VALUE_BITS) - 1;
  uint256 internal constant _PAIR_MASK = (1 << _PAIR_BITS) - 1;

  /// @notice get packed (`key`, `value`) pair at `index` in `list`.
  function get(List storage list, uint256 index) internal view returns (uint256, uint256) {
    unchecked {
      (uint256 key, uint256 value) = _unpack(_get(list, index));
      return (key, value);
    }
  }

  /// @dev `key` uniqueness constraint is not checked.
  function insert(List storage list, uint256 key, uint256 value) internal {
    uint256 index = search(list, value);
    uint256 newCount = ++list.count;

    // alternate approach #A: right shift to move multiple pairs together (loop while last pair doesn't need next slot)
    for (uint256 i = newCount - 1; i > index; --i) {
      uint32 prevPair = _get(list, i - 1); // can be optimized since `_getSlotIndexAndOffset` calc is more obvious now
      _set(list, i, prevPair);
    }
    _set(list, index, _pack(key, value));
  }

  function remove(List storage list, uint256 index) internal {
    require(index < list.count, Errors.IndexOutOfBounds()); // ? do outside
    uint256 newCount = --list.count;
    // alternate approach #A isn't suitable since with left shifting, next slot first is needed
    // alternate approach #B: null/sentinel this slot and ignore null slots in `get` (added loop in each `get` - each null slot's value can store offset till next valid value)
    for (uint256 i = index; i < newCount; ++i) {
      uint32 nextPair = _get(list, i + 1);
      _set(list, i, nextPair);
    }
  }

  /// @notice assumes `key` remains static, and only updates `value` at `index`.
  /// @dev second parameter is *not* `key`, search for `key` before.
  // ? maybe use named uint's or uint16's for (key, value) to avoid confusion, enforce w compiler checks
  function update(List storage list, uint256 index, uint256 value) internal {
    require(index < list.count, Errors.IndexOutOfBounds()); // ?  do outside
    uint32 pair = _get(list, index);
    (uint256 key, ) = _unpack(pair);

    // optimize: do in place if new value maintains sorted order else do the following
    remove(list, index);
    insert(list, key, value);
  }

  /// @dev search by `value` since `list` is sorted by `value` only.
  function search(List storage list, uint256 value) internal view returns (uint256) {
    uint256 low = 0;
    uint256 high = list.count;
    while (low < high) {
      uint256 mid = (low + high) >> 1;
      if (_getValue(list, mid) < value) low = mid + 1;
      else high = mid;
    }
    return low;
  }

  function length(List storage list) internal view returns (uint256) {
    return list.count;
  }

  function unpack(uint32 pair) internal pure returns (uint256 key, uint256 value) {
    return _unpack(pair);
  }

  /// @dev index bound checks are expected to be done before.
  function _get(List storage list, uint256 index) private view returns (uint32) {
    (uint256 slotIndex, uint256 offset) = _getSlotIndexAndOffset(index);
    return uint32((list.slots[slotIndex] >> offset) & _PAIR_MASK);
  }

  function _getValue(List storage list, uint256 index) private view returns (uint256) {
    (uint256 slotIndex, uint256 offset) = _getSlotIndexAndOffset(index);
    return uint32((list.slots[slotIndex] >> offset) & _VALUE_MASK);
  }

  function _set(List storage list, uint256 index, uint32 pair) internal {
    (uint256 slotIndex, uint256 offset) = _getSlotIndexAndOffset(index);
    // expand slot incase of dynamic array
    require(slotIndex < list.slots.length, Errors.IndexOutOfBounds());

    uint256 mask = ~(_PAIR_MASK << offset);
    list.slots[slotIndex] = (list.slots[slotIndex] & mask) | (uint256(pair) << offset);
  }

  function _pack(uint256 key, uint256 value) private pure returns (uint32) {
    // ? ceil checks can be moved?
    require(key <= _KEY_MASK, Errors.MaxKeyExceeded());
    require(value <= _VALUE_MASK, Errors.MaxValueExceeded());
    return uint32((key << _VALUE_BITS) | value);
  }

  function _unpack(uint32 pair) private pure returns (uint256 key, uint256 value) {
    key = uint256(pair >> _VALUE_BITS);
    value = uint256(pair & uint32(_VALUE_MASK));
  }

  function _getSlotIndexAndOffset(
    uint256 index
  ) private pure returns (uint256 slotIndex, uint256 offset) {
    slotIndex = index / _PAIRS_PER_SLOT;
    offset = (index % _PAIRS_PER_SLOT) * _PAIR_BITS;
  }
}
