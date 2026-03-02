# Aave V4 config engine

## What is the AaveV4ConfigEngine?

The `AaveV4ConfigEngine` is a helper smart contract to abstract best practices when interacting with the Aave V4 protocol via governance payloads, without modifying core contracts.

Based on experience reviewing governance payloads for Aave V3, the config engine provides a type-safe, composable interface that covers the most common administrative operations: Hub configuration, Spoke configuration, AccessManager role management, and PositionManager administration.

The engine itself is **stateless** — it never stores data of its own. Payloads invoke it via `delegatecall`, so every external call the engine makes executes in the payload's (governance executor's) context and with the executor's permissions.

## How to use the engine?

Instead of calling `AaveV4ConfigEngine` directly, payload authors inherit from the **`AaveV4Payload`** abstract base contract. `AaveV4Payload` receives the engine address in its constructor and exposes virtual functions — one per action type — that return empty arrays by default. The payload simply overrides the functions relevant to the proposal, returning the desired configuration structs.

When governance calls `execute()`, the base contract loops through each action category and delegate-calls the engine for every non-empty array.

### Action categories

The four groups, and the virtual functions in each, are listed below.

#### Hub actions (`_executeHubActions`)

| Function                                | Struct                            | Purpose                              |
| --------------------------------------- | --------------------------------- | ------------------------------------ |
| `hubAssetListings()`                    | `AssetListing`                    | List a new asset on a Hub            |
| `hubFeeConfigUpdates()`                 | `FeeConfigUpdate`                 | Update liquidity fee / fee receiver  |
| `hubInterestRateUpdates()`              | `InterestRateUpdate`              | Update IR strategy or IR data        |
| `hubReinvestmentControllerUpdates()`    | `ReinvestmentControllerUpdate`    | Update reinvestment controller       |
| `hubSpokeAdditions()`                   | `SpokeAddition`                   | Add a Spoke to a Hub for an asset    |
| `hubSpokeToAssetsAdditions()`           | `SpokeToAssetsAddition`           | Register a Spoke for multiple assets |
| `hubSpokeCapsUpdates()`                 | `SpokeCapsUpdate`                 | Update Spoke add/draw caps           |
| `hubSpokeRiskPremiumThresholdUpdates()` | `SpokeRiskPremiumThresholdUpdate` | Update risk premium threshold        |
| `hubSpokeStatusUpdates()`               | `SpokeStatusUpdate`               | Update Spoke active/halted status    |
| `hubAssetHalts()`                       | `AssetHalt`                       | Halt an asset                        |
| `hubAssetDeactivations()`               | `AssetDeactivation`               | Deactivate an asset                  |
| `hubAssetCapsResets()`                  | `AssetCapsReset`                  | Reset asset caps                     |
| `hubSpokeHalts()`                       | `SpokeHalt`                       | Halt a Spoke                         |
| `hubSpokeDeactivations()`               | `SpokeDeactivation`               | Deactivate a Spoke                   |
| `hubSpokeCapsResets()`                  | `SpokeCapsReset`                  | Reset Spoke caps                     |

#### Spoke actions (`_executeSpokeActions`)

