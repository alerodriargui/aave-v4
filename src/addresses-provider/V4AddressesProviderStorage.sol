// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity 0.8.28;

import {EnumerableSet} from 'src/dependencies/openzeppelin/EnumerableSet.sol';
import {IV4AddressesProvider} from 'src/addresses-provider/interfaces/IV4AddressesProvider.sol';

/// @title V4AddressesProviderStorage
/// @author Aave Labs
/// @notice Storage layout for the V4AddressesProvider contract.
/// @dev This contract defines all storage variables used by the V4AddressesProvider.
abstract contract V4AddressesProviderStorage {
  /// @dev Map of entry identifiers to address entries.
  mapping(bytes32 id => IV4AddressesProvider.AddressEntry) internal _addressEntries;

  /// @dev Map of tags to set of entry identifiers.
  mapping(string tag => EnumerableSet.Bytes32Set ids) internal _taggedIds;

  /// @dev Set of all tags with at least one registered entry.
  EnumerableSet.StringSet internal _tags;

  /// @dev Reserved storage space to allow for future layout updates.
  uint256[50] private __gap;
}
