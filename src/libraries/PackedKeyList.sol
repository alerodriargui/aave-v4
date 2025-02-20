// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Errors} from 'src/libraries/helpers/Errors.sol';

/// @notice Keys are stored (& packed)
library PackedKeyList {
  using PackedKeyList for KeyList;
  using PackedKeyList for ValueMap;

  /// @dev we use a static array to save on dynamic array slot computation cost.
  struct KeyList {
    uint256[150] slots;
    uint256 count;
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

  function push(KeyList storage list, ValueMap storage map, uint256 value) internal {
    uint256 key = map.incrementKey();
    uint256 index = list.count++;

    map.store(key, value);
    list.set(index, key);
  }

  function pop(KeyList storage list, ValueMap storage map) internal {
    uint256 index = list.count - 1;
    map.store(list.getKey(index), 0);
    --list.count;
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