| Function                               | Struct                         | Purpose                                                                  |
| -------------------------------------- | ------------------------------ | ------------------------------------------------------------------------ |
| `spokeReserveListings()`               | `ReserveListing`               | List a new reserve on a Spoke                                            |
| `spokeReserveConfigUpdates()`          | `ReserveConfigUpdate`          | Update collateral risk, paused, frozen, borrowable, receiveSharesEnabled |
| `spokeReservePriceSourceUpdates()`     | `ReservePriceSourceUpdate`     | Update reserve price source                                              |
| `spokeLiquidationConfigUpdates()`      | `LiquidationConfigUpdate`      | Update liquidation config                                                |
| `spokeDynamicReserveConfigAdditions()` | `DynamicReserveConfigAddition` | Add a dynamic reserve config                                             |
| `spokeDynamicReserveConfigUpdates()`   | `DynamicReserveConfigUpdate`   | Update a dynamic reserve config                                          |
| `spokeCollateralFactorAdditions()`     | `CollateralFactorAddition`     | Add a collateral factor                                                  |
| `spokeCollateralFactorUpdates()`       | `CollateralFactorUpdate`       | Update a collateral factor                                               |
| `spokeMaxLiquidationBonusAdditions()`  | `MaxLiquidationBonusAddition`  | Add max liquidation bonus                                                |
| `spokeMaxLiquidationBonusUpdates()`    | `MaxLiquidationBonusUpdate`    | Update max liquidation bonus                                             |
| `spokeLiquidationFeeAdditions()`       | `LiquidationFeeAddition`       | Add liquidation fee                                                      |
| `spokeLiquidationFeeUpdates()`         | `LiquidationFeeUpdate`         | Update liquidation fee                                                   |
| `spokeAllReservesPauses()`             | `SpokePause`                   | Pause all reserves on a Spoke                                            |
| `spokeAllReservesFreezes()`            | `SpokeFreeze`                  | Freeze all reserves on a Spoke                                           |
| `spokeReservePauses()`                 | `ReservePause`                 | Pause a single reserve                                                   |
| `spokeReserveFreezes()`                | `ReserveFreeze`                | Freeze a single reserve                                                  |
| `spokePositionManagerUpdates()`        | `PositionManagerUpdate`        | Activate/deactivate a PositionManager on a Spoke                         |

#### AccessManager actions (`_executeAccessManagerActions`)

| Function                                   | Struct                     | Purpose                 |
| ------------------------------------------ | -------------------------- | ----------------------- |
| `accessManagerRoleGrants()`                | `RoleGrant`                | Grant a role            |
| `accessManagerRoleRevocations()`           | `RoleRevocation`           | Revoke a role           |
| `accessManagerRoleAdminUpdates()`          | `RoleAdminUpdate`          | Set role admin          |
| `accessManagerRoleGuardianUpdates()`       | `RoleGuardianUpdate`       | Set role guardian       |
| `accessManagerTargetFunctionRoleUpdates()` | `TargetFunctionRoleUpdate` | Map selectors to a role |
| `accessManagerTargetClosedUpdates()`       | `TargetClosedUpdate`       | Open/close a target     |
| `accessManagerRoleLabelUpdates()`          | `RoleLabelUpdate`          | Label a role            |
| `accessManagerGrantDelayUpdates()`         | `GrantDelayUpdate`         | Set grant delay         |
| `accessManagerTargetAdminDelayUpdates()`   | `TargetAdminDelayUpdate`   | Set target admin delay  |

Convenience helpers are also available for granting well-known roles by name (e.g. `hubConfiguratorFeeUpdaterRoleGrants()`, `spokeConfiguratorAdminRoleGrants()`, `hubConfiguratorAllRoleGrants()`, `spokeConfiguratorAllRoleGrants()`, etc.).

#### PositionManager actions (`_executePositionManagerActions`)

| Function                              | Struct                            | Purpose                         |
| ------------------------------------- | --------------------------------- | ------------------------------- |
| `positionManagerSpokeRegistrations()` | `SpokeRegistration`               | Register/deregister a Spoke     |
| `positionManagerTokenRescues()`       | `TokenRescue`                     | Rescue ERC-20 tokens            |
| `positionManagerNativeRescues()`      | `NativeRescue`                    | Rescue native assets            |
| `positionManagerRoleRenouncements()`  | `PositionManagerRoleRenouncement` | Renounce a PositionManager role |

## Internal aspects to consider

### Execution hooks

`AaveV4Payload` exposes two virtual hooks:

- **`_preExecute()`** — called before any engine action.
- **`_postExecute()`** — called after all engine actions complete.

Override these to add custom logic (e.g. granting temporary permissions before the batch and revoking them afterwards).

### Execution ordering

When `execute()` is called, actions run in the following fixed order:

1. `_preExecute()`
2. **Hub actions** (in order):
   1. Asset listings
   2. Fee config updates
   3. Interest rate updates
   4. Reinvestment controller updates
   5. Spoke additions
   6. Spoke-to-assets additions
   7. Spoke caps updates
   8. Spoke risk premium threshold updates
   9. Spoke status updates
   10. Asset halts
   11. Asset deactivations
   12. Asset caps resets
   13. Spoke halts
   14. Spoke deactivations
   15. Spoke caps resets
3. **Spoke actions** (in order):
   1. Reserve listings
   2. Reserve config updates
   3. Reserve price source updates
   4. Liquidation config updates
   5. Dynamic reserve config additions
   6. Dynamic reserve config updates
   7. Collateral factor additions
   8. Collateral factor updates
   9. Max liquidation bonus additions
   10. Max liquidation bonus updates
   11. Liquidation fee additions
   12. Liquidation fee updates
   13. All-reserves pauses
   14. All-reserves freezes
   15. Reserve pauses
   16. Reserve freezes
   17. Position manager updates
4. **AccessManager actions** (in order):
   1. Role grants
   2. Role revocations
   3. Role admin updates
   4. Role guardian updates
   5. Target function role updates
   6. Target closed updates
   7. Role label updates
   8. Grant delay updates
   9. Target admin delay updates
   10. Convenience role grants (HubConfigurator roles, then SpokeConfigurator roles)
5. **PositionManager actions** (in order):
   1. Spoke registrations
   2. Token rescues
   3. Native rescues
   4. Role renouncements
6. `_postExecute()`

### The `KEEP_CURRENT` sentinel pattern

The `EngineFlags` library defines two sentinel values:

| Constant               | Type      | Value                        |
| ---------------------- | --------- | ---------------------------- |
| `KEEP_CURRENT`         | `uint256` | `type(uint256).max`          |
| `KEEP_CURRENT_ADDRESS` | `address` | `address(type(uint160).max)` |

When a struct field is set to its corresponding sentinel, the engine **skips** updating that field and leaves the on-chain value unchanged. This lets a single struct express partial updates — for example, changing the liquidity fee without touching the fee receiver.

`EngineFlags` also provides boolean convenience constants (`ENABLED = 1`, `DISABLED = 0`) and conversion helpers `toBool(uint256)` / `fromBool(bool)`.

### Smart partial updates

Several engine functions inspect which fields differ from `KEEP_CURRENT` and choose the most efficient on-chain call:

- **Fee config** (`HubEngine.executeHubFeeConfigUpdates`) — calls `updateFeeConfig` when both fee and receiver change, `updateLiquidityFee` or `updateFeeReceiver` when only one changes.
- **Spoke caps** (`HubEngine.executeHubSpokeCapsUpdates`) — calls `updateSpokeCaps`, `updateSpokeSupplyCap`, or `updateSpokeDrawCap` depending on which caps are modified.
- **Liquidation config** (`SpokeEngine.executeSpokeLiquidationConfigUpdates`) — calls `updateLiquidationConfig` when all three fields change, otherwise updates each field individually.
- **Dynamic reserve config** (`SpokeEngine.executeSpokeDynamicReserveConfigUpdates`) — reads the current on-chain config, patches only the non-sentinel fields, and writes back the merged result. If nothing changed, the external call is skipped entirely.
- **Reserve config** (`SpokeEngine.executeSpokeReserveConfigUpdates`) — each flag (collateralRisk, paused, frozen, borrowable, receiveSharesEnabled) is updated individually only when it differs from `KEEP_CURRENT`.
- **Spoke status** (`HubEngine.executeHubSpokeStatusUpdates`) — active and halted flags are each updated independently only when not `KEEP_CURRENT`.

### Delegatecall architecture

`AaveV4ConfigEngine` is deployed once and shared across all payloads. Payloads do **not** call the engine via a regular call — they use `delegatecall` (via OpenZeppelin's `Address.functionDelegateCall`). This means:

- The engine's code runs in the **payload's storage and `msg.sender` context** (i.e. the governance executor).
- The engine itself holds no storage, no permissions, and no admin keys.
- All HubConfigurator, SpokeConfigurator, AccessManager, and PositionManager calls originate from the governance executor's address.
