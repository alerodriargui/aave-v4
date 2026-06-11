// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity 0.8.28;

import {V4AddressesProvider} from 'src/addresses-provider/V4AddressesProvider.sol';

/// @title V4AddressesProviderInstance
/// @author Aave Labs
/// @notice Implementation contract for the V4AddressesProvider.
contract V4AddressesProviderInstance is V4AddressesProvider {
  uint64 public constant ADDRESSES_PROVIDER_REVISION = 1;

  /// @dev Constructor.
  constructor() {
    _disableInitializers();
  }

  /// @notice Initializer.
  /// @param owner The address of the owner.
  function initialize(address owner) external override reinitializer(ADDRESSES_PROVIDER_REVISION) {
    __Ownable_init(owner);
    __Ownable2Step_init();
  }
}
