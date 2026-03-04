// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {BaseConfigEngineTest} from 'tests/config-engine/BaseConfigEngine.t.sol';

import {IAaveV4ConfigEngine} from 'src/config-engine/interfaces/IAaveV4ConfigEngine.sol';
import {AaveV4Payload} from 'src/config-engine/AaveV4Payload.sol';

/// @dev Minimal concrete payload that does NOT override any virtual methods.
///   Calling execute() on this exercises every base virtual method returning empty arrays,
///   plus the no-op _preExecute / _postExecute hooks.
contract MinimalAaveV4Payload is AaveV4Payload {
  constructor(IAaveV4ConfigEngine configEngine) AaveV4Payload(configEngine) {}
}

/// @dev Payload that exposes base virtual methods through external wrappers for direct testing.
contract ExposedAaveV4Payload is AaveV4Payload {
  constructor(IAaveV4ConfigEngine configEngine) AaveV4Payload(configEngine) {}

  // Hub getters
  function exposed_hubAssetListings() external returns (IAaveV4ConfigEngine.AssetListing[] memory) {
    return hubAssetListings();
  }

  function exposed_hubAssetConfigUpdates()
    external
    returns (IAaveV4ConfigEngine.AssetConfigUpdate[] memory)
  {
    return hubAssetConfigUpdates();
  }

  function exposed_hubSpokeToAssetsAdditions()
    external
    returns (IAaveV4ConfigEngine.SpokeToAssetsAddition[] memory)
  {
    return hubSpokeToAssetsAdditions();
  }

  function exposed_hubSpokeConfigUpdates()
    external
    returns (IAaveV4ConfigEngine.SpokeConfigUpdate[] memory)
  {
    return hubSpokeConfigUpdates();
  }

  function exposed_hubAssetHalts() external returns (IAaveV4ConfigEngine.AssetHalt[] memory) {
    return hubAssetHalts();
  }

  function exposed_hubAssetDeactivations()
    external
    returns (IAaveV4ConfigEngine.AssetDeactivation[] memory)
  {
    return hubAssetDeactivations();
  }

  function exposed_hubAssetCapsResets()
    external
    returns (IAaveV4ConfigEngine.AssetCapsReset[] memory)
  {
    return hubAssetCapsResets();
  }

  function exposed_hubSpokeHalts() external returns (IAaveV4ConfigEngine.SpokeHalt[] memory) {
    return hubSpokeHalts();
  }

  function exposed_hubSpokeDeactivations()
    external
    returns (IAaveV4ConfigEngine.SpokeDeactivation[] memory)
  {
    return hubSpokeDeactivations();
  }

  function exposed_hubSpokeCapsResets()
    external
    returns (IAaveV4ConfigEngine.SpokeCapsReset[] memory)
  {
    return hubSpokeCapsResets();
  }

  function exposed_spokeReserveListings()
    external
    returns (IAaveV4ConfigEngine.ReserveListing[] memory)
  {
    return spokeReserveListings();
  }

  function exposed_spokeReserveConfigUpdates()
    external
    returns (IAaveV4ConfigEngine.ReserveConfigUpdate[] memory)
  {
    return spokeReserveConfigUpdates();
  }

  function exposed_spokeLiquidationConfigUpdates()
    external
    returns (IAaveV4ConfigEngine.LiquidationConfigUpdate[] memory)
  {
    return spokeLiquidationConfigUpdates();
  }

  function exposed_spokeDynamicReserveConfigAdditions()
    external
    returns (IAaveV4ConfigEngine.DynamicReserveConfigAddition[] memory)
  {
    return spokeDynamicReserveConfigAdditions();
  }

  function exposed_spokeDynamicReserveConfigUpdates()
    external
    returns (IAaveV4ConfigEngine.DynamicReserveConfigUpdate[] memory)
  {
    return spokeDynamicReserveConfigUpdates();
  }

  function exposed_spokeAllReservesPauses()
    external
    returns (IAaveV4ConfigEngine.SpokePause[] memory)
  {
    return spokeAllReservesPauses();
  }

  function exposed_spokeAllReservesFreezes()
    external
    returns (IAaveV4ConfigEngine.SpokeFreeze[] memory)
  {
    return spokeAllReservesFreezes();
  }

  function exposed_spokePositionManagerUpdates()
    external
    returns (IAaveV4ConfigEngine.PositionManagerUpdate[] memory)
  {
    return spokePositionManagerUpdates();
  }

  function exposed_accessManagerRoleMemberships()
    external
    returns (IAaveV4ConfigEngine.RoleMembership[] memory)
  {
    return accessManagerRoleMemberships();
  }

  function exposed_accessManagerRoleUpdates()
    external
    returns (IAaveV4ConfigEngine.RoleUpdate[] memory)
  {
    return accessManagerRoleUpdates();
  }

  function exposed_accessManagerTargetFunctionRoleUpdates()
    external
    returns (IAaveV4ConfigEngine.TargetFunctionRoleUpdate[] memory)
  {
    return accessManagerTargetFunctionRoleUpdates();
  }

  function exposed_accessManagerTargetAdminDelayUpdates()
    external
    returns (IAaveV4ConfigEngine.TargetAdminDelayUpdate[] memory)
  {
    return accessManagerTargetAdminDelayUpdates();
  }

  function exposed_positionManagerSpokeRegistrations()
    external
    returns (IAaveV4ConfigEngine.SpokeRegistration[] memory)
  {
    return positionManagerSpokeRegistrations();
  }

  function exposed_positionManagerRescues() external returns (IAaveV4ConfigEngine.Rescue[] memory) {
    return positionManagerRescues();
  }

  function exposed_positionManagerRoleRenouncements()
    external
    returns (IAaveV4ConfigEngine.PositionManagerRoleRenouncement[] memory)
  {
    return positionManagerRoleRenouncements();
  }
}

