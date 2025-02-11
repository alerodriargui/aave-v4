// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.0;

// import {SSTORE2} from 'src/dependencies/solmate/SSTORE2.sol';
// import {Errors} from 'src/libraries/helpers/Errors.sol';

// /// @notice Keys are stored (& packed) in ascending order of their associated value, and maintained in contiguous storage
// /// to be iterable.
// library PackedSortedKeyListSstore2 {
//   using PackedSortedKeyListSstore2 for KeyList;
//   using PackedSortedKeyListSstore2 for ValueMap;

//   /// @dev we use a static array to save on dynamic array slot computation cost.
//   struct KeyList {
//     address slotsPointer;
//     uint256 count;
//   }
//   struct ValueMap {
//     mapping(uint256 key => uint256 value) keyToValue;
//     uint256 currentKey; // monotonically increasing
//   }

//   uint256 internal constant _KEY_BITS = 10;
//   /// @dev 25 keys per slot, 6 bits remaining in slot. can be re-used for b+ tree update optimization
//   uint256 internal constant _KEYS_PER_SLOT = 256 / _KEY_BITS;
//   uint256 internal constant _KEY_MASK = (1 << _KEY_BITS) - 1;

//   function insert(KeyList storage list, ValueMap storage map, uint256 value) internal {
//     if (list.slotsPointer == address(0)) list.writeToSlotsAt(0, 0);
//     _insertKey(list, map, map.incrementKey(), value);
//   }

//   function remove(KeyList storage list, ValueMap storage map, uint256 index) internal {
//     require(index < list.count, Errors.IndexOutOfBounds());
//     map.store(list.getKey(index), 0);

//     uint256 newCount = list.count - 1;
//     // alternate approach #A isn't suitable since with left shifting, next slot first is needed
//     // alternate approach #B: null/sentinel this slot and ignore null slots in `get` (added loop in each `get` - each null slot's value can store offset till next valid value)
//     for (uint256 i = index; i < newCount; ++i) {
//       list.set(i, list.getKey(i + 1));
//     }
//     --list.count;
//   }

//   function update(
//     KeyList storage list,
//     ValueMap storage map,
//     uint256 index, // of `key` to update
//     uint256 value
//   ) internal {
//     require(index < list.count, Errors.IndexOutOfBounds());
//     // optimize: do in place if new value maintains sorted order else do the following
//     uint256 key = list.getKey(index);

//     list.remove(map, index);
//     _insertKey(list, map, key, value);
//   }

//   /// @return Index at which `value` should be inserted to maintain sorted order.
//   function search(
//     KeyList storage list,
//     ValueMap storage map,
//     uint256 value
//   ) internal view returns (uint256) {
//     uint256 low = 0;
//     uint256 high = list.count;
//     while (low < high) {
//       uint256 mid = (low + high) >> 1;
//       if (map.getValue(list.getKey(mid)) < value) low = mid + 1;
//       else high = mid;
//     }
//     return low;
//   }

//   function length(KeyList storage list) internal view returns (uint256) {
//     return list.count;
//   }

//   function getKey(KeyList storage list, uint256 index) internal view returns (uint256) {
//     require(index < list.count, Errors.IndexOutOfBounds());
//     (uint256 slotIndex, uint256 offset) = _getSlotIndexAndOffset(index);
//     return (list.getSlotsAt(slotIndex) >> offset) & _KEY_MASK;
//   }

//   function unsafeGetKey(KeyList storage list, uint256 index) internal view returns (uint256) {
//     unchecked {
//       (uint256 slotIndex, uint256 offset) = _getSlotIndexAndOffset(index);
//       return (list.getSlotsAt(slotIndex) >> offset) & _KEY_MASK;
//     }
//   }

//   function set(KeyList storage list, uint256 index, uint256 key) internal {
//     require(key < _KEY_MASK, Errors.ItemOverflow());
//     (uint256 slotIndex, uint256 offset) = _getSlotIndexAndOffset(index);
//     // expand slot incase of dynamic array
//     require(slotIndex < list.getSlotsLength(), Errors.IndexOutOfBounds());

//     uint256 mask = ~(_KEY_MASK << offset);
//     list.writeToSlotsAt(slotIndex, (list.getSlotsAt(slotIndex) & mask) | (key << offset));
//   }

//   function _getSlotIndexAndOffset(uint256 index) private pure returns (uint256, uint256) {
//     uint256 slotIndex = index / _KEYS_PER_SLOT;
//     uint256 offset = (index % _KEYS_PER_SLOT) * _KEY_BITS;
//     return (slotIndex, offset);
//   }

