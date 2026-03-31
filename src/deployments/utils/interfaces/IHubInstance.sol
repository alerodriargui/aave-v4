// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

import {IHub} from 'src/hub/interfaces/IHub.sol';

/// @title IHubInstance
/// @author Aave Labs
/// @notice Hub instance interface exposing the initializer and revision.
interface IHubInstance is IHub {
  function initialize(address authority) external;

  function HUB_REVISION() external view returns (uint64);
}
