// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.10;

import {ILiquidityHub} from 'src/interfaces/ILiquidityHub.sol';

contract DataTypes2 {
  struct A {
    uint64 a;
  }

  struct B {
    uint64 a;
    A n;
  }

  B internal b;
  uint256 internal a;

  // Liquidity Hub types
  struct SpokeData {
    uint128 suppliedShares; // 128 bits (potentially 112 bits)
    uint128 baseDrawnShares; // 128 bits (potentially 112 bits)
    uint128 premiumDrawnShares; // 128 bits (potentially 112 bits)
    uint128 premiumOffset; // 128 bits (potentially 112 bits)
    uint128 realizedPremium; // 128 bits (potentially 112 bits)
    SpokeConfig config;
  }

  // 136 bits (potentially 129 bits)
  struct SpokeConfig {
    bool active; // 8 bits (potentially 1 bit)
    uint64 supplyCap; // 64 bits
    uint64 drawCap; // 64 bits
  }

  struct Asset {
    uint128 suppliedShares; // 128 bits (potentially 112 bits)
    uint128 availableLiquidity; // 128 bits (potentially 112 bits)
    uint128 baseDrawnShares; // 128 bits (potentially 112 bits)
    uint128 premiumDrawnShares; // 128 bits (potentially 112 bits)
    uint128 premiumOffset; // 128 bits (potentially 112 bits)
    uint128 realizedPremium; // 128 bits (potentially 112 bits)
    uint128 baseDebtIndex; // 128 bits
    uint128 baseBorrowRate; // 128 bits
    address underlying; // 160 bits
    uint8 decimals; // 8 bits
    uint40 lastUpdateTimestamp; // 40 bits
    AssetConfig config;
  }

  // 360 bits (potentially 333 bits)
  struct AssetConfig {
    bool active; // 8 bits (potentially 1 bit)
    bool paused; // 8 bits (potentially 1 bit)
    bool frozen; // 8 bits (potentially 1 bit)
    uint16 liquidityFee; // 16 bits (potentially 10 bits)
    address feeReceiver; // 160 bits
    address irStrategy; // 160 bits
  }

  // Spoke types
  struct Reserve {
    uint128 suppliedShares; // 128 bits (potentially 112 bits)
    uint128 baseDrawnShares; // 128 bits (potentially 112 bits)
    uint128 premiumDrawnShares; // 128 bits (potentially 112 bits)
    uint128 premiumOffset; // 128 bits (potentially 112 bits)
    uint128 realizedPremium; // 128 bits (potentially 112 bits)
    uint16 reserveId; // 16 bits
    uint16 assetId; // 16 bits
    uint16 dynamicConfigKey; // 16 bits (potentially 10 bits)
    uint8 decimals; // 8 bits
    address underlying; // 160 bits
    ILiquidityHub hub; // 160 bits
    ReserveConfig config;
  }

  // 72 bits (potentially 25 bits)
  struct ReserveConfig {
    bool active; // 8 bits
    bool frozen; // 8 bits
    bool paused; // 8 bits
    bool borrowable; // 8 bits
    bool collateral; // 8 bits
    uint16 liquidityPremium; // 16 bits (potentially 10 bits)
    uint16 liquidationFee; // 16 bits (potentially 10 bits) // to be moved
  }

  // 32 bits (potentially 20 bits)
  struct DynamicReserveConfig {
    uint16 collateralFactor; // 16 bits (potentially 10 bits)
    uint16 liquidationBonus; // 16 bits (potentially 10 bits) // BPS, 100_00 represent a 0% bonus
  }

  struct UserPosition {
    uint128 suppliedShares; // 128 bits (potentially 112 bits)
    uint128 baseDrawnShares; // 128 bits (potentially 112 bits)
    uint128 premiumDrawnShares; // 128 bits (potentially 112 bits)
    uint128 premiumOffset; // 128 bits (potentially 112 bits)
    uint128 realizedPremium; // 128 bits (potentially 112 bits)
    uint16 configKey; // 16 bits (potentially 10 bits)
  }

  struct PositionStatus {
    mapping(uint256 slot => uint256 status) map;
  }

  struct NotifyRiskPremiumUpdateVars {
    bool premiumIncrease;
    uint256 reserveCount;
    uint256 reserveId;
  }

  struct CalculateUserAccountDataVars {
    uint256 i;
    uint256 assetId;
    uint256 assetPrice;
    uint256 assetUnit;
    uint256 reserveId;
    uint256 reservePrice;
    uint256 liquidityPremium;
    uint256 userCollateralInBaseCurrency;
    uint256 totalCollateralInBaseCurrency;
    uint256 totalDebtInBaseCurrency;
    uint256 debtCounterInBaseCurrency;
    uint256 collateralCounterInBaseCurrency;
    uint256 avgCollateralFactor;
    uint256 userRiskPremium;
    uint256 healthFactor;
  }

  struct LiquidationConfig {
    uint256 closeFactor; // BPS, HF value to restore to during a liquidation, TODO: use smaller uint
    uint256 healthFactorForMaxBonus; // health factor under which liquidation bonus is max, TODO: use smaller uint
    uint256 liquidationBonusFactor; // BPS, as a percentage of effective lb, TODO: use smaller uint
  }

  struct LiquidationCallLocalVars {
    uint256 collateralReserveId;
    uint256 debtReserveId;
    uint256 actualCollateralToLiquidate;
    uint256 actualDebtToLiquidate;
    uint256 liquidationFeeAmount;
    uint256 userCollateralBalance;
    uint256 totalCollateralInBaseCurrency;
    uint256 totalDebtInBaseCurrency;
    uint256 debtAssetPrice;
    uint256 debtAssetUnit;
    uint256 totalDebt;
    uint256 healthFactor;
    uint256 liquidationBonus;
    uint256 baseDebtToLiquidate;
    uint256 premiumDebtToLiquidate;
    uint256 closeFactor;
    uint256 collateralFactor;
    uint256 collateralAssetPrice;
    uint256 collateralAssetUnit;
    uint256 liquidationFee;
  }

  struct ExecuteLiquidationLocalVars {
    uint256 i;
    address user;
    uint256 debtAssetId;
    uint256 collateralAssetId;
    uint256 debtReserveId;
    uint256 collateralReserveId;
    uint256 baseDebt;
    uint256 premiumDebt;
    uint256 collateralToLiquidate;
    uint256 liquidationFeeAmount;
    uint256 liquidationFeeShares;
    uint256 baseDebtToLiquidate;
    uint256 premiumDebtToLiquidate;
    uint256 restoredShares;
    uint256 withdrawnShares;
    uint256 newUserRiskPremium;
    uint256 userPremiumDrawnShares;
    uint256 userPremiumOffset;
    uint256 userRealizedPremium;
    uint256 totalRestoredShares;
    uint256 totalWithdrawnShares;
    uint256 totalCollateralToLiquidate;
    uint256 totalLiquidationFeeShares;
    int256 totalUserDebtPremiumDrawnSharesDelta;
    int256 totalUserDebtPremiumOffsetDelta;
    int256 totalUserCollateralPremiumDrawnSharesDelta;
    int256 totalUserCollateralPremiumOffsetDelta;
    uint256 totalDebtToLiquidate;
    uint256 usersLength;
    uint256 liquidatedSuppliedShares;
  }
}