//   function _insertKey(
//     KeyList storage list,
//     ValueMap storage map,
//     uint256 key,
//     uint256 value
//   ) private {
//     map.store(key, value);

//     uint256 index = list.search(map, value);
//     uint256 newCount = ++list.count;

//     // optimize: right shift to move multiple pairs together (loop while last pair doesn't need next slot)
//     for (uint256 i = newCount - 1; i > index; --i) {
//       list.set(i, list.getKey(i - 1));
//     }
//     list.set(index, key);
//   }

//   /// @dev To override based on `keyToValue` mapping implementation
//   function store(ValueMap storage map, uint256 key, uint256 value) internal {
//     map.keyToValue[key] = value;
//   }

//   function getValue(ValueMap storage map, uint256 key) internal view returns (uint256) {
//     return map.keyToValue[key];
//   }

//   function incrementKey(ValueMap storage map) internal returns (uint256 key) {
//     require((key = map.currentKey++) < _KEY_MASK, Errors.ItemOverflow());
//   }

//   // function getSlotsAt(KeyList storage list, uint256 index) internal view returns (uint256) {
//   //   return SSTORE2.read(list.slotsAddress, index * 32);
//   // }

//   // function writeToSlotsAt(KeyList storage list, uint256 index, uint256 value) internal {
//   //   uint256 count = list.getSlotsLength();
//   //   bytes memory currentData = new bytes(count * 32);
//   //   for (uint256 i; i < count; i += 32) {
//   //     currentData[i:i + 32] = list.getSlotsAt(i / 32);
//   //   }
//   //   SSTORE2.write(list.slotsAddress, index * 32, value);
//   //   // list.slots[index] = value;
//   // }

//   // function getSlotsLength(KeyList storage list) internal view returns (uint256) {
//   //   return SSTORE2.read(list.slotsAddress).length / 32;
//   // }

//   /**
//    * @notice Reads the uint256 value stored at the given index.
//    * @param list The KeyList storage struct.
//    * @param index The index to read (must be less than count).
//    * @return slotValue The uint256 value stored at that index.
//    */
//   function getSlotsAt(
//     KeyList storage list,
//     uint256 index
//   ) internal view returns (uint256 slotValue) {
//     require(index < list.count, 'Index out of bounds');
//     require(list.slotsPointer != address(0), 'Slots not initialized');

//     // Each slot is 32 bytes. Retrieve bytes for the target slot:
//     // (index * 32) to ((index + 1) * 32)
//     bytes memory slotBytes = SSTORE2.read(list.slotsPointer, index * 32, (index + 1) * 32);
//     assembly {
//       slotValue := mload(add(slotBytes, 32))
//     }
//   }

//   /**
//    * @notice Writes a uint256 value to a given index.
//    * @dev If index equals the current count, this function appends a new slot.
//    *      If index is less than count, it updates an existing slot.
//    *      Index must not be greater than count.
//    *      Every write creates a new SSTORE2 pointer.
//    * @param list The KeyList storage struct.
//    * @param index The index to write (allowed values: 0 <= index <= count).
//    * @param value The uint256 value to write.
//    */
//   function writeToSlotsAt(KeyList storage list, uint256 index, uint256 value) internal {
//     require(index <= list.count, 'Index must be at most current count (append or update)');
//     bytes memory data;

//     if (list.slotsPointer == address(0)) {
//       // No blob exists yet, so count must be 0 and data is empty.
//       require(list.count == 0, 'Data missing with nonzero count');
//       data = new bytes(0);
//     } else {
//       // Retrieve the existing blob.
//       data = SSTORE2.read(list.slotsPointer);
//     }

