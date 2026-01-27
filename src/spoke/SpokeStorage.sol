// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity 0.8.28;

import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';

/// @title SpokeStorage
/// @author Aave Labs
/// @notice Storage layout for the Spoke contract using ERC-7201 namespaced storage.
/// @dev This contract defines all storage variables used by Spoke.
abstract contract SpokeStorage {
  /// @custom:storage-location erc7201:aave-v4.storage.SpokeStorage
  struct SpokeStorageLayout {
    /// @dev Number of reserves listed in the Spoke.
    uint256 _reserveCount;
    /// @dev Map of user addresses and reserve identifiers to user positions.
    mapping(address user => mapping(uint256 reserveId => ISpoke.UserPosition)) _userPositions;
    /// @dev Map of user addresses to their position status.
    mapping(address user => ISpoke.PositionStatus) _positionStatus;
    /// @dev Map of reserve identifiers to their Reserve data.
    mapping(uint256 reserveId => ISpoke.Reserve) _reserves;
    /// @dev Map of position manager addresses to their configuration data.
    mapping(address positionManager => ISpoke.PositionManagerConfig) _positionManager;
    /// @dev Map of reserve identifiers and dynamic configuration keys to the dynamic configuration data.
    mapping(uint256 reserveId => mapping(uint24 dynamicConfigKey => ISpoke.DynamicReserveConfig)) _dynamicConfig;
    /// @dev Liquidation configuration for the Spoke.
    ISpoke.LiquidationConfig _liquidationConfig;
    /// @dev Map of hub addresses and asset identifiers to whether the reserve exists.
    mapping(address hub => mapping(uint256 assetId => bool)) _reserveExists;
  }

  /// @dev The storage slot for the SpokeStorage struct.
  bytes32 private constant NAMESPACE_SLOT =
    // keccak256(abi.encode(uint256(keccak256("aave-v4.storage.SpokeStorage")) - 1)) & ~bytes32(uint256(0xff))
    0xc842799967b8f7d5772ae56745a2eebbf66470edc0052d1522a5ff82d1419e00;

  /// @dev Loads the SpokeStorage storage struct.
  function _getSpokeStorage() internal pure returns (SpokeStorageLayout storage $) {
    assembly ('memory-safe') {
      $.slot := NAMESPACE_SLOT
    }
  }
}
