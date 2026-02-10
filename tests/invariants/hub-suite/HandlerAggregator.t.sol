// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Handler contracts
import {HubHandler} from './handlers/HubHandler.t.sol';
import {HubConfiguratorHandler} from './handlers/HubConfiguratorHandler.t.sol';
import {DonationAttackHandler} from './handlers/simulators/DonationAttackHandler.t.sol';

/// @notice Helper contract to aggregate all handler contracts for hub suite
abstract contract HandlerAggregator is HubHandler, HubConfiguratorHandler, DonationAttackHandler {
  function _setUpHandlers() internal {}
}
