// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {IHub} from 'src/hub/interfaces/IHub.sol';
import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';
import {IHubConfigurator} from 'src/hub/interfaces/IHubConfigurator.sol';
import {ISpokeConfigurator} from 'src/spoke/interfaces/ISpokeConfigurator.sol';

/// @title IAaveV4ConfigEngine
/// @author Aave Labs
/// @notice Interface for the Aave V4 Config Engine, defining all structs and engine method signatures.
/// The engine is stateless and invoked via delegatecall from payload contracts.
/// All numeric fields in config structs use uint256 so that type(uint256).max can serve as
/// the universal KEEP_CURRENT sentinel. Boolean fields use uint256 (0=false, 1=true, KEEP_CURRENT=skip).
interface IAaveV4ConfigEngine {
  /// @notice Parameters for listing a new asset on a hub.
  /// @param hubConfigurator The HubConfigurator to use for this action.
  /// @param hub The address of the Hub.
  /// @param underlying The address of the underlying asset.
  /// @param decimals Explicit decimals (0 means use addAsset which auto-detects decimals).
  /// @param feeReceiver The address of the fee receiver spoke.
  /// @param liquidityFee The liquidity fee of the asset, in BPS.
  /// @param irStrategy The address of the interest rate strategy contract.
  /// @param irData The interest rate data to apply to the given asset, encoded in bytes.
  struct AssetListing {
    IHubConfigurator hubConfigurator;
    address hub;
    address underlying;
    uint256 decimals;
    address feeReceiver;
    uint256 liquidityFee;
    address irStrategy;
    bytes irData;
  }

  /// @notice Parameters for updating asset config (fee, interest rate, reinvestment) on a hub.
  /// @param hubConfigurator The HubConfigurator to use for this action.
  /// @param hub The address of the Hub.
  /// @param assetId The identifier of the asset.
  /// @param liquidityFee The new liquidity fee (KEEP_CURRENT to skip).
  /// @param feeReceiver The new fee receiver (KEEP_CURRENT_ADDRESS to skip).
  /// @param irStrategy The new interest rate strategy (KEEP_CURRENT_ADDRESS to skip strategy update).
  /// @param irData The interest rate data. If irStrategy != KEEP_CURRENT_ADDRESS, calls updateInterestRateStrategy.
  ///   Otherwise if irData.length > 0, calls updateInterestRateData.
  /// @param reinvestmentController The new reinvestment controller (KEEP_CURRENT_ADDRESS to skip).
  struct AssetConfigUpdate {
    IHubConfigurator hubConfigurator;
    address hub;
    uint256 assetId;
    uint256 liquidityFee;
    address feeReceiver;
    address irStrategy;
    bytes irData;
    address reinvestmentController;
  }

  /// @notice Parameters for registering a spoke for multiple assets on a hub.
  /// @param hubConfigurator The HubConfigurator to use for this action.
  /// @param hub The address of the Hub.
  /// @param spoke The address of the Spoke.
  /// @param assetIds The list of asset identifiers to register the spoke for.
  /// @param configs The list of Spoke configurations to register.
  struct SpokeToAssetsAddition {
    IHubConfigurator hubConfigurator;
    address hub;
    address spoke;
    uint256[] assetIds;
    IHub.SpokeConfig[] configs;
  }

  /// @notice Parameters for updating spoke config (caps, risk premium threshold, status) on a hub.
  /// @param hubConfigurator The HubConfigurator to use for this action.
  /// @param hub The address of the Hub.
  /// @param assetId The identifier of the asset.
  /// @param spoke The address of the Spoke.
  /// @param addCap The new add cap (KEEP_CURRENT to skip).
  /// @param drawCap The new draw cap (KEEP_CURRENT to skip).
  /// @param riskPremiumThreshold The new risk premium threshold (KEEP_CURRENT to skip).
  /// @param active New active flag (0=false, 1=true, KEEP_CURRENT=skip).
  /// @param halted New halted flag (0=false, 1=true, KEEP_CURRENT=skip).
  struct SpokeConfigUpdate {
    IHubConfigurator hubConfigurator;
    address hub;
    uint256 assetId;
    address spoke;
    uint256 addCap;
    uint256 drawCap;
    uint256 riskPremiumThreshold;
    uint256 active;
    uint256 halted;
  }