//     if (index == list.count) {
//       // Append operation.
//       uint256 newCount = list.count + 1;
//       // Allocate a new bytes array to hold the existing slots plus one extra slot.
//       bytes memory newData = new bytes(newCount * 32);
//       if (data.length > 0) {
//         // Copy the old data into the new array.
//         assembly {
//           // data and newData's first 32 bytes store their length; skip those.
//           let src := add(data, 32)
//           let dst := add(newData, 32)
//           let len := mload(data) // should equal list.count * 32
//           // Copy in 32-byte chunks.
//           for {
//             let offset := 0
//           } lt(offset, len) {
//             offset := add(offset, 32)
//           } {
//             mstore(add(dst, offset), mload(add(src, offset)))
//           }
//         }
//       }
//       uint256 currentCount = list.count;
//       // Write the new value into the appended slot.
//       assembly {
//         mstore(add(newData, add(32, mul(currentCount, 32))), value)
//       }
//       // Write the new blob via SSTORE2 and update the count.
//       list.slotsPointer = SSTORE2.write(newData);
//       list.count = newCount;
//     } else {
//       // Update operation: index < list.count.
//       require(data.length == list.count * 32, 'Data length mismatch');
//       assembly {
//         // Compute the position within the bytes array (skip the first 32 bytes for the length).
//         let pos := add(data, add(32, mul(index, 32)))
//         mstore(pos, value)
//       }
//       // Write the updated blob.
//       list.slotsPointer = SSTORE2.write(data);
//     }
//   }

//   /**
//    * @notice Returns the number of slots currently stored.
//    * @param list The KeyList storage struct.
//    * @return The count of slots.
//    */
//   function getSlotsLength(KeyList storage list) internal view returns (uint256) {
//     return list.count;
//   }

//   // function getSlotsAt(
//   //   KeyList storage list,
//   //   uint256 index
//   // ) internal view returns (uint256 slotValue) {
//   //   bytes memory slotBytes = SSTORE2.read(list.slotsPointer, index * 32, (index + 1) * 32);
//   //   // cast value to uint256, cheaper than abi.decode
//   //   assembly ('memory-safe') {
//   //     slotValue := mload(add(slotBytes, 32))
//   //   }
//   // }

//   // function writeToSlotsAt(KeyList storage list, uint256 index, uint256 value) internal {
//   //   bytes memory data = list.slotsPointer == address(0)
//   //     ? new bytes(0)
//   //     : SSTORE2.read(list.slotsPointer);
//   //   uint256 currentCount = list.count;

//   //   if (index == currentCount) {
//   //     uint256 newCount = currentCount + 1;
//   //     bytes memory newData = new bytes(newCount * 32);
//   //     if (data.length > 0) {
//   //       // todo: do this in place and use memcopy
//   //       assembly {
//   //         let src := add(data, 32)
//   //         let dst := add(newData, 32)
//   //         let len := mload(data)
//   //         for {
//   //           let offset := 0
//   //         } lt(offset, len) {
//   //           offset := add(offset, 32)
//   //         } {
//   //           mstore(add(dst, offset), mload(add(src, offset)))
//   //         }
//   //       }
//   //     }
//   //     assembly {
//   //       mstore(add(newData, add(32, mul(currentCount, 32))), value)
//   //     }
//   //     list.slotsPointer = SSTORE2.write(newData);
//   //     list.count = newCount;
//   //   } else {
//   //     assembly {
//   //       let pos := add(data, add(32, mul(index, 32)))
//   //       mstore(pos, value)
//   //     }
//   //     list.slotsPointer = SSTORE2.write(data);
//   //   }
//   // }

//   // function getSlotsLength(KeyList storage list) internal view returns (uint256) {
//   //   return list.count;
//   // }
// }

// pragma solidity ^0.8.0;

// import {SSTORE2} from 'src/dependencies/solmate/SSTORE2.sol';
// import {Errors} from 'src/libraries/helpers/Errors.sol';

// /// @notice The keys (stored in packed form) are kept sorted by their associated value.
// /// Keys are stored in a contiguous SSTORE2 blob made of 256-bit words (“slots”), each packing up to 25 keys.
// library PackedSortedKeyListSstore2 {
//   using PackedSortedKeyListSstore2 for KeyList;
//   using PackedSortedKeyListSstore2 for ValueMap;

//   /// @dev The key list stores the SSTORE2 pointer and the total number of keys.
//   struct KeyList {
//     address slotsPointer; // pointer to the SSTORE2 blob (each slot is 32 bytes)
//     uint256 count; // total number of keys stored
//   }

//   /// @dev The value map stores the mapping from key => value and a counter for new keys.
//   struct ValueMap {
//     mapping(uint256 => uint256) keyToValue;
//     uint256 currentKey; // monotonically increasing counter used as the key
//   }

//   // --- Packing parameters ---
//   uint256 internal constant _KEY_BITS = 10;
//   /// @dev There are 256/_KEY_BITS keys per 256-bit word.
//   uint256 internal constant _KEYS_PER_SLOT = 256 / _KEY_BITS; // 25
//   /// @dev Mask for one key (10 bits).
//   uint256 internal constant _KEY_MASK = (1 << _KEY_BITS) - 1; // 1023

