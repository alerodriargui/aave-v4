// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

import {ITokenizationSpoke} from 'src/spoke/interfaces/ITokenizationSpoke.sol';

/// @title ITokenizationSpokeInstance
/// @author Aave Labs
/// @notice TokenizationSpoke instance interface exposing the initializer and revision.
interface ITokenizationSpokeInstance is ITokenizationSpoke {
  function initialize(string memory shareName, string memory shareSymbol) external;

  function SPOKE_REVISION() external view returns (uint64);
}