  /// @notice Parameters for halting an asset on a hub.
  /// @param hubConfigurator The HubConfigurator to use for this action.
  /// @param hub The address of the Hub.
  /// @param assetId The identifier of the asset.
  struct AssetHalt {
    IHubConfigurator hubConfigurator;
    address hub;
    uint256 assetId;
  }

  /// @notice Parameters for deactivating an asset on a hub.
  /// @param hubConfigurator The HubConfigurator to use for this action.
  /// @param hub The address of the Hub.
  /// @param assetId The identifier of the asset.
  struct AssetDeactivation {
    IHubConfigurator hubConfigurator;
    address hub;
    uint256 assetId;
  }

  /// @notice Parameters for resetting asset caps on a hub.
  /// @param hubConfigurator The HubConfigurator to use for this action.
  /// @param hub The address of the Hub.
  /// @param assetId The identifier of the asset.
  struct AssetCapsReset {
    IHubConfigurator hubConfigurator;
    address hub;
    uint256 assetId;
  }

  /// @notice Parameters for halting a spoke on a hub.
  /// @param hubConfigurator The HubConfigurator to use for this action.
  /// @param hub The address of the Hub.
  /// @param spoke The address of the Spoke.
  struct SpokeHalt {
    IHubConfigurator hubConfigurator;
    address hub;
    address spoke;
  }

  /// @notice Parameters for deactivating a spoke on a hub.
  /// @param hubConfigurator The HubConfigurator to use for this action.
  /// @param hub The address of the Hub.
  /// @param spoke The address of the Spoke.
  struct SpokeDeactivation {
    IHubConfigurator hubConfigurator;
    address hub;
    address spoke;
  }

  /// @notice Parameters for resetting spoke caps on a hub.
  /// @param hubConfigurator The HubConfigurator to use for this action.
  /// @param hub The address of the Hub.
  /// @param spoke The address of the Spoke.
  struct SpokeCapsReset {
    IHubConfigurator hubConfigurator;
    address hub;
    address spoke;
  }

  /// @notice Parameters for listing a new reserve on a spoke.
  /// @param spokeConfigurator The SpokeConfigurator to use for this action.
  /// @param spoke The address of the Spoke.
  /// @param hub The address of the Hub.
  /// @param assetId The identifier of the asset.
  /// @param priceSource The address of the price source.
  /// @param config The configuration of the reserve.
  /// @param dynamicConfig The dynamic configuration of the reserve.
  struct ReserveListing {
    ISpokeConfigurator spokeConfigurator;
    address spoke;
    address hub;
    uint256 assetId;
    address priceSource;
    ISpoke.ReserveConfig config;
    ISpoke.DynamicReserveConfig dynamicConfig;
  }

  /// @notice Parameters for updating reserve config on a spoke.
  /// @param spokeConfigurator The SpokeConfigurator to use for this action.
  /// @param spoke The address of the Spoke.
  /// @param reserveId The identifier of the reserve.
  /// @param priceSource The new price source address (KEEP_CURRENT_ADDRESS to skip).
  /// @param collateralRisk New collateral risk (KEEP_CURRENT to skip).
  /// @param paused New paused flag (0=false, 1=true, KEEP_CURRENT=skip).
  /// @param frozen New frozen flag (0=false, 1=true, KEEP_CURRENT=skip).
  /// @param borrowable New borrowable flag (0=false, 1=true, KEEP_CURRENT=skip).
  /// @param receiveSharesEnabled New receiveSharesEnabled flag (0=false, 1=true, KEEP_CURRENT=skip).
  struct ReserveConfigUpdate {
    ISpokeConfigurator spokeConfigurator;
    address spoke;
    uint256 reserveId;
    address priceSource;
    uint256 collateralRisk;
    uint256 paused;
    uint256 frozen;
    uint256 borrowable;
    uint256 receiveSharesEnabled;
  }