//   // --- SSTORE2 Blob Helpers ---
//   /// @notice Returns the number of 256-bit slots stored in the blob.
//   function getSlotsLength(KeyList storage list) internal view returns (uint256) {
//     if (list.count == 0) return 0;
//     // The number of slots is the ceiling of (count / _KEYS_PER_SLOT).
//     return ((list.count - 1) / _KEYS_PER_SLOT) + 1;
//   }

//   /// @notice Reads the 256-bit word (slot) at a given slot index.
//   function getSlotsAt(
//     KeyList storage list,
//     uint256 slotIndex
//   ) internal view returns (uint256 slotValue) {
//     uint256 slotsLength = getSlotsLength(list);
//     require(slotIndex < slotsLength, 'Slot index out of bounds');
//     require(list.slotsPointer != address(0), 'Slots not initialized');
//     // Each slot occupies 32 bytes. Read from byte offset (slotIndex * 32) up to ((slotIndex + 1) * 32).
//     bytes memory slotBytes = SSTORE2.read(list.slotsPointer, slotIndex * 32, (slotIndex + 1) * 32);
//     assembly {
//       slotValue := mload(add(slotBytes, 32))
//     }
//   }

//   /// @notice Writes a 256-bit word (slot) at a given slot index.
//   /// If the slot index is past the end of the current blob, the blob is extended.
//   function writeToSlotsAt(KeyList storage list, uint256 slotIndex, uint256 value) internal {
//     uint256 currentSlots = list.slotsPointer == address(0)
//       ? 0
//       : SSTORE2.read(list.slotsPointer).length / 32;
//     if (slotIndex >= currentSlots) {
//       // Extend the blob so that it has (slotIndex+1) slots.
//       uint256 newSlotsLength = slotIndex + 1;
//       bytes memory oldData = currentSlots == 0 ? new bytes(0) : SSTORE2.read(list.slotsPointer);
//       bytes memory newData = new bytes(newSlotsLength * 32);
//       // Copy over old data if present.
//       if (oldData.length > 0) {
//         assembly {
//           let src := add(oldData, 32)
//           let dst := add(newData, 32)
//           let len := mload(oldData)
//           for {
//             let i := 0
//           } lt(i, len) {
//             i := add(i, 32)
//           } {
//             mstore(add(dst, i), mload(add(src, i)))
//           }
//         }
//       }
//       // Write the new value into the proper slot.
//       assembly {
//         mstore(add(newData, add(32, mul(slotIndex, 32))), value)
//       }
//       list.slotsPointer = SSTORE2.write(newData);
//     } else {
//       // Update in-place.
//       bytes memory data = SSTORE2.read(list.slotsPointer);
//       require(data.length == currentSlots * 32, 'Data length mismatch');
//       assembly {
//         let pos := add(data, add(32, mul(slotIndex, 32)))
//         mstore(pos, value)
//       }
//       list.slotsPointer = SSTORE2.write(data);
//     }
//   }

//   /// @notice Ensures that the SSTORE2 blob has the number of slots required by list.count.
//   /// (This is useful after increasing list.count when a new slot may be needed.)
//   function _syncSlots(KeyList storage list) internal {
//     uint256 desiredSlots = list.count == 0 ? 0 : ((list.count - 1) / _KEYS_PER_SLOT) + 1;
//     uint256 currentSlots = list.slotsPointer == address(0)
//       ? 0
//       : SSTORE2.read(list.slotsPointer).length / 32;
//     if (desiredSlots > currentSlots) {
//       bytes memory oldData = currentSlots == 0 ? new bytes(0) : SSTORE2.read(list.slotsPointer);
//       bytes memory newData = new bytes(desiredSlots * 32);
//       if (oldData.length > 0) {
//         assembly {
//           let src := add(oldData, 32)
//           let dst := add(newData, 32)
//           let len := mload(oldData)
//           for {
//             let i := 0
//           } lt(i, len) {
//             i := add(i, 32)
//           } {
//             mstore(add(dst, i), mload(add(src, i)))
//           }
//         }
//       }
//       list.slotsPointer = SSTORE2.write(newData);
//     }
//   }

