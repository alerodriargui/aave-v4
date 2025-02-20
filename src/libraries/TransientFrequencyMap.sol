// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

library TransientFrequencyMap {
  using PackedUintArray for uint256;

  function put(uint256 key, uint256 value) internal {
    uint256 existingValues = _load(key);
    if (existingValues == 0) {
      _store(key, value);
      return;
    }
  }

  function get(uint256 key) internal view returns (uint256) {
    return _load(key);
  }

  function _load(uint256 key) internal view returns (uint256 value) {
    assembly {
      value := tload(key)
    }
  }

  function _store(uint256 key, uint256 value) internal {
    assembly {
      tstore(key, value)
    }
  }
}

library PackedUintArray {
  error MaxValueSizeExceeded();

  uint256 internal constant _SLOT_BITS = 256; // evm limit
  uint256 internal constant _VALUE_BITS = 10; // 10 bits per key
  uint256 internal constant _VALUES_PER_SLOT = _SLOT_BITS / _VALUE_BITS; // _MAX_VALUES_PER_SLOT, 25 keys per slot
  uint256 internal constant _VALUE_MASK = (1 << _VALUE_BITS) - 1;

  function set(uint256 data, uint256 index, uint256 value) internal pure returns (uint256) {
    require(value < _VALUE_MASK, MaxValueSizeExceeded());
    uint256 offset = _getOffset(index);
    return (data & ~(_VALUE_MASK << offset)) | (value << offset);
  }

  function get(uint256 data, uint256 index) internal pure returns (uint256) {
    return (data >> _getOffset(index)) & _VALUE_MASK;
  }

  // assumes index < _MAX_KEYS_PER_SLOT
  function _getOffset(uint256 index) private pure returns (uint256) {
    return (index % _VALUES_PER_SLOT) * _VALUE_BITS;
  }
}