  /// @notice Parameters for updating liquidation config on a spoke.
  /// @param spokeConfigurator The SpokeConfigurator to use for this action.
  /// @param spoke The address of the Spoke.
  /// @param targetHealthFactor The new target health factor (KEEP_CURRENT to skip).
  /// @param healthFactorForMaxBonus The new health factor for max bonus (KEEP_CURRENT to skip).
  /// @param liquidationBonusFactor The new liquidation bonus factor (KEEP_CURRENT to skip).
  struct LiquidationConfigUpdate {
    ISpokeConfigurator spokeConfigurator;
    address spoke;
    uint256 targetHealthFactor;
    uint256 healthFactorForMaxBonus;
    uint256 liquidationBonusFactor;
  }

  /// @notice Parameters for adding a dynamic reserve config on a spoke.
  /// @param spokeConfigurator The SpokeConfigurator to use for this action.
  /// @param spoke The address of the Spoke.
  /// @param reserveId The identifier of the reserve.
  /// @param dynamicConfig The new dynamic config.
  struct DynamicReserveConfigAddition {
    ISpokeConfigurator spokeConfigurator;
    address spoke;
    uint256 reserveId;
    ISpoke.DynamicReserveConfig dynamicConfig;
  }

  /// @notice Parameters for updating a dynamic reserve config on a spoke.
  /// @param spokeConfigurator The SpokeConfigurator to use for this action.
  /// @param spoke The address of the Spoke.
  /// @param reserveId The identifier of the reserve.
  /// @param dynamicConfigKey The key of the dynamic config to update.
  /// @param collateralFactor New collateral factor (KEEP_CURRENT to skip).
  /// @param maxLiquidationBonus New max liquidation bonus (KEEP_CURRENT to skip).
  /// @param liquidationFee New liquidation fee (KEEP_CURRENT to skip).
  struct DynamicReserveConfigUpdate {
    ISpokeConfigurator spokeConfigurator;
    address spoke;
    uint256 reserveId;
    uint256 dynamicConfigKey;
    uint256 collateralFactor;
    uint256 maxLiquidationBonus;
    uint256 liquidationFee;
  }

  /// @notice Parameters for pausing all reserves on a spoke.
  /// @param spokeConfigurator The SpokeConfigurator to use for this action.
  /// @param spoke The address of the Spoke.
  struct SpokePause {
    ISpokeConfigurator spokeConfigurator;
    address spoke;
  }

  /// @notice Parameters for freezing all reserves on a spoke.
  /// @param spokeConfigurator The SpokeConfigurator to use for this action.
  /// @param spoke The address of the Spoke.
  struct SpokeFreeze {
    ISpokeConfigurator spokeConfigurator;
    address spoke;
  }

  /// @notice Parameters for updating a position manager on a spoke.
  /// @param spokeConfigurator The SpokeConfigurator to use for this action.
  /// @param spoke The address of the Spoke.
  /// @param positionManager The address of the position manager.
  /// @param active The new active flag.
  struct PositionManagerUpdate {
    ISpokeConfigurator spokeConfigurator;
    address spoke;
    address positionManager;
    bool active;
  }

  /// @notice Parameters for registering/deregistering a spoke on a position manager.
  /// @param positionManager The position manager address.
  /// @param spoke The address of the spoke.
  /// @param registered Whether to register (true) or deregister (false) the spoke.
  struct SpokeRegistration {
    address positionManager;
    address spoke;
    bool registered;
  }