//   // --- Packed Key Helpers ---
//   /// @notice Returns the key at the given key index.
//   /// @dev Keys are packed 25 per slot. Compute the slot index and bit-offset.
//   function getKey(KeyList storage list, uint256 index) internal view returns (uint256) {
//     require(index < list.count, Errors.IndexOutOfBounds());
//     (uint256 slotIndex, uint256 offset) = _getSlotIndexAndOffset(index);
//     uint256 slotVal = list.getSlotsAt(slotIndex);
//     return (slotVal >> offset) & _KEY_MASK;
//   }

//   /// @notice Same as getKey but without checked arithmetic.
//   function unsafeGetKey(KeyList storage list, uint256 index) internal view returns (uint256) {
//     unchecked {
//       (uint256 slotIndex, uint256 offset) = _getSlotIndexAndOffset(index);
//       uint256 slotVal = list.getSlotsAt(slotIndex);
//       return (slotVal >> offset) & _KEY_MASK;
//     }
//   }

//   /// @notice Sets the key at the given key index.
//   /// @dev Extends the blob if needed.
//   function set(KeyList storage list, uint256 index, uint256 key) internal {
//     require(key < _KEY_MASK, Errors.ItemOverflow());
//     (uint256 slotIndex, uint256 offset) = _getSlotIndexAndOffset(index);
//     // If the slot does not exist yet, extend the blob.
//     if (
//       slotIndex >=
//       (list.slotsPointer == address(0) ? 0 : SSTORE2.read(list.slotsPointer).length / 32)
//     ) {
//       writeToSlotsAt(list, slotIndex, 0);
//     }
//     uint256 currentSlot = list.getSlotsAt(slotIndex);
//     uint256 mask = ~(_KEY_MASK << offset);
//     uint256 newSlot = (currentSlot & mask) | (key << offset);
//     writeToSlotsAt(list, slotIndex, newSlot);
//   }

//   /// @dev Computes the slot index and bit offset for a given key index.
//   function _getSlotIndexAndOffset(
//     uint256 index
//   ) private pure returns (uint256 slotIndex, uint256 offset) {
//     slotIndex = index / _KEYS_PER_SLOT;
//     offset = (index % _KEYS_PER_SLOT) * _KEY_BITS;
//   }

//   // --- Core List Operations ---

//   /// @notice Inserts a new key (with its associated value) into the list, preserving sorted order.
//   function _insertKey(
//     KeyList storage list,
//     ValueMap storage map,
//     uint256 key,
//     uint256 value
//   ) private {
//     // Store the associated value.
//     map.store(key, value);
//     // Determine the index where the new key should be inserted.
//     uint256 index = search(list, map, value);
//     // Increase the key count.
//     list.count++;
//     // Ensure the SSTORE2 blob is large enough.
//     _syncSlots(list);
//     // Shift keys right (from the end down to the insertion index).
//     for (uint256 i = list.count - 1; i > index; --i) {
//       uint256 prevKey = getKey(list, i - 1);
//       set(list, i, prevKey);
//     }
//     // Insert the new key.
//     set(list, index, key);
//   }

//   /// @notice Inserts a new key with its associated value.
//   /// @dev Automatically assigns a new key value (via ValueMap.incrementKey()).
//   function insert(KeyList storage list, ValueMap storage map, uint256 value) internal {
//     if (list.slotsPointer == address(0)) {
//       // Initialize SSTORE2 blob with one slot (all zeros).
//       writeToSlotsAt(list, 0, 0);
//     }
//     uint256 newKey = map.incrementKey();
//     _insertKey(list, map, newKey, value);
//   }

//   /// @notice Removes the key (and its associated value) at the given key index.
//   function remove(KeyList storage list, ValueMap storage map, uint256 index) internal {
//     require(index < list.count, Errors.IndexOutOfBounds());
//     uint256 keyToRemove = getKey(list, index);
//     map.store(keyToRemove, 0); // clear associated value
//     uint256 newCount = list.count - 1;
//     // Shift keys left to fill the gap.
//     for (uint256 i = index; i < newCount; ++i) {
//       uint256 nextKey = getKey(list, i + 1);
//       set(list, i, nextKey);
//     }
//     list.count = newCount;
//     // Note: we do not shrink the SSTORE2 blob.
//   }

//   /// @notice Updates the value associated with the key at the given index.
//   /// @dev For simplicity the key is removed and re-inserted.
//   function update(
//     KeyList storage list,
//     ValueMap storage map,
//     uint256 index,
//     uint256 value
//   ) internal {
//     require(index < list.count, Errors.IndexOutOfBounds());
//     uint256 key = getKey(list, index);
//     remove(list, map, index);
//     _insertKey(list, map, key, value);
//   }

