// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {IAaveV4ConfigEngine} from 'src/config-engine/interfaces/IAaveV4ConfigEngine.sol';
import {IHubEngine} from 'src/config-engine/interfaces/IHubEngine.sol';
import {ISpokeEngine} from 'src/config-engine/interfaces/ISpokeEngine.sol';
import {IAccessManagerEngine} from 'src/config-engine/interfaces/IAccessManagerEngine.sol';
import {IPositionManagerEngine} from 'src/config-engine/interfaces/IPositionManagerEngine.sol';
import {Address} from 'src/dependencies/openzeppelin/Address.sol';

/// @title AaveV4ConfigEngine
/// @author Aave Labs
/// @notice Implementation of IAaveV4ConfigEngine. Stores 4 deployed sub-engine addresses as
///   immutables and delegatecalls into them. Invoked via delegatecall from payload contracts.
contract AaveV4ConfigEngine is IAaveV4ConfigEngine {
  using Address for address;

  /// @dev Thrown when a constructor engine address is zero.
  error InvalidEngineAddress();

  /// @notice The deployed HubEngine contract.
  IHubEngine public immutable HUB_ENGINE;
  /// @notice The deployed SpokeEngine contract.
  ISpokeEngine public immutable SPOKE_ENGINE;
  /// @notice The deployed AccessManagerEngine contract.
  IAccessManagerEngine public immutable ACCESS_MANAGER_ENGINE;
  /// @notice The deployed PositionManagerEngine contract.
  IPositionManagerEngine public immutable POSITION_MANAGER_ENGINE;

  /// @param hubEngine The HubEngine implementation.
  /// @param spokeEngine The SpokeEngine implementation.
  /// @param accessManagerEngine The AccessManagerEngine implementation.
  /// @param positionManagerEngine The PositionManagerEngine implementation.
  constructor(
    IHubEngine hubEngine,
    ISpokeEngine spokeEngine,
    IAccessManagerEngine accessManagerEngine,
    IPositionManagerEngine positionManagerEngine
  ) {
    require(address(hubEngine) != address(0), InvalidEngineAddress());
    require(address(spokeEngine) != address(0), InvalidEngineAddress());
    require(address(accessManagerEngine) != address(0), InvalidEngineAddress());
    require(address(positionManagerEngine) != address(0), InvalidEngineAddress());
    HUB_ENGINE = hubEngine;
    SPOKE_ENGINE = spokeEngine;
    ACCESS_MANAGER_ENGINE = accessManagerEngine;
    POSITION_MANAGER_ENGINE = positionManagerEngine;
  }

  // --- Hub Engine ---

  /// @inheritdoc IAaveV4ConfigEngine
  function executeHubAssetListings(AssetListing[] calldata listings) external {
    address(HUB_ENGINE).functionDelegateCall(
      abi.encodeCall(IHubEngine.executeHubAssetListings, (listings))
    );
  }

  /// @inheritdoc IAaveV4ConfigEngine
  function executeHubAssetConfigUpdates(AssetConfigUpdate[] calldata updates) external {
    address(HUB_ENGINE).functionDelegateCall(
      abi.encodeCall(IHubEngine.executeHubAssetConfigUpdates, (updates))
    );
  }

  /// @inheritdoc IAaveV4ConfigEngine
  function executeHubSpokeToAssetsAdditions(SpokeToAssetsAddition[] calldata additions) external {
    address(HUB_ENGINE).functionDelegateCall(
      abi.encodeCall(IHubEngine.executeHubSpokeToAssetsAdditions, (additions))
    );
  }

  /// @inheritdoc IAaveV4ConfigEngine
  function executeHubSpokeConfigUpdates(SpokeConfigUpdate[] calldata updates) external {
    address(HUB_ENGINE).functionDelegateCall(
      abi.encodeCall(IHubEngine.executeHubSpokeConfigUpdates, (updates))
    );
  }

  /// @inheritdoc IAaveV4ConfigEngine
  function executeHubAssetHalts(AssetHalt[] calldata halts) external {
    address(HUB_ENGINE).functionDelegateCall(
      abi.encodeCall(IHubEngine.executeHubAssetHalts, (halts))
    );
  }

  /// @inheritdoc IAaveV4ConfigEngine
  function executeHubAssetDeactivations(AssetDeactivation[] calldata deactivations) external {
    address(HUB_ENGINE).functionDelegateCall(
      abi.encodeCall(IHubEngine.executeHubAssetDeactivations, (deactivations))
    );
  }

  /// @inheritdoc IAaveV4ConfigEngine
  function executeHubAssetCapsResets(AssetCapsReset[] calldata resets) external {
    address(HUB_ENGINE).functionDelegateCall(
      abi.encodeCall(IHubEngine.executeHubAssetCapsResets, (resets))
    );
  }

  /// @inheritdoc IAaveV4ConfigEngine
  function executeHubSpokeHalts(SpokeHalt[] calldata halts) external {
    address(HUB_ENGINE).functionDelegateCall(
      abi.encodeCall(IHubEngine.executeHubSpokeHalts, (halts))
    );
  }

  /// @inheritdoc IAaveV4ConfigEngine
  function executeHubSpokeDeactivations(SpokeDeactivation[] calldata deactivations) external {
    address(HUB_ENGINE).functionDelegateCall(
      abi.encodeCall(IHubEngine.executeHubSpokeDeactivations, (deactivations))
    );
  }

  /// @inheritdoc IAaveV4ConfigEngine
  function executeHubSpokeCapsResets(SpokeCapsReset[] calldata resets) external {
    address(HUB_ENGINE).functionDelegateCall(
      abi.encodeCall(IHubEngine.executeHubSpokeCapsResets, (resets))
    );
  }

  // --- Spoke Engine ---

  /// @inheritdoc IAaveV4ConfigEngine
  function executeSpokeReserveListings(ReserveListing[] calldata listings) external {
    address(SPOKE_ENGINE).functionDelegateCall(
      abi.encodeCall(ISpokeEngine.executeSpokeReserveListings, (listings))
    );
  }

  /// @inheritdoc IAaveV4ConfigEngine
  function executeSpokeReserveConfigUpdates(ReserveConfigUpdate[] calldata updates) external {
    address(SPOKE_ENGINE).functionDelegateCall(
      abi.encodeCall(ISpokeEngine.executeSpokeReserveConfigUpdates, (updates))
    );
  }

  /// @inheritdoc IAaveV4ConfigEngine
  function executeSpokeLiquidationConfigUpdates(
    LiquidationConfigUpdate[] calldata updates
  ) external {
    address(SPOKE_ENGINE).functionDelegateCall(
      abi.encodeCall(ISpokeEngine.executeSpokeLiquidationConfigUpdates, (updates))
    );
  }

  /// @inheritdoc IAaveV4ConfigEngine
  function executeSpokeDynamicReserveConfigAdditions(
    DynamicReserveConfigAddition[] calldata additions
  ) external {
    address(SPOKE_ENGINE).functionDelegateCall(
      abi.encodeCall(ISpokeEngine.executeSpokeDynamicReserveConfigAdditions, (additions))
    );
  }

  /// @inheritdoc IAaveV4ConfigEngine
  function executeSpokeDynamicReserveConfigUpdates(
    DynamicReserveConfigUpdate[] calldata updates
  ) external {
    address(SPOKE_ENGINE).functionDelegateCall(
      abi.encodeCall(ISpokeEngine.executeSpokeDynamicReserveConfigUpdates, (updates))
    );
  }

  /// @inheritdoc IAaveV4ConfigEngine
  function executeSpokeAllReservesPauses(SpokePause[] calldata pauses) external {
    address(SPOKE_ENGINE).functionDelegateCall(
      abi.encodeCall(ISpokeEngine.executeSpokeAllReservesPauses, (pauses))
    );
  }

  /// @inheritdoc IAaveV4ConfigEngine
  function executeSpokeAllReservesFreezes(SpokeFreeze[] calldata freezes) external {
    address(SPOKE_ENGINE).functionDelegateCall(
      abi.encodeCall(ISpokeEngine.executeSpokeAllReservesFreezes, (freezes))
    );
  }

  /// @inheritdoc IAaveV4ConfigEngine
  function executeSpokePositionManagerUpdates(PositionManagerUpdate[] calldata updates) external {
    address(SPOKE_ENGINE).functionDelegateCall(
      abi.encodeCall(ISpokeEngine.executeSpokePositionManagerUpdates, (updates))
    );
  }

  // --- Position Manager Engine ---

  /// @inheritdoc IAaveV4ConfigEngine
  function executePositionManagerSpokeRegistrations(
    SpokeRegistration[] calldata registrations
  ) external {
    address(POSITION_MANAGER_ENGINE).functionDelegateCall(
      abi.encodeCall(
        IPositionManagerEngine.executePositionManagerSpokeRegistrations,
        (registrations)
      )
    );
  }

  /// @inheritdoc IAaveV4ConfigEngine
  function executePositionManagerRescues(Rescue[] calldata rescues) external {
    address(POSITION_MANAGER_ENGINE).functionDelegateCall(
      abi.encodeCall(IPositionManagerEngine.executePositionManagerRescues, (rescues))
    );
  }

  /// @inheritdoc IAaveV4ConfigEngine
  function executePositionManagerRoleRenouncements(
    PositionManagerRoleRenouncement[] calldata renouncements
  ) external {
    address(POSITION_MANAGER_ENGINE).functionDelegateCall(
      abi.encodeCall(
        IPositionManagerEngine.executePositionManagerRoleRenouncements,
        (renouncements)
      )
    );
  }

  // --- Access Manager Engine ---

  /// @inheritdoc IAaveV4ConfigEngine
  function executeRoleMemberships(RoleMembership[] calldata memberships) external {
    address(ACCESS_MANAGER_ENGINE).functionDelegateCall(
      abi.encodeCall(IAccessManagerEngine.executeRoleMemberships, (memberships))
    );
  }

  /// @inheritdoc IAaveV4ConfigEngine
  function executeRoleUpdates(RoleUpdate[] calldata updates) external {
    address(ACCESS_MANAGER_ENGINE).functionDelegateCall(
      abi.encodeCall(IAccessManagerEngine.executeRoleUpdates, (updates))
    );
  }

  /// @inheritdoc IAaveV4ConfigEngine
  function executeTargetFunctionRoleUpdates(TargetFunctionRoleUpdate[] calldata updates) external {
    address(ACCESS_MANAGER_ENGINE).functionDelegateCall(
      abi.encodeCall(IAccessManagerEngine.executeTargetFunctionRoleUpdates, (updates))
    );
  }

  /// @inheritdoc IAaveV4ConfigEngine
  function executeTargetAdminDelayUpdates(TargetAdminDelayUpdate[] calldata updates) external {
    address(ACCESS_MANAGER_ENGINE).functionDelegateCall(
      abi.encodeCall(IAccessManagerEngine.executeTargetAdminDelayUpdates, (updates))
    );
  }
}