contract AaveV4PayloadEmptyReturnsTest is BaseConfigEngineTest {
  MinimalAaveV4Payload public minimal;
  ExposedAaveV4Payload public exposed;

  function setUp() public override {
    super.setUp();
    minimal = new MinimalAaveV4Payload(IAaveV4ConfigEngine(address(engine)));
    exposed = new ExposedAaveV4Payload(IAaveV4ConfigEngine(address(engine)));
  }

  /// @dev Calling execute() on the minimal payload exercises _preExecute, _postExecute,
  ///   _executeHubActions, _executeSpokeActions, _executeAccessManagerActions, and every
  ///   base virtual getter (all returning empty arrays, so no delegatecalls are made).
  function test_minimalPayload_execute_noReverts() public {
    minimal.execute();
  }

  function test_hubAssetListings_returnsEmpty() public {
    assertEq(exposed.exposed_hubAssetListings().length, 0);
  }

  function test_hubAssetConfigUpdates_returnsEmpty() public {
    assertEq(exposed.exposed_hubAssetConfigUpdates().length, 0);
  }

  function test_hubSpokeToAssetsAdditions_returnsEmpty() public {
    assertEq(exposed.exposed_hubSpokeToAssetsAdditions().length, 0);
  }

  function test_hubSpokeConfigUpdates_returnsEmpty() public {
    assertEq(exposed.exposed_hubSpokeConfigUpdates().length, 0);
  }

  function test_hubAssetHalts_returnsEmpty() public {
    assertEq(exposed.exposed_hubAssetHalts().length, 0);
  }

  function test_hubAssetDeactivations_returnsEmpty() public {
    assertEq(exposed.exposed_hubAssetDeactivations().length, 0);
  }

  function test_hubAssetCapsResets_returnsEmpty() public {
    assertEq(exposed.exposed_hubAssetCapsResets().length, 0);
  }

  function test_hubSpokeHalts_returnsEmpty() public {
    assertEq(exposed.exposed_hubSpokeHalts().length, 0);
  }

  function test_hubSpokeDeactivations_returnsEmpty() public {
    assertEq(exposed.exposed_hubSpokeDeactivations().length, 0);
  }

  function test_hubSpokeCapsResets_returnsEmpty() public {
    assertEq(exposed.exposed_hubSpokeCapsResets().length, 0);
  }

  function test_spokeReserveListings_returnsEmpty() public {
    assertEq(exposed.exposed_spokeReserveListings().length, 0);
  }

  function test_spokeReserveConfigUpdates_returnsEmpty() public {
    assertEq(exposed.exposed_spokeReserveConfigUpdates().length, 0);
  }

  function test_spokeLiquidationConfigUpdates_returnsEmpty() public {
    assertEq(exposed.exposed_spokeLiquidationConfigUpdates().length, 0);
  }

  function test_spokeDynamicReserveConfigAdditions_returnsEmpty() public {
    assertEq(exposed.exposed_spokeDynamicReserveConfigAdditions().length, 0);
  }

  function test_spokeDynamicReserveConfigUpdates_returnsEmpty() public {
    assertEq(exposed.exposed_spokeDynamicReserveConfigUpdates().length, 0);
  }

  function test_spokeAllReservesPauses_returnsEmpty() public {
    assertEq(exposed.exposed_spokeAllReservesPauses().length, 0);
  }

  function test_spokeAllReservesFreezes_returnsEmpty() public {
    assertEq(exposed.exposed_spokeAllReservesFreezes().length, 0);
  }

  function test_spokePositionManagerUpdates_returnsEmpty() public {
    assertEq(exposed.exposed_spokePositionManagerUpdates().length, 0);
  }

  function test_accessManagerRoleMemberships_returnsEmpty() public {
    assertEq(exposed.exposed_accessManagerRoleMemberships().length, 0);
  }

  function test_accessManagerRoleUpdates_returnsEmpty() public {
    assertEq(exposed.exposed_accessManagerRoleUpdates().length, 0);
  }

  function test_accessManagerTargetFunctionRoleUpdates_returnsEmpty() public {
    assertEq(exposed.exposed_accessManagerTargetFunctionRoleUpdates().length, 0);
  }

  function test_accessManagerTargetAdminDelayUpdates_returnsEmpty() public {
    assertEq(exposed.exposed_accessManagerTargetAdminDelayUpdates().length, 0);
  }

  function test_positionManagerSpokeRegistrations_returnsEmpty() public {
    assertEq(exposed.exposed_positionManagerSpokeRegistrations().length, 0);
  }

  function test_positionManagerRescues_returnsEmpty() public {
    assertEq(exposed.exposed_positionManagerRescues().length, 0);
  }

  function test_positionManagerRoleRenouncements_returnsEmpty() public {
    assertEq(exposed.exposed_positionManagerRoleRenouncements().length, 0);
  }
}
