// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Errors} from 'src/libraries/helpers/Errors.sol';

/// @notice Keys are stored (& packed) in ascending order of their associated value, and maintained in contiguous storage
/// to be iterable.
library PackedSortedKeyList {
  using PackedSortedKeyList for KeyList;
  using PackedSortedKeyList for ValueMap;

  /// @dev we use a static array to save on dynamic array slot computation cost.
  struct KeyList {
    uint256[150] slots;
    uint256 count;
    address slotsAddress;
  }
  struct ValueMap {
    mapping(uint256 key => uint256 value) keyToValue;
    uint256 currentKey; // monotonically increasing
  }
  uint256 internal constant _SLOT_BITS = 256; // evm limit
  uint256 internal constant _KEY_BITS = 10;
  /// @dev 25 keys per slot, 6 bits remaining in slot. can be re-used for b+ tree update optimization
  uint256 internal constant _KEYS_PER_SLOT = _SLOT_BITS / _KEY_BITS;
  uint256 internal constant _KEY_MASK = (1 << _KEY_BITS) - 1;

  /// @dev SlotIndex cache
  uint256 internal constant _CACHE_BITS = _SLOT_BITS % _KEY_BITS;
  uint256 internal constant _CACHE_OFFSET = _SLOT_BITS - _CACHE_BITS;
  uint256 internal constant _CACHE_MASK = (1 << _CACHE_BITS) - 1;

  function insert(KeyList storage list, ValueMap storage map, uint256 value) internal {
    _insertKey(list, map, map.incrementKey(), value);
  }

  function remove(KeyList storage list, ValueMap storage map, uint256 index) internal {
    require(index < list.count, Errors.IndexOutOfBounds());
    map.store(list.getKey(index), 0);

    uint256 newCount = list.count - 1;
    // alternate approach #A isn't suitable since with left shifting, next slot first is needed
    // alternate approach #B: null/sentinel this slot and ignore null slots in `get` (added loop in each `get` - each null slot's value can store offset till next valid value)
    for (uint256 i = index; i < newCount; ++i) {
      list.set(i, list.getKey(i + 1));
    }
    --list.count;
  }

  function update(
    KeyList storage list,
    ValueMap storage map,
    uint256 index, // of `key` to update
    uint256 value
  ) internal {
    require(index < list.count, Errors.IndexOutOfBounds());
    // optimize: do in place if new value maintains sorted order else do the following
    uint256 key = list.getKey(index);

    list.remove(map, index);
    _insertKey(list, map, key, value);
  }

  /// @return Index at which `value` should be inserted to maintain sorted order.
  function search(
    KeyList storage list,
    ValueMap storage map,
    uint256 value
  ) internal view returns (uint256) {
    uint256 low = 0;
    uint256 high = list.count;
    while (low < high) {
      uint256 mid = (low + high) >> 1;
      if (map.getValue(list.getKey(mid)) < value) low = mid + 1;
      else high = mid;
    }
    return low;
  }

  function length(KeyList storage list) internal view returns (uint256) {
    return list.count;
  }

  function getKey(KeyList storage list, uint256 index) internal view returns (uint256) {
    require(index < list.count, Errors.IndexOutOfBounds());
    (uint256 slotIndex, uint256 offset) = _getSlotIndexAndOffset(index);
    return (list.getSlotsAt(slotIndex) >> offset) & _KEY_MASK;
  }

  function unsafeGetKey(KeyList storage list, uint256 index) internal view returns (uint256) {
    unchecked {
      (uint256 slotIndex, uint256 offset) = _getSlotIndexAndOffset(index);
      return (list.getSlotsAt(slotIndex) >> offset) & _KEY_MASK;
    }
  }

  // @dev index bound checks are omitted for gas efficiency.
  function getFromCache(
    KeyList storage list,
    uint256 cache,
    uint256 index
  ) internal view returns (uint256, uint256) {
    unchecked {
      (uint256 slotIndex, uint256 offset) = _getSlotIndexAndOffset(index);
      if (cache == 0 || ((cache >> _CACHE_OFFSET) != slotIndex)) {
        cache = list.getSlotsAt(slotIndex);
      }
      return (cache, (cache >> offset) & _KEY_MASK);
    }
  }

  function hasIndex(uint256 cache, uint256 index) internal pure returns (bool) {
    unchecked {
      return (cache >> _CACHE_OFFSET) == index / _KEYS_PER_SLOT; // cachedSlotIndex == slotIndex
    }
  }

  function extractKey(uint256 cache, uint256 index) internal pure returns (uint256) {
    unchecked {
      return (cache >> ((index % _KEYS_PER_SLOT) * _KEY_BITS)) & _KEY_MASK; // cache >> offset & keyMask
    }
  }

  function getWithCache(
    KeyList storage list,
    uint256 index
  ) internal view returns (uint256, uint256) {
    unchecked {
      (uint256 slotIndex, uint256 offset) = _getSlotIndexAndOffset(index);
      uint256 cache = list.getSlotsAt(slotIndex);
      return (cache, (cache >> offset) & _KEY_MASK);
    }
  }

  function set(KeyList storage list, uint256 index, uint256 key) internal {
    require(key < _KEY_MASK, Errors.ItemOverflow());
    (uint256 slotIndex, uint256 offset) = _getSlotIndexAndOffset(index);
    // expand slot incase of dynamic array
    require(slotIndex < list.getSlotsLength(), Errors.IndexOutOfBounds());

    uint256 slot = list.getSlotsAt(slotIndex);
    if (slot == 0) {
      // if this is the first entry, encode slotIndex at cache
      // slot = (slot & ~(_CACHE_MASK << _CACHE_OFFSET)) | (slotIndex << _CACHE_OFFSET);
      slot = _maskValue(slot, _CACHE_MASK, slotIndex, _CACHE_OFFSET);
    }

    // list.writeToSlotsAt(slotIndex, (slot & ~(_KEY_MASK << offset)) | (key << offset));
    list.writeToSlotsAt(slotIndex, _maskValue(slot, _KEY_MASK, key, offset));
  }

  function _maskValue(
    uint256 page,
    uint256 mask,
    uint256 value,
    uint256 offset
  ) internal pure returns (uint256) {
    return (page & ~(mask << offset)) | (value << offset);
  }

  function _getSlotIndexAndOffset(uint256 index) private pure returns (uint256, uint256) {
    uint256 slotIndex = index / _KEYS_PER_SLOT;
    uint256 offset = (index % _KEYS_PER_SLOT) * _KEY_BITS;
    return (slotIndex, offset);
  }

  function _insertKey(
    KeyList storage list,
    ValueMap storage map,
    uint256 key,
    uint256 value
  ) private {
    map.store(key, value);

    uint256 index = list.search(map, value);
    uint256 newCount = ++list.count;

    // optimize: right shift to move multiple pairs together (loop while last pair doesn't need next slot)
    for (uint256 i = newCount - 1; i > index; --i) {
      list.set(i, list.getKey(i - 1));
    }
    list.set(index, key);
  }

  /// @dev To override based on `keyToValue` mapping implementation
  function store(ValueMap storage map, uint256 key, uint256 value) internal {
    map.keyToValue[key] = value;
  }

  function getValue(ValueMap storage map, uint256 key) internal view returns (uint256) {
    return map.keyToValue[key];
  }

  function incrementKey(ValueMap storage map) internal returns (uint256 key) {
    require((key = map.currentKey++) < _KEY_MASK, Errors.ItemOverflow());
  }

  /// @dev Override with SSTORE2
  function getSlotsAt(KeyList storage list, uint256 index) internal view returns (uint256) {
    return list.slots[index];
  }

  function writeToSlotsAt(KeyList storage list, uint256 index, uint256 value) internal {
    list.slots[index] = value;
  }

  function getSlotsLength(KeyList storage list) internal view returns (uint256) {
    return list.slots.length;
  }
}