  /// @notice Parameters for rescuing ERC20 tokens and/or native assets from a position manager.
  /// @param positionManager The position manager address.
  /// @param token The address of the ERC20 token to rescue (only used if tokenAmount > 0).
  /// @param to The address to send the rescued assets to.
  /// @param tokenAmount The amount of ERC20 tokens to rescue (calls rescueToken if > 0).
  /// @param nativeAmount The amount of native assets to rescue (calls rescueNative if > 0).
  struct Rescue {
    address positionManager;
    address token;
    address to;
    uint256 tokenAmount;
    uint256 nativeAmount;
  }

  /// @notice Parameters for renouncing the position manager role for a user on a spoke.
  /// @param positionManager The position manager address.
  /// @param spoke The address of the spoke.
  /// @param user The address of the user to renounce the role for.
  struct PositionManagerRoleRenouncement {
    address positionManager;
    address spoke;
    address user;
  }

  /// @notice Parameters for granting or revoking a role via AccessManager.
  /// When granted=true → grantRole(roleId, account, executionDelay).
  /// When granted=false → revokeRole(roleId, account). executionDelay is ignored.
  /// @param authority The AccessManager address.
  /// @param roleId The role identifier.
  /// @param account The account to grant/revoke the role to/from.
  /// @param granted Whether to grant (true) or revoke (false) the role.
  /// @param executionDelay The execution delay for the account (only used when granted=true).
  struct RoleMembership {
    address authority;
    uint64 roleId;
    address account;
    bool granted;
    uint32 executionDelay;
  }

  /// @notice Parameters for updating role configuration via AccessManager.
  /// Uses type-specific sentinels to skip fields: type(uint64).max for admin/guardian,
  /// type(uint32).max for grantDelay, empty string for label.
  /// @param authority The AccessManager address.
  /// @param roleId The role identifier.
  /// @param admin The new admin role identifier (type(uint64).max to skip).
  /// @param guardian The new guardian role identifier (type(uint64).max to skip).
  /// @param grantDelay The new grant delay (type(uint32).max to skip).
  /// @param label The label string (empty string to skip).
  struct RoleUpdate {
    address authority;
    uint64 roleId;
    uint64 admin;
    uint64 guardian;
    uint32 grantDelay;
    string label;
  }

  /// @notice Parameters for setting target function roles via AccessManager.
  /// @param authority The AccessManager address.
  /// @param target The target contract address.
  /// @param selectors The function selectors.
  /// @param roleId The role identifier.
  struct TargetFunctionRoleUpdate {
    address authority;
    address target;
    bytes4[] selectors;
    uint64 roleId;
  }

  /// @notice Parameters for setting target admin delay via AccessManager.
  /// @param authority The AccessManager address.
  /// @param target The target contract address.
  /// @param newDelay The new admin delay.
  struct TargetAdminDelayUpdate {
    address authority;
    address target;
    uint32 newDelay;
  }

  /// @notice Lists new assets on hubs via the HubConfigurator.
  /// @param listings The asset listings to execute.
  function executeHubAssetListings(AssetListing[] calldata listings) external;

  /// @notice Updates asset config (fee, interest rate, reinvestment) on hubs.
  /// @param updates The asset config updates to execute.
  function executeHubAssetConfigUpdates(AssetConfigUpdate[] calldata updates) external;

  /// @notice Registers spokes for multiple assets on hubs.
  /// @param additions The spoke-to-assets additions to execute.
  function executeHubSpokeToAssetsAdditions(SpokeToAssetsAddition[] calldata additions) external;

  /// @notice Updates spoke config (caps, risk premium threshold, status) on hubs.
  /// @param updates The spoke config updates to execute.
  function executeHubSpokeConfigUpdates(SpokeConfigUpdate[] calldata updates) external;

  /// @notice Halts assets on hubs.
  /// @param halts The asset halts to execute.
  function executeHubAssetHalts(AssetHalt[] calldata halts) external;

  /// @notice Deactivates assets on hubs.
  /// @param deactivations The asset deactivations to execute.
  function executeHubAssetDeactivations(AssetDeactivation[] calldata deactivations) external;

