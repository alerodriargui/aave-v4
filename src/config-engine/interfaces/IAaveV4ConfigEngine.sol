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

  /// @notice Parameters for updating fee config of an asset on a hub.
  /// @param hubConfigurator The HubConfigurator to use for this action.
  /// @param hub The address of the Hub.
  /// @param assetId The identifier of the asset.
  /// @param liquidityFee The new liquidity fee (KEEP_CURRENT to skip).
  /// @param feeReceiver The new fee receiver (KEEP_CURRENT_ADDRESS to skip).
  struct FeeConfigUpdate {
    IHubConfigurator hubConfigurator;
    address hub;
    uint256 assetId;
    uint256 liquidityFee;
    address feeReceiver;
  }

  /// @notice Parameters for updating interest rate config of an asset on a hub.
  /// @param hubConfigurator The HubConfigurator to use for this action.
  /// @param hub The address of the Hub.
  /// @param assetId The identifier of the asset.
  /// @param irStrategy The new interest rate strategy (KEEP_CURRENT_ADDRESS to skip strategy update).
  /// @param irData The interest rate data. If irStrategy != KEEP_CURRENT_ADDRESS, calls updateInterestRateStrategy.
  ///   Otherwise if irData.length > 0, calls updateInterestRateData.
  struct InterestRateUpdate {
    IHubConfigurator hubConfigurator;
    address hub;
    uint256 assetId;
    address irStrategy;
    bytes irData;
  }

  /// @notice Parameters for updating the reinvestment controller of an asset on a hub.
  /// @param hubConfigurator The HubConfigurator to use for this action.
  /// @param hub The address of the Hub.
  /// @param assetId The identifier of the asset.
  /// @param reinvestmentController The new reinvestment controller address.
  struct ReinvestmentControllerUpdate {
    IHubConfigurator hubConfigurator;
    address hub;
    uint256 assetId;
    address reinvestmentController;
  }

  /// @notice Parameters for adding a spoke to a hub for a specific asset.
  /// @param hubConfigurator The HubConfigurator to use for this action.
  /// @param hub The address of the Hub.
  /// @param spoke The address of the Spoke.
  /// @param assetId The identifier of the asset.
  /// @param config The Spoke configuration to register.
  struct SpokeAddition {
    IHubConfigurator hubConfigurator;
    address hub;
    address spoke;
    uint256 assetId;
    IHub.SpokeConfig config;
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

  /// @notice Parameters for updating spoke caps on a hub.
  /// @param hubConfigurator The HubConfigurator to use for this action.
  /// @param hub The address of the Hub.
  /// @param assetId The identifier of the asset.
  /// @param spoke The address of the Spoke.
  /// @param addCap The new add cap (KEEP_CURRENT to skip).
  /// @param drawCap The new draw cap (KEEP_CURRENT to skip).
  struct SpokeCapsUpdate {
    IHubConfigurator hubConfigurator;
    address hub;
    uint256 assetId;
    address spoke;
    uint256 addCap;
    uint256 drawCap;
  }

  /// @notice Parameters for updating spoke risk premium threshold.
  /// @param hubConfigurator The HubConfigurator to use for this action.
  /// @param hub The address of the Hub.
  /// @param assetId The identifier of the asset.
  /// @param spoke The address of the Spoke.
  /// @param riskPremiumThreshold The new risk premium threshold.
  struct SpokeRiskPremiumThresholdUpdate {
    IHubConfigurator hubConfigurator;
    address hub;
    uint256 assetId;
    address spoke;
    uint256 riskPremiumThreshold;
  }

  /// @notice Parameters for updating spoke status (active/halted).
  /// @param hubConfigurator The HubConfigurator to use for this action.
  /// @param hub The address of the Hub.
  /// @param assetId The identifier of the asset.
  /// @param spoke The address of the Spoke.
  /// @param active New active flag (0=false, 1=true, KEEP_CURRENT=skip).
  /// @param halted New halted flag (0=false, 1=true, KEEP_CURRENT=skip).
  struct SpokeStatusUpdate {
    IHubConfigurator hubConfigurator;
    address hub;
    uint256 assetId;
    address spoke;
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
  /// @param collateralRisk New collateral risk (KEEP_CURRENT to skip).
  /// @param paused New paused flag (0=false, 1=true, KEEP_CURRENT=skip).
  /// @param frozen New frozen flag (0=false, 1=true, KEEP_CURRENT=skip).
  /// @param borrowable New borrowable flag (0=false, 1=true, KEEP_CURRENT=skip).
  /// @param receiveSharesEnabled New receiveSharesEnabled flag (0=false, 1=true, KEEP_CURRENT=skip).
  struct ReserveConfigUpdate {
    ISpokeConfigurator spokeConfigurator;
    address spoke;
    uint256 reserveId;
    uint256 collateralRisk;
    uint256 paused;
    uint256 frozen;
    uint256 borrowable;
    uint256 receiveSharesEnabled;
  }

  /// @notice Parameters for updating reserve price source on a spoke.
  /// @param spokeConfigurator The SpokeConfigurator to use for this action.
  /// @param spoke The address of the Spoke.
  /// @param reserveId The identifier of the reserve.
  /// @param priceSource The new price source address.
  struct ReservePriceSourceUpdate {
    ISpokeConfigurator spokeConfigurator;
    address spoke;
    uint256 reserveId;
    address priceSource;
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

  /// @notice Parameters for adding a collateral factor to a reserve.
  /// @param spokeConfigurator The SpokeConfigurator to use for this action.
  /// @param spoke The address of the Spoke.
  /// @param reserveId The identifier of the reserve.
  /// @param collateralFactor The new collateral factor.
  struct CollateralFactorAddition {
    ISpokeConfigurator spokeConfigurator;
    address spoke;
    uint256 reserveId;
    uint256 collateralFactor;
  }

  /// @notice Parameters for updating a collateral factor on a reserve.
  /// @param spokeConfigurator The SpokeConfigurator to use for this action.
  /// @param spoke The address of the Spoke.
  /// @param reserveId The identifier of the reserve.
  /// @param dynamicConfigKey The key of the dynamic config to update.
  /// @param collateralFactor The new collateral factor.
  struct CollateralFactorUpdate {
    ISpokeConfigurator spokeConfigurator;
    address spoke;
    uint256 reserveId;
    uint256 dynamicConfigKey;
    uint256 collateralFactor;
  }

  /// @notice Parameters for adding a max liquidation bonus to a reserve.
  /// @param spokeConfigurator The SpokeConfigurator to use for this action.
  /// @param spoke The address of the Spoke.
  /// @param reserveId The identifier of the reserve.
  /// @param maxLiquidationBonus The new max liquidation bonus.
  struct MaxLiquidationBonusAddition {
    ISpokeConfigurator spokeConfigurator;
    address spoke;
    uint256 reserveId;
    uint256 maxLiquidationBonus;
  }

  /// @notice Parameters for updating a max liquidation bonus on a reserve.
  /// @param spokeConfigurator The SpokeConfigurator to use for this action.
  /// @param spoke The address of the Spoke.
  /// @param reserveId The identifier of the reserve.
  /// @param dynamicConfigKey The key of the dynamic config to update.
  /// @param maxLiquidationBonus The new max liquidation bonus.
  struct MaxLiquidationBonusUpdate {
    ISpokeConfigurator spokeConfigurator;
    address spoke;
    uint256 reserveId;
    uint256 dynamicConfigKey;
    uint256 maxLiquidationBonus;
  }

  /// @notice Parameters for adding a liquidation fee to a reserve.
  /// @param spokeConfigurator The SpokeConfigurator to use for this action.
  /// @param spoke The address of the Spoke.
  /// @param reserveId The identifier of the reserve.
  /// @param liquidationFee The new liquidation fee.
  struct LiquidationFeeAddition {
    ISpokeConfigurator spokeConfigurator;
    address spoke;
    uint256 reserveId;
    uint256 liquidationFee;
  }

  /// @notice Parameters for updating a liquidation fee on a reserve.
  /// @param spokeConfigurator The SpokeConfigurator to use for this action.
  /// @param spoke The address of the Spoke.
  /// @param reserveId The identifier of the reserve.
  /// @param dynamicConfigKey The key of the dynamic config to update.
  /// @param liquidationFee The new liquidation fee.
  struct LiquidationFeeUpdate {
    ISpokeConfigurator spokeConfigurator;
    address spoke;
    uint256 reserveId;
    uint256 dynamicConfigKey;
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

  /// @notice Parameters for pausing a single reserve on a spoke.
  /// @param spokeConfigurator The SpokeConfigurator to use for this action.
  /// @param spoke The address of the Spoke.
  /// @param reserveId The identifier of the reserve.
  struct ReservePause {
    ISpokeConfigurator spokeConfigurator;
    address spoke;
    uint256 reserveId;
  }

  /// @notice Parameters for freezing a single reserve on a spoke.
  /// @param spokeConfigurator The SpokeConfigurator to use for this action.
  /// @param spoke The address of the Spoke.
  /// @param reserveId The identifier of the reserve.
  struct ReserveFreeze {
    ISpokeConfigurator spokeConfigurator;
    address spoke;
    uint256 reserveId;
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

  /// @notice Parameters for rescuing ERC20 tokens from a position manager.
  /// @param positionManager The position manager address.
  /// @param token The address of the ERC20 token to rescue.
  /// @param to The address to send the rescued tokens to.
  /// @param amount The amount of tokens to rescue.
  struct TokenRescue {
    address positionManager;
    address token;
    address to;
    uint256 amount;
  }

  /// @notice Parameters for rescuing native assets from a position manager.
  /// @param positionManager The position manager address.
  /// @param to The address to send the rescued native assets to.
  /// @param amount The amount of native assets to rescue.
  struct NativeRescue {
    address positionManager;
    address to;
    uint256 amount;
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

  /// @notice Parameters for granting a role via AccessManager.
  /// @param authority The AccessManager address.
  /// @param roleId The role identifier.
  /// @param account The account to grant the role to.
  /// @param executionDelay The execution delay for the account.
  struct RoleGrant {
    address authority;
    uint64 roleId;
    address account;
    uint32 executionDelay;
  }

  /// @notice Parameters for revoking a role via AccessManager.
  /// @param authority The AccessManager address.
  /// @param roleId The role identifier.
  /// @param account The account to revoke the role from.
  struct RoleRevocation {
    address authority;
    uint64 roleId;
    address account;
  }

  /// @notice Parameters for setting a role admin via AccessManager.
  /// @param authority The AccessManager address.
  /// @param roleId The role identifier.
  /// @param admin The new admin role identifier.
  struct RoleAdminUpdate {
    address authority;
    uint64 roleId;
    uint64 admin;
  }

  /// @notice Parameters for setting a role guardian via AccessManager.
  /// @param authority The AccessManager address.
  /// @param roleId The role identifier.
  /// @param guardian The new guardian role identifier.
  struct RoleGuardianUpdate {
    address authority;
    uint64 roleId;
    uint64 guardian;
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

  /// @notice Parameters for setting target closed status via AccessManager.
  /// @param authority The AccessManager address.
  /// @param target The target contract address.
  /// @param closed Whether the target is closed.
  struct TargetClosedUpdate {
    address authority;
    address target;
    bool closed;
  }

  /// @notice Parameters for labelling a role via AccessManager.
  /// @param authority The AccessManager address.
  /// @param roleId The role identifier.
  /// @param label The label string.
  struct RoleLabelUpdate {
    address authority;
    uint64 roleId;
    string label;
  }

  /// @notice Parameters for setting grant delay via AccessManager.
  /// @param authority The AccessManager address.
  /// @param roleId The role identifier.
  /// @param newDelay The new grant delay.
  struct GrantDelayUpdate {
    address authority;
    uint64 roleId;
    uint32 newDelay;
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

  /// @notice Convenience struct for granting a named role.
  /// @param authority The AccessManager address.
  /// @param account The account to grant the role to.
  struct RoleGrantByName {
    address authority;
    address account;
  }

  /// @notice Lists new assets on hubs via the HubConfigurator.
  /// @param listings The asset listings to execute.
  function executeHubAssetListings(AssetListing[] calldata listings) external;

  /// @notice Updates fee config for assets on hubs.
  /// @param updates The fee config updates to execute.
  function executeHubFeeConfigUpdates(FeeConfigUpdate[] calldata updates) external;

  /// @notice Updates interest rate config for assets on hubs.
  /// @param updates The interest rate updates to execute.
  function executeHubInterestRateUpdates(InterestRateUpdate[] calldata updates) external;

  /// @notice Updates reinvestment controllers for assets on hubs.
  /// @param updates The reinvestment controller updates to execute.
  function executeHubReinvestmentControllerUpdates(
    ReinvestmentControllerUpdate[] calldata updates
  ) external;

  /// @notice Adds spokes to hubs for specific assets.
  /// @param additions The spoke additions to execute.
  function executeHubSpokeAdditions(SpokeAddition[] calldata additions) external;

  /// @notice Registers spokes for multiple assets on hubs.
  /// @param additions The spoke-to-assets additions to execute.
  function executeHubSpokeToAssetsAdditions(SpokeToAssetsAddition[] calldata additions) external;

  /// @notice Updates spoke caps on hubs.
  /// @param updates The spoke caps updates to execute.
  function executeHubSpokeCapsUpdates(SpokeCapsUpdate[] calldata updates) external;

  /// @notice Updates spoke risk premium thresholds on hubs.
  /// @param updates The spoke risk premium threshold updates to execute.
  function executeHubSpokeRiskPremiumThresholdUpdates(
    SpokeRiskPremiumThresholdUpdate[] calldata updates
  ) external;

  /// @notice Updates spoke status (active/halted) on hubs.
  /// @param updates The spoke status updates to execute.
  function executeHubSpokeStatusUpdates(SpokeStatusUpdate[] calldata updates) external;

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

  /// @notice Updates reserve price sources on spokes.
  /// @param updates The reserve price source updates to execute.
  function executeSpokeReservePriceSourceUpdates(
    ReservePriceSourceUpdate[] calldata updates
  ) external;

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

  /// @notice Adds collateral factors on spokes.
  /// @param additions The collateral factor additions to execute.
  function executeSpokeCollateralFactorAdditions(
    CollateralFactorAddition[] calldata additions
  ) external;

  /// @notice Updates collateral factors on spokes.
  /// @param updates The collateral factor updates to execute.
  function executeSpokeCollateralFactorUpdates(CollateralFactorUpdate[] calldata updates) external;

  /// @notice Adds max liquidation bonuses on spokes.
  /// @param additions The max liquidation bonus additions to execute.
  function executeSpokeMaxLiquidationBonusAdditions(
    MaxLiquidationBonusAddition[] calldata additions
  ) external;

  /// @notice Updates max liquidation bonuses on spokes.
  /// @param updates The max liquidation bonus updates to execute.
  function executeSpokeMaxLiquidationBonusUpdates(
    MaxLiquidationBonusUpdate[] calldata updates
  ) external;

  /// @notice Adds liquidation fees on spokes.
  /// @param additions The liquidation fee additions to execute.
  function executeSpokeLiquidationFeeAdditions(
    LiquidationFeeAddition[] calldata additions
  ) external;

  /// @notice Updates liquidation fees on spokes.
  /// @param updates The liquidation fee updates to execute.
  function executeSpokeLiquidationFeeUpdates(LiquidationFeeUpdate[] calldata updates) external;

  /// @notice Pauses all reserves on spokes.
  /// @param pauses The spoke pauses to execute.
  function executeSpokeAllReservesPauses(SpokePause[] calldata pauses) external;

  /// @notice Freezes all reserves on spokes.
  /// @param freezes The spoke freezes to execute.
  function executeSpokeAllReservesFreezes(SpokeFreeze[] calldata freezes) external;

  /// @notice Pauses individual reserves on spokes.
  /// @param pauses The reserve pauses to execute.
  function executeSpokeReservePauses(ReservePause[] calldata pauses) external;

  /// @notice Freezes individual reserves on spokes.
  /// @param freezes The reserve freezes to execute.
  function executeSpokeReserveFreezes(ReserveFreeze[] calldata freezes) external;

  /// @notice Updates position managers on spokes.
  /// @param updates The position manager updates to execute.
  function executeSpokePositionManagerUpdates(PositionManagerUpdate[] calldata updates) external;

  /// @notice Registers/deregisters spokes on position managers.
  /// @param registrations The spoke registrations to execute.
  function executePositionManagerSpokeRegistrations(
    SpokeRegistration[] calldata registrations
  ) external;

  /// @notice Rescues ERC20 tokens from position managers.
  /// @param rescues The token rescues to execute.
  function executePositionManagerTokenRescues(TokenRescue[] calldata rescues) external;

  /// @notice Rescues native assets from position managers.
  /// @param rescues The native rescues to execute.
  function executePositionManagerNativeRescues(NativeRescue[] calldata rescues) external;

  /// @notice Renounces position manager roles for users on spokes.
  /// @param renouncements The role renouncements to execute.
  function executePositionManagerRoleRenouncements(
    PositionManagerRoleRenouncement[] calldata renouncements
  ) external;

  /// @notice Grants roles via AccessManager.
  /// @param grants The role grants to execute.
  function executeRoleGrants(RoleGrant[] calldata grants) external;

  /// @notice Revokes roles via AccessManager.
  /// @param revocations The role revocations to execute.
  function executeRoleRevocations(RoleRevocation[] calldata revocations) external;

  /// @notice Updates role admins via AccessManager.
  /// @param updates The role admin updates to execute.
  function executeRoleAdminUpdates(RoleAdminUpdate[] calldata updates) external;

  /// @notice Updates role guardians via AccessManager.
  /// @param updates The role guardian updates to execute.
  function executeRoleGuardianUpdates(RoleGuardianUpdate[] calldata updates) external;

  /// @notice Updates target function roles via AccessManager.
  /// @param updates The target function role updates to execute.
  function executeTargetFunctionRoleUpdates(TargetFunctionRoleUpdate[] calldata updates) external;

  /// @notice Updates target closed status via AccessManager.
  /// @param updates The target closed updates to execute.
  function executeTargetClosedUpdates(TargetClosedUpdate[] calldata updates) external;

  /// @notice Updates role labels via AccessManager.
  /// @param updates The role label updates to execute.
  function executeRoleLabelUpdates(RoleLabelUpdate[] calldata updates) external;

  /// @notice Updates grant delays via AccessManager.
  /// @param updates The grant delay updates to execute.
  function executeGrantDelayUpdates(GrantDelayUpdate[] calldata updates) external;

  /// @notice Updates target admin delays via AccessManager.
  /// @param updates The target admin delay updates to execute.
  function executeTargetAdminDelayUpdates(TargetAdminDelayUpdate[] calldata updates) external;

  /// @notice Grants the HubConfigurator fee updater role.
  /// @param grants The role grants to execute.
  function executeGrantHubConfiguratorFeeUpdaterRole(RoleGrantByName[] calldata grants) external;

  /// @notice Grants the HubConfigurator reinvestment updater role.
  /// @param grants The role grants to execute.
  function executeGrantHubConfiguratorReinvestmentUpdaterRole(
    RoleGrantByName[] calldata grants
  ) external;

  /// @notice Grants the HubConfigurator asset lister role.
  /// @param grants The role grants to execute.
  function executeGrantHubConfiguratorAssetListerRole(RoleGrantByName[] calldata grants) external;

  /// @notice Grants the HubConfigurator spoke adder role.
  /// @param grants The role grants to execute.
  function executeGrantHubConfiguratorSpokeAdderRole(RoleGrantByName[] calldata grants) external;

  /// @notice Grants the HubConfigurator interest rate updater role.
  /// @param grants The role grants to execute.
  function executeGrantHubConfiguratorInterestRateUpdaterRole(
    RoleGrantByName[] calldata grants
  ) external;

  /// @notice Grants the HubConfigurator halter role.
  /// @param grants The role grants to execute.
  function executeGrantHubConfiguratorHalterRole(RoleGrantByName[] calldata grants) external;

  /// @notice Grants the HubConfigurator deactivater role.
  /// @param grants The role grants to execute.
  function executeGrantHubConfiguratorDeactivaterRole(RoleGrantByName[] calldata grants) external;

  /// @notice Grants the HubConfigurator caps updater role.
  /// @param grants The role grants to execute.
  function executeGrantHubConfiguratorCapsUpdaterRole(RoleGrantByName[] calldata grants) external;

  /// @notice Grants all HubConfigurator roles.
  /// @param grants The role grants to execute.
  function executeGrantHubConfiguratorAllRoles(RoleGrantByName[] calldata grants) external;

  /// @notice Grants the SpokeConfigurator admin role.
  /// @param grants The role grants to execute.
  function executeGrantSpokeConfiguratorAdminRole(RoleGrantByName[] calldata grants) external;

  /// @notice Grants the SpokeConfigurator liquidation updater role.
  /// @param grants The role grants to execute.
  function executeGrantSpokeConfiguratorLiquidationUpdaterRole(
    RoleGrantByName[] calldata grants
  ) external;

  /// @notice Grants the SpokeConfigurator reserve adder role.
  /// @param grants The role grants to execute.
  function executeGrantSpokeConfiguratorReserveAdderRole(
    RoleGrantByName[] calldata grants
  ) external;

  /// @notice Grants the SpokeConfigurator freezer role.
  /// @param grants The role grants to execute.
  function executeGrantSpokeConfiguratorFreezerRole(RoleGrantByName[] calldata grants) external;

  /// @notice Grants the SpokeConfigurator pauser role.
  /// @param grants The role grants to execute.
  function executeGrantSpokeConfiguratorPauserRole(RoleGrantByName[] calldata grants) external;

  /// @notice Grants all SpokeConfigurator roles.
  /// @param grants The role grants to execute.
  function executeGrantSpokeConfiguratorAllRoles(RoleGrantByName[] calldata grants) external;
}