//   /// @notice Searches for the key index at which the given value should be inserted.
//   /// Returns the index at which the value is not less than the searched value.
//   function search(
//     KeyList storage list,
//     ValueMap storage map,
//     uint256 value
//   ) internal view returns (uint256) {
//     uint256 low = 0;
//     uint256 high = list.count;
//     while (low < high) {
//       uint256 mid = (low + high) >> 1;
//       if (map.getValue(getKey(list, mid)) < value) {
//         low = mid + 1;
//       } else {
//         high = mid;
//       }
//     }
//     return low;
//   }

//   /// @notice Returns the number of keys in the list.
//   function length(KeyList storage list) internal view returns (uint256) {
//     return list.count;
//   }

//   // --- ValueMap Helper Functions ---
//   function store(ValueMap storage map, uint256 key, uint256 value) internal {
//     map.keyToValue[key] = value;
//   }

//   function getValue(ValueMap storage map, uint256 key) internal view returns (uint256) {
//     return map.keyToValue[key];
//   }

//   /// @notice Returns a new key and increments the internal counter.
//   function incrementKey(ValueMap storage map) internal returns (uint256 key) {
//     key = map.currentKey;
//     require(key < _KEY_MASK, Errors.ItemOverflow());
//     map.currentKey = key + 1;
//   }
// }

pragma solidity ^0.8.0;

import {SSTORE2} from 'src/dependencies/solmate/SSTORE2.sol';
import {Errors} from 'src/libraries/helpers/Errors.sol';

