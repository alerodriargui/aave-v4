// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity 0.8.28;

import {SafeCast} from 'src/dependencies/openzeppelin/SafeCast.sol';
import {MathUtils} from 'src/libraries/math/MathUtils.sol';
import {WadRayMath} from 'src/libraries/math/WadRayMath.sol';
import {KeyValueList} from 'src/spoke/libraries/KeyValueList.sol';
import {RiskFreeLiquidationLogic} from 'src/spoke/libraries/RiskFreeLiquidationLogic.sol';
import {Spoke} from 'src/spoke/Spoke.sol';
import {IHubBase} from 'src/hub/interfaces/IHubBase.sol';
import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';

/// @title RiskFreeSpoke
/// @author Aave Labs
/// @notice Spoke contract without premium/risk premium functionality.
/// @dev Debt is simply drawnShares.toAssets() without any premium calculations.
/// @dev Hub interface remains unchanged - we pass PremiumDelta(0,0,0) to hub functions.
abstract contract RiskFreeSpoke is Spoke {
  using SafeCast for *;
  using MathUtils for *;
  using WadRayMath for *;

  /// @dev Constructor.
  /// @param oracle_ The address of the AaveOracle contract.
  constructor(address oracle_) Spoke(oracle_) {}

  // ============ Liquidation Override ============
  // Liquidation still needs full override due to different library/struct

  /// @inheritdoc Spoke
  function liquidationCall(
    uint256 collateralReserveId,
    uint256 debtReserveId,
    address user,
    uint256 debtToCover,
    bool receiveShares
  ) external override nonReentrant {
    Reserve storage collateralReserve = _getReserve(collateralReserveId);
    Reserve storage debtReserve = _getReserve(debtReserveId);
    DynamicReserveConfig storage collateralDynConfig = _getSpokeStorage()._dynamicConfig[
      collateralReserveId
    ][_getSpokeStorage()._userPositions[user][collateralReserveId].dynamicConfigKey];
    UserAccountData memory userAccountData = _calculateUserAccountData(user);

    uint256 drawnIndex = debtReserve.hub.getAssetDrawnIndex(debtReserve.assetId);
    (uint256 drawnDebt, ) = _getUserDebt(
      _getSpokeStorage()._userPositions[user][debtReserveId],
      drawnIndex
    );

    RiskFreeLiquidationLogic.LiquidateUserParams memory params = RiskFreeLiquidationLogic.LiquidateUserParams({
      collateralReserveId: collateralReserveId,
      debtReserveId: debtReserveId,
      oracle: ORACLE,
      user: user,
      debtToCover: debtToCover,
      healthFactor: userAccountData.healthFactor,
      drawnDebt: drawnDebt,
      drawnIndex: drawnIndex,
      totalDebtValue: userAccountData.totalDebtValue,
      activeCollateralCount: userAccountData.activeCollateralCount,
      borrowedCount: userAccountData.borrowedCount,
      liquidator: msg.sender,
      receiveShares: receiveShares
    });

    bool isUserInDeficit = RiskFreeLiquidationLogic.liquidateUser(
      collateralReserve,
      debtReserve,
      _getSpokeStorage()._userPositions,
      _getSpokeStorage()._positionStatus,
      _getSpokeStorage()._liquidationConfig,
      collateralDynConfig,
      params
    );

    if (isUserInDeficit) {
      _reportDeficit(user);
    }
    // No _notifyRiskPremiumUpdate call - risk-free spoke has no premium
  }

  /// @inheritdoc Spoke
  function getLiquidationLogic() external pure override returns (address) {
    return address(RiskFreeLiquidationLogic);
  }

  // ============ Virtual Function Overrides ============
  // These override the debt calculation wrappers to remove premium handling

  /// @inheritdoc Spoke
  function _getUserDebt(
    UserPosition storage userPosition,
    uint256 drawnIndex
  ) internal view override returns (uint256 drawnDebt, uint256 premiumDebtRay) {
    return (uint256(userPosition.drawnShares).rayMulUp(drawnIndex), 0);
  }

  /// @inheritdoc Spoke
  function _getUserDebtFromHub(
    UserPosition storage userPosition,
    IHubBase hub,
    uint256 assetId
  ) internal view override returns (uint256 drawnDebt, uint256 premiumDebtRay) {
    uint256 drawnIndex = hub.getAssetDrawnIndex(assetId);
    return (uint256(userPosition.drawnShares).rayMulUp(drawnIndex), 0);
  }

  /// @inheritdoc Spoke
  function _calculateRestoreAmount(
    UserPosition storage userPosition,
    uint256 drawnIndex,
    uint256 amount
  ) internal view override returns (uint256 drawnDebtRestored, uint256 premiumDebtRayRestored) {
    uint256 drawnDebt = uint256(userPosition.drawnShares).rayMulUp(drawnIndex);
    return (amount.min(drawnDebt), 0);
  }

  /// @inheritdoc Spoke
  function _calculatePremiumDelta(
    UserPosition storage,
    uint256,
    uint256,
    uint256,
    uint256
  ) internal pure override returns (IHubBase.PremiumDelta memory) {
    // Return zero premium delta - risk-free spoke has no premium
    return IHubBase.PremiumDelta(0, 0, 0);
  }

  /// @inheritdoc Spoke
  function _applyPremiumDelta(
    UserPosition storage,
    IHubBase.PremiumDelta memory
  ) internal pure override {
    // No-op: RiskFreeSpoke has no premium tracking
  }

  /// @inheritdoc Spoke
  function _calculateUserRiskPremium(
    KeyValueList.List memory,
    uint256
  ) internal pure override returns (uint256) {
    return 0; // RiskFreeSpoke has no risk premium
  }

  /// @inheritdoc Spoke
  function _notifyRiskPremiumUpdate(address, uint256) internal override {
    // No-op: RiskFreeSpoke has no premium tracking
  }
}
