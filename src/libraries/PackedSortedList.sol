// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Errors} from 'src/libraries/helpers/Errors.sol';

library PackedSortedList {
  using PackedSortedList for List;

  /// @dev we use a static array to save on dynamic array slot computation cost.
  struct List {
    uint256[150] slots;
    uint256 count;
  }

  uint256 internal constant _ITEM_BITS = 10;
  /// @dev 25 pairs per slot, 6 bit remaining in slot. can be re-used for b+ tree update optimization
  uint256 internal constant _ITEMS_PER_SLOT = 256 / _ITEM_BITS;

  uint256 internal constant _ITEM_MASK = (1 << _ITEM_BITS) - 1;

  /// @dev `item` uniqueness constraint is not checked.
  function insert(List storage list, uint256 item) internal {
    uint256 index = list.search(item);
    uint256 newCount = ++list.count;

    // alternate approach #A: right shift to move multiple pairs together (loop while last pair doesn't need next slot)
    for (uint256 i = newCount - 1; i > index; --i) {
      uint256 previousItem = list.get(i - 1); // can be optimized since `_getSlotIndexAndOffset` calc is more obvious here
      list.set(i, previousItem);
    }
    list.set(index, item);
  }

  function remove(List storage list, uint256 index) internal {
    require(index < list.count, Errors.IndexOutOfBounds());
    uint256 newCount = --list.count;
    // alternate approach #A isn't suitable since with left shifting, next slot first is needed
    // alternate approach #B: null/sentinel this slot and ignore null slots in `get` (added loop in each `get` - each null slot's value can store offset till next valid value)
    for (uint256 i = index; i < newCount; ++i) {
      uint256 nextItem = list.get(i + 1);
      list.set(i, nextItem);
    }
  }

  function update(List storage list, uint256 index, uint256 value) internal {
    require(index < list.count, Errors.IndexOutOfBounds());

    // optimize: do in place if new value maintains sorted order else do the following
    list.remove(index);
    list.insert(value);
  }

  function search(List storage list, uint256 item) internal view returns (uint256) {
    uint256 low = 0;
    uint256 high = list.count;
    while (low < high) {
      uint256 mid = (low + high) >> 1;
      if (list.get(mid) < item) low = mid + 1;
      else high = mid;
    }
    return low;
  }

  function length(List storage list) internal view returns (uint256) {
    return list.count;
  }

  function get(List storage list, uint256 index) internal view returns (uint256) {
    require(index < list.count, Errors.IndexOutOfBounds());
    (uint256 slotIndex, uint256 offset) = _getSlotIndexAndOffset(index);
    return (list.slots[slotIndex] >> offset) & _ITEM_MASK;
  }

  function unsafeGet(List storage list, uint256 index) internal view returns (uint256) {
    unchecked {
      (uint256 slotIndex, uint256 offset) = _getSlotIndexAndOffset(index);
      return (list.slots[slotIndex] >> offset) & _ITEM_MASK;
    }
  }

  function set(List storage list, uint256 index, uint256 item) internal {
    require(item <= _ITEM_MASK, Errors.ItemOverflow());
    (uint256 slotIndex, uint256 offset) = _getSlotIndexAndOffset(index);
    // expand slot incase of dynamic array
    require(slotIndex < list.slots.length, Errors.IndexOutOfBounds());

    uint256 mask = ~(_ITEM_MASK << offset);
    list.slots[slotIndex] = (list.slots[slotIndex] & mask) | (item << offset);
  }

  function _getSlotIndexAndOffset(uint256 index) private pure returns (uint256, uint256) {
    uint256 slotIndex = index / _ITEMS_PER_SLOT;
    uint256 offset = (index % _ITEMS_PER_SLOT) * _ITEM_BITS;
    return (slotIndex, offset);
  }
}