  /// @notice Resets asset caps on hubs.
  /// @param resets The asset caps resets to execute.
  function executeHubAssetCapsResets(AssetCapsReset[] calldata resets) external;

  /// @notice Halts spokes on hubs.
  /// @param halts The spoke halts to execute.
  function executeHubSpokeHalts(SpokeHalt[] calldata halts) external;

  /// @notice Deactivates spokes on hubs.
  /// @param deactivations The spoke deactivations to execute.
  function executeHubSpokeDeactivations(SpokeDeactivation[] calldata deactivations) external;

  /// @notice Resets spoke caps on hubs.
  /// @param resets The spoke caps resets to execute.
  function executeHubSpokeCapsResets(SpokeCapsReset[] calldata resets) external;

  /// @notice Lists new reserves on spokes.
  /// @param listings The reserve listings to execute.
  function executeSpokeReserveListings(ReserveListing[] calldata listings) external;

  /// @notice Updates reserve config on spokes.
  /// @param updates The reserve config updates to execute.
  function executeSpokeReserveConfigUpdates(ReserveConfigUpdate[] calldata updates) external;

  /// @notice Updates liquidation config on spokes.
  /// @param updates The liquidation config updates to execute.
  function executeSpokeLiquidationConfigUpdates(
    LiquidationConfigUpdate[] calldata updates
  ) external;

  /// @notice Adds dynamic reserve configs on spokes.
  /// @param additions The dynamic reserve config additions to execute.
  function executeSpokeDynamicReserveConfigAdditions(
    DynamicReserveConfigAddition[] calldata additions
  ) external;

  /// @notice Updates dynamic reserve configs on spokes.
  /// @param updates The dynamic reserve config updates to execute.
  function executeSpokeDynamicReserveConfigUpdates(
    DynamicReserveConfigUpdate[] calldata updates
  ) external;

  /// @notice Pauses all reserves on spokes.
  /// @param pauses The spoke pauses to execute.
  function executeSpokeAllReservesPauses(SpokePause[] calldata pauses) external;

  /// @notice Freezes all reserves on spokes.
  /// @param freezes The spoke freezes to execute.
  function executeSpokeAllReservesFreezes(SpokeFreeze[] calldata freezes) external;

  /// @notice Updates position managers on spokes.
  /// @param updates The position manager updates to execute.
  function executeSpokePositionManagerUpdates(PositionManagerUpdate[] calldata updates) external;

  /// @notice Registers/deregisters spokes on position managers.
  /// @param registrations The spoke registrations to execute.
  function executePositionManagerSpokeRegistrations(
    SpokeRegistration[] calldata registrations
  ) external;

  /// @notice Rescues ERC20 tokens and/or native assets from position managers.
  /// @param rescues The rescues to execute.
  function executePositionManagerRescues(Rescue[] calldata rescues) external;

  /// @notice Renounces position manager roles for users on spokes.
  /// @param renouncements The role renouncements to execute.
  function executePositionManagerRoleRenouncements(
    PositionManagerRoleRenouncement[] calldata renouncements
  ) external;

  /// @notice Grants or revokes roles via AccessManager.
  /// @param memberships The role memberships to execute.
  function executeRoleMemberships(RoleMembership[] calldata memberships) external;

  /// @notice Updates role configuration (admin, guardian, grant delay, label) via AccessManager.
  /// @param updates The role updates to execute.
  function executeRoleUpdates(RoleUpdate[] calldata updates) external;

  /// @notice Updates target function roles via AccessManager.
  /// @param updates The target function role updates to execute.
  function executeTargetFunctionRoleUpdates(TargetFunctionRoleUpdate[] calldata updates) external;

  /// @notice Updates target admin delays via AccessManager.
  /// @param updates The target admin delay updates to execute.
  function executeTargetAdminDelayUpdates(TargetAdminDelayUpdate[] calldata updates) external;
}
