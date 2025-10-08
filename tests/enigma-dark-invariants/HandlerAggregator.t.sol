// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Handler contracts
import {HubHandler} from "./handlers/hub/HubHandler.t.sol";
import {SpokeHandler} from "./handlers/spoke/SpokeHandler.t.sol";
import {HubConfiguratorHandler} from "./handlers/hub/HubConfiguratorHandler.t.sol";
import {SpokeConfiguratorHandler} from "./handlers/spoke/SpokeConfiguratorHandler.t.sol";

// Simulator contracts
import {PriceFeeSimulatorHandler} from "./handlers/simulators/PriceFeeSimulatorHandler.t.sol";
import {DonationAttackHandler} from "./handlers/simulators/DonationAttackHandler.t.sol";

/// @notice Helper contract to aggregate all handler contracts, inherited in BaseInvariants
abstract contract HandlerAggregator is
    HubHandler, // Main handlers
    SpokeHandler,
    HubConfiguratorHandler, // Configurators
    SpokeConfiguratorHandler,
    PriceFeeSimulatorHandler, // Simulators
    DonationAttackHandler
{
    /// @notice Helper function in case any handler requires additional setup
    function _setUpHandlers() internal {}
}
