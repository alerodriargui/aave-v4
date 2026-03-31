// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';

/// @title ISpokeInstance
/// @author Aave Labs
/// @notice Spoke instance interface exposing the initializer and revision.
interface ISpokeInstance is ISpoke {
  function initialize(address _authority) external;

  function SPOKE_REVISION() external view returns (uint64);
}