library PackedSortedKeyListSstore2 {
  using PackedSortedKeyListSstore2 for KeyList;
  using PackedSortedKeyListSstore2 for ValueMap;

  /// @dev Keys are stored in packed form in a contiguous SSTORE2 blob.
  /// Each key is encoded in 10 bits, so 25 keys fit in a single 256-bit (32-byte) slot.
  struct KeyList {
    address slotsPointer;
    uint256[] slots;
    uint256 count;
  }

  /// @dev Maintains the mapping from key => value, and a monotonically increasing key counter.
  struct ValueMap {
    mapping(uint256 => uint256) keyToValue;
    uint256 currentKey;
  }

  uint256 internal constant _KEY_BITS = 10;
  uint256 internal constant _KEYS_PER_SLOT = 256 / _KEY_BITS; // 25 keys per slot.
  uint256 internal constant _KEY_MASK = (1 << _KEY_BITS) - 1; // 1023

  function getSlotsLength(KeyList storage list) internal view returns (uint256) {
    if (list.count == 0) return 0;
    return ((list.count - 1) / _KEYS_PER_SLOT) + 1;
  }

  function getSlotsAt(
    KeyList storage list,
    uint256 slotIndex
  ) internal view returns (uint256 slotValue) {
    bytes memory slotBytes = SSTORE2.read(list.slotsPointer, slotIndex * 32, (slotIndex + 1) * 32);
    assembly ('memory-safe') {
      slotValue := mload(add(slotBytes, 32))
    }
  }

  function writeToSlotsAt(KeyList storage list, uint256 slotIndex, uint256 value) internal {
    uint256 currentSlots = list.slotsPointer == address(0)
      ? 0
      : SSTORE2.read(list.slotsPointer).length / 32;
    if (slotIndex >= currentSlots) {
      // Extend the blob to have (slotIndex+1) slots.
      uint256 newSlotsLength = slotIndex + 1;
      bytes memory oldData = currentSlots == 0 ? new bytes(0) : SSTORE2.read(list.slotsPointer);
      bytes memory newData = new bytes(newSlotsLength * 32);
      // Copy existing data.
      if (oldData.length > 0) {
        assembly {
          let src := add(oldData, 32)
          let dst := add(newData, 32)
          let len := mload(oldData)
          for {
            let i := 0
          } lt(i, len) {
            i := add(i, 32)
          } {
            mstore(add(dst, i), mload(add(src, i)))
          }
        }
      }
      // Write the new value into the proper slot.
      assembly {
        mstore(add(newData, add(32, mul(slotIndex, 32))), value)
      }
      list.slotsPointer = SSTORE2.write(newData);
    } else {
      // Update the existing blob.
      bytes memory data = SSTORE2.read(list.slotsPointer);
      require(data.length == currentSlots * 32, 'Data length mismatch');
      assembly {
        let pos := add(data, add(32, mul(slotIndex, 32)))
        mstore(pos, value)
      }
      list.slotsPointer = SSTORE2.write(data);
    }
  }

  function _syncSlots(KeyList storage list) internal {
    uint256 desiredSlots = list.count == 0 ? 0 : ((list.count - 1) / _KEYS_PER_SLOT) + 1;
    uint256 currentSlots = list.slotsPointer == address(0)
      ? 0
      : SSTORE2.read(list.slotsPointer).length / 32;
    if (desiredSlots > currentSlots) {
      bytes memory oldData = currentSlots == 0 ? new bytes(0) : SSTORE2.read(list.slotsPointer);
      bytes memory newData = new bytes(desiredSlots * 32);
      if (oldData.length > 0) {
        assembly {
          let src := add(oldData, 32)
          let dst := add(newData, 32)
          let len := mload(oldData)
          for {
            let i := 0
          } lt(i, len) {
            i := add(i, 32)
          } {
            mstore(add(dst, i), mload(add(src, i)))
          }
        }
      }
      list.slotsPointer = SSTORE2.write(newData);
    }
  }

  // --- Packed Key Helpers ---
  /// @dev Computes the slot index and bit offset for a given key index.
  function _getSlotIndexAndOffset(
    uint256 index
  ) private pure returns (uint256 slotIndex, uint256 offset) {
    slotIndex = index / _KEYS_PER_SLOT;
    offset = (index % _KEYS_PER_SLOT) * _KEY_BITS;
  }

  /// @notice Returns the key at the given index.
  function getKey(KeyList storage list, uint256 index) internal view returns (uint256) {
    require(index < list.count, Errors.IndexOutOfBounds());
    (uint256 slotIndex, uint256 offset) = _getSlotIndexAndOffset(index);
    uint256 slotVal = list.getSlotsAt(slotIndex);
    return (slotVal >> offset) & _KEY_MASK;
  }

  /// @notice Returns the key at the given index without checked arithmetic.
  function unsafeGetKey(KeyList storage list, uint256 index) internal view returns (uint256) {
    unchecked {
      (uint256 slotIndex, uint256 offset) = _getSlotIndexAndOffset(index);
      uint256 slotVal = list.getSlotsAt(slotIndex);
      return (slotVal >> offset) & _KEY_MASK;
    }
  }

  /// @notice Sets the key at the given index.
  /// Extends the SSTORE2 blob if needed.
  function set(KeyList storage list, uint256 index, uint256 key) internal {
    require(key < _KEY_MASK, Errors.ItemOverflow());
    (uint256 slotIndex, uint256 offset) = _getSlotIndexAndOffset(index);
    if (
      slotIndex >=
      (list.slotsPointer == address(0) ? 0 : SSTORE2.read(list.slotsPointer).length / 32)
    ) {
      writeToSlotsAt(list, slotIndex, 0);
    }
    uint256 currentSlot = list.getSlotsAt(slotIndex);
    uint256 mask = ~(_KEY_MASK << offset);
    uint256 newSlot = (currentSlot & mask) | (key << offset);
    writeToSlotsAt(list, slotIndex, newSlot);
  }

  // --- Optimized Batch Shift-and-Insert ---
  /// @dev Shifts keys right (from the end down to the insertion index) and inserts the new key,
  /// all in memory so that a single SSTORE2.write call is performed.
  function _batchShiftAndInsert(KeyList storage list, uint256 index, uint256 key) private {
    // Load the entire blob into memory.
    bytes memory data = SSTORE2.read(list.slotsPointer);
    uint256 newCount = list.count;
    // For each index from newCount-1 down to index+1,
    // copy the key from the previous index into the current index.
    for (uint256 i = newCount - 1; i > index; --i) {
      (uint256 slotIndexOld, uint256 offsetOld) = _getSlotIndexAndOffset(i - 1);
      uint256 prevKey;
      {
        assembly {
          let pos := add(data, add(32, mul(slotIndexOld, 32)))
          let slotVal := mload(pos)
          // Use literal 1023 instead of _KEY_MASK in assembly.
          prevKey := and(shr(offsetOld, slotVal), 1023)
        }
      }
      (uint256 slotIndexNew, uint256 offsetNew) = _getSlotIndexAndOffset(i);
      uint256 currentSlotShift;
      {
        assembly {
          let pos := add(data, add(32, mul(slotIndexNew, 32)))
          currentSlotShift := mload(pos)
        }
      }
      uint256 maskShift = ~(1023 << offsetNew);
      uint256 newSlotShift = (currentSlotShift & maskShift) | (prevKey << offsetNew);
      assembly {
        let pos := add(data, add(32, mul(slotIndexNew, 32)))
        mstore(pos, newSlotShift)
      }
    }
    // Now insert the new key at the target index.
    (uint256 insSlotIndex, uint256 insOffset) = _getSlotIndexAndOffset(index);
    uint256 currentSlotInsert;
    {
      assembly {
        let pos := add(data, add(32, mul(insSlotIndex, 32)))
        currentSlotInsert := mload(pos)
      }
    }
    // Here we can use _KEY_MASK in Solidity since it's not inside an assembly block.
    uint256 maskInsert = ~(1023 << insOffset);
    uint256 newSlotInsert = (currentSlotInsert & maskInsert) | (key << insOffset);
    assembly {
      let pos := add(data, add(32, mul(insSlotIndex, 32)))
      mstore(pos, newSlotInsert)
    }
    // Write the updated blob in one go.
    list.slotsPointer = SSTORE2.write(data);
  }

  // --- Core List Operations ---

  /// @dev Inserts a new key (with its associated value) into the list while preserving sorted order.
  /// Uses a batched in-memory update to shift keys and insert the new key.
  function _insertKey(
    KeyList storage list,
    ValueMap storage map,
    uint256 key,
    uint256 value
  ) private {
    // Store the associated value.
    map.store(key, value);

    // Determine the index at which to insert the new key (binary search).
    uint256 index = search(list, map, value);

    // Increase the key count.
    list.count++;

    // Ensure the SSTORE2 blob is large enough.
    _syncSlots(list);

    // Perform a batched right-shift and then insert the new key.
    _batchShiftAndInsert(list, index, key);
  }

  /// @notice Inserts a new key with its associated value.
  /// Automatically assigns a new key (using ValueMap.incrementKey).
  function insert(KeyList storage list, ValueMap storage map, uint256 value) internal {
    if (list.slotsPointer == address(0)) {
      // Initialize the SSTORE2 blob with one empty slot.
      writeToSlotsAt(list, 0, 0);
    }
    uint256 newKey = map.incrementKey();
    _insertKey(list, map, newKey, value);
  }

  /// @notice Removes the key (and its associated value) at the given index.
  function remove(KeyList storage list, ValueMap storage map, uint256 index) internal {
    require(index < list.count, Errors.IndexOutOfBounds());
    uint256 keyToRemove = getKey(list, index);
    // Clear the associated value.
    map.store(keyToRemove, 0);

    uint256 newCount = list.count - 1;
    // Shift keys left to fill the gap.
    for (uint256 i = index; i < newCount; ++i) {
      uint256 nextKey = getKey(list, i + 1);
      set(list, i, nextKey);
    }
    list.count = newCount;
    // Note: the SSTORE2 blob is not shrunk.
  }

  /// @notice Updates the value associated with the key at the given index.
  /// For simplicity, this removes and then re-inserts the key.
  function update(
    KeyList storage list,
    ValueMap storage map,
    uint256 index,
    uint256 value
  ) internal {
    require(index < list.count, Errors.IndexOutOfBounds());
    uint256 key = getKey(list, index);
    remove(list, map, index);
    _insertKey(list, map, key, value);
  }

  /// @notice Searches for the index at which a key with the given value should be inserted.
  /// Returns the index at which the key's value is not less than the given value.
  function search(
    KeyList storage list,
    ValueMap storage map,
    uint256 value
  ) internal view returns (uint256) {
    uint256 low = 0;
    uint256 high = list.count;
    while (low < high) {
      uint256 mid = (low + high) >> 1;
      if (map.getValue(getKey(list, mid)) < value) {
        low = mid + 1;
      } else {
        high = mid;
      }
    }
    return low;
  }

  /// @notice Returns the number of keys in the list.
  function length(KeyList storage list) internal view returns (uint256) {
    return list.count;
  }

  // --- ValueMap Helper Functions ---

  function store(ValueMap storage map, uint256 key, uint256 value) internal {
    map.keyToValue[key] = value;
  }

  function getValue(ValueMap storage map, uint256 key) internal view returns (uint256) {
    return map.keyToValue[key];
  }

  /// @notice Returns a new key and increments the internal counter.
  function incrementKey(ValueMap storage map) internal returns (uint256 key) {
    key = map.currentKey;
    require(key < _KEY_MASK, Errors.ItemOverflow());
    map.currentKey = key + 1;
  }
}
