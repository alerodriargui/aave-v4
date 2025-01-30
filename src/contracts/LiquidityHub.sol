// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {SafeERC20} from 'src/dependencies/openzeppelin/SafeERC20.sol';
import {IERC20} from 'src/dependencies/openzeppelin/IERC20.sol';
import {ILiquidityHub} from 'src/interfaces/ILiquidityHub.sol';
import {DataTypes} from 'src/libraries/types/DataTypes.sol';
import {AssetLogic} from 'src/contracts/AssetLogic.sol';
import {SpokeDataLogic} from 'src/contracts/SpokeDataLogic.sol';
import {WadRayMath} from 'src/contracts/WadRayMath.sol';
import {SharesMath} from 'src/contracts/SharesMath.sol';
import {MathUtils} from 'src/contracts/MathUtils.sol';
import {PercentageMath} from 'src/contracts/PercentageMath.sol';

// todo move to DataTypes
struct SpokeData {
  uint256 suppliedShares; // share
  uint256 baseDebt; // asset
  uint256 outstandingPremium; // asset
  uint256 baseBorrowIndex; // in ray
  uint256 riskPremiumWeightedSum; // weighted averaged sum risk premium in rad (bps value with extra `rad` precision)
  uint256 lastUpdateTimestamp;
  DataTypes.SpokeConfig config;
}

struct Asset {
  uint256 id;
  uint256 suppliedShares; // share
  uint256 availableLiquidity; // asset
  uint256 baseDebt; // asset
  uint256 outstandingPremium; // asset
  uint256 baseBorrowIndex; // in ray
  uint256 baseBorrowRate; // in ray
  uint256 riskPremiumWeightedSum;
  uint256 lastUpdateTimestamp;
  DataTypes.AssetConfig config;
}

struct AssetCache {
  uint256 existingBaseDebt;
  uint256 cumulatedBaseDebt;
  uint256 cumulatedRiskPremiumWeightedSum;
  uint256 existingRiskPremiumWeightedSum;
}

struct SpokeDataCache {
  uint256 existingBaseDebt;
  uint256 cumulatedBaseDebt;
  uint256 existingRiskPremiumWeightedSum;
  uint256 cumulatedRiskPremiumWeightedSum;
}

// @dev Amounts are `asset` denominated by default unless specified otherwise with `share` suffix
contract LiquidityHub is ILiquidityHub {
  using SafeERC20 for IERC20;
  using WadRayMath for uint256;
  using SharesMath for uint256;
  using PercentageMath for uint256;
  using AssetLogic for Asset;
  using SpokeDataLogic for SpokeData;
  using SpokeDataLogic for SpokeDataCache;

  mapping(uint256 assetId => Asset assetData) internal _assets;
  mapping(uint256 assetId => mapping(address spokeAddress => SpokeData spokeData)) internal _spokes;

  IERC20[] public assetsList; // TODO: Check if Enumerable or Set makes more sense
  uint256 public assetCount;

  //
  // External
  //

  function getAsset(uint256 assetId) external view returns (Asset memory) {
    return _assets[assetId];
  }

  function getSpoke(uint256 assetId, address spoke) external view returns (SpokeData memory) {
    return _spokes[assetId][spoke];
  }

  function getSpokeConfig(
    uint256 assetId,
    address spoke
  ) external view returns (DataTypes.SpokeConfig memory) {
    return _spokes[assetId][spoke].config;
  }

  function getTotalAssets(uint256 assetId) external view returns (uint256) {
    Asset storage asset = _assets[assetId];
    return asset.getTotalAssets();
  }

  // /////
  // Governance
  // /////

  function addAsset(DataTypes.AssetConfig memory config, address asset) external {
    // TODO: AccessControl
    assetsList.push(IERC20(asset));
    _assets[assetCount] = Asset({
      id: assetCount,
      suppliedShares: 0,
      availableLiquidity: 0,
      baseDebt: 0,
      outstandingPremium: 0,
      baseBorrowIndex: WadRayMath.RAY,
      baseBorrowRate: 0,
      lastUpdateTimestamp: block.timestamp,
      riskPremiumWeightedSum: 0,
      config: DataTypes.AssetConfig({
        decimals: config.decimals,
        active: config.active,
        irStrategy: config.irStrategy
      })
    });
    assetCount++;

    // TODO: emit event
  }

  function updateAssetConfig(uint256 assetId, DataTypes.AssetConfig memory config) external {
    // TODO: AccessControl
    _assets[assetId].config = DataTypes.AssetConfig({
      decimals: config.decimals,
      active: config.active,
      irStrategy: config.irStrategy
    });

    // TODO: emit event
  }

  function addSpoke(uint256 assetId, DataTypes.SpokeConfig memory config, address spoke) external {
    // TODO: AccessControl
    _addSpoke(assetId, config, spoke);
  }

  function addSpokes(
    uint256[] calldata assetIds,
    DataTypes.SpokeConfig[] memory configs,
    address spoke
  ) external {
    // TODO: AccessControl

    require(assetIds.length == configs.length, 'MISMATCHED_CONFIGS');
    for (uint256 i; i < assetIds.length; i++) {
      _addSpoke(assetIds[i], configs[i], spoke);
    }
  }

  function updateSpokeConfig(
    uint256 assetId,
    address spoke,
    DataTypes.SpokeConfig memory config
  ) external {
    // TODO: AccessControl
    _spokes[assetId][spoke].config = DataTypes.SpokeConfig({
      drawCap: config.drawCap,
      supplyCap: config.supplyCap
    });

    // TODO: emit event
  }

  // /////
  // Users
  // /////

  /// @dev risk premium is calculated on the spoke and passed upon every action
  function supply(
    uint256 assetId,
    uint256 amount,
    uint256 riskPremiumWeightedSum,
    address supplier
  ) external returns (uint256, uint256) {
    // TODO: authorization - only spokes

    Asset storage asset = _assets[assetId];
    AssetCache memory assetCache = asset.cache();
    SpokeData storage spoke = _spokes[assetId][msg.sender];
    SpokeDataCache memory spokeCache = spoke.cache();

    _accrueInterest(asset, spoke, assetCache, spokeCache); // uint256 nextBaseBorrowIndex = _accrueInterest(asset, spoke);
    _validateSupply(asset, spoke, amount);

    asset.updateBorrowRate({liquidityAdded: amount, liquidityTaken: 0});
    _updateRiskPremiumAndBaseDebt({
      asset: asset,
      spoke: spoke,
      assetCache: assetCache,
      spokeCache: spokeCache,
      newSpokeRiskPremiumWeightedSum: riskPremiumWeightedSum,
      debtAdded: 0,
      debtTaken: 0
    });

    // todo: Mitigate inflation attack (burn some amount if first supply)
    uint256 sharesAmount = asset.convertToSharesDown(amount);
    require(sharesAmount > 0, 'INVALID_SHARES_AMOUNT');

    asset.availableLiquidity += amount;
    asset.suppliedShares += sharesAmount;
    spoke.suppliedShares += sharesAmount; // todo: mint 4626 shares to abstract this accounting

    // TODO: fee-on-transfer
    assetsList[assetId].safeTransferFrom(supplier, address(this), amount);

    emit Supply(assetId, msg.sender, amount);

    return (uint(0), sharesAmount);
  }

  // TODO: Be able to pass max(uint) as amount to withdraw all or accept number of shares
  function withdraw(
    uint256 assetId,
    address to,
    uint256 amount,
    uint256 riskPremiumWeightedSum
  ) external returns (uint256) {
    // TODO: authorization - only spokes

    Asset storage asset = _assets[assetId];
    SpokeData storage spoke = _spokes[assetId][msg.sender];

    // _accrueInterest(asset, spoke); // accrue interest before validating action
    // _validateWithdraw(asset, spoke, amount);

    // asset.updateBorrowRate({liquidityAdded: 0, liquidityTaken: amount});
    // _updateRiskPremiumAndBaseDebt(asset, spoke, riskPremiumWeightedSum, 0); // no base debt change

    uint256 sharesAmount = asset.convertToSharesDown(amount);
    asset.suppliedShares -= sharesAmount;
    asset.availableLiquidity -= amount;

    assetsList[assetId].safeTransfer(to, amount);

    emit Withdraw(assetId, msg.sender, to, amount);

    return sharesAmount;
  }

  function draw(
    uint256 assetId,
    address to,
    uint256 amount,
    uint256 riskPremiumWeightedSum
  ) external returns (uint256) {
    // TODO: authorization - only spokes

    Asset storage asset = _assets[assetId];
    AssetCache memory assetCache = asset.cache();
    SpokeData storage spoke = _spokes[assetId][msg.sender];
    SpokeDataCache memory spokeCache = spoke.cache();

    _accrueInterest(asset, spoke, assetCache, spokeCache); // accrue interest before validating action
    _validateDraw(asset, amount, spoke.config.drawCap);

    asset.updateBorrowRate({liquidityAdded: 0, liquidityTaken: amount});
    _updateRiskPremiumAndBaseDebt({
      asset: asset,
      spoke: spoke,
      assetCache: assetCache,
      spokeCache: spokeCache,
      newSpokeRiskPremiumWeightedSum: riskPremiumWeightedSum,
      debtAdded: amount,
      debtTaken: 0
    }); // base debt added

    asset.availableLiquidity -= amount;

    assetsList[assetId].safeTransfer(to, amount);

    emit Draw(assetId, msg.sender, to, amount);

    return amount;
  }

  /**
   * @notice Repays debt on behalf of user
   * @dev Only callable by spokes
   * @dev Interest is always paid off first from premium, then from base
   * @param assetId The asset id
   * @param amount The amount to repay
   * @param riskPremiumWeightedSum The aggregated risk premium of the calling spoke
   * @param repayer The address who is trying to settle the credit line
   * @return The amount of shares restored
   */
  function restore(
    uint256 assetId,
    uint256 amount,
    uint256 riskPremiumWeightedSum,
    address repayer
  ) external returns (uint256) {
    // TODO: authorization - only spokes

    Asset storage asset = _assets[assetId];
    SpokeData storage spoke = _spokes[assetId][msg.sender];

    // _accrueInterest(asset, spoke); // accrue interest before validating action
    // _validateRestore(asset, amount, spoke.baseDebt);
    // asset.updateBorrowRate({liquidityAdded: amount, liquidityTaken: 0});

    uint256 baseDebtRestored = _deductFromOutstandingPremium(asset, spoke, amount);
    // _updateRiskPremiumAndBaseDebt(asset, spoke, riskPremiumWeightedSum, -int256(baseDebtRestored));

    asset.availableLiquidity += amount;

    assetsList[assetId].safeTransferFrom(repayer, address(this), amount);

    emit Restore(assetId, msg.sender, amount);

    return amount;
  }

  //
  // public
  //

  function getAssetRiskPremium(uint256 assetId) public view returns (uint256) {
    return _assets[assetId].riskPremiumRay();
  }

  function getSpokeRiskPremium(uint256 assetId, address spoke) public view returns (uint256) {
    return _spokes[assetId][spoke].riskPremiumRay();
  }

  function previewNextBorrowIndex(uint256 assetId) public view returns (uint256) {
    (, uint256 nextBaseBorrowIndex) = _assets[assetId].previewNextBorrowIndex();
    return nextBaseBorrowIndex;
  }

  function convertToSharesUp(uint256 assetId, uint256 assets) external view returns (uint256) {
    return _assets[assetId].convertToSharesUp(assets);
  }

  function convertToSharesDown(uint256 assetId, uint256 assets) external view returns (uint256) {
    return _assets[assetId].convertToSharesDown(assets);
  }

  function convertToAssetsUp(uint256 assetId, uint256 shares) external view returns (uint256) {
    return _assets[assetId].convertToAssetsUp(shares);
  }

  function convertToAssetsDown(uint256 assetId, uint256 shares) external view returns (uint256) {
    return _assets[assetId].convertToAssetsDown(shares);
  }

  function getBaseInterestRate(uint256 assetId) public view returns (uint256) {
    return _assets[assetId].baseBorrowRate;
  }

  function getInterestRate(uint256 assetId) public view returns (uint256) {
    return _assets[assetId].getInterestRate();
  }

  function getSpokeDrawnLiquidity(uint256 assetId, address spoke) public view returns (uint256) {
    return _spokes[assetId][spoke].baseDebt;
  }

  function getTotalDrawnLiquidity(uint256 assetId) public view returns (uint256) {
    return _assets[assetId].baseDebt;
  }

  //
  // Internal
  //

  function _validateSupply(
    Asset storage asset,
    SpokeData storage spoke,
    uint256 amount
  ) internal view {
    require(amount > 0, 'INVALID_AMOUNT');
    require(assetsList[asset.id] != IERC20(address(0)), 'ASSET_NOT_LISTED');
    // TODO: Different states e.g. frozen, paused
    require(asset.config.active, 'ASSET_NOT_ACTIVE');
    require(
      spoke.config.supplyCap == type(uint256).max ||
        asset.convertToAssetsDown(spoke.suppliedShares) + amount <= spoke.config.supplyCap,
      'SUPPLY_CAP_EXCEEDED'
    );
  }

  function _validateWithdraw(
    Asset storage asset,
    SpokeData storage spoke,
    uint256 amount
  ) internal view {
    // TODO: Other cases of status (frozen, paused)
    // TODO: still allow withdrawal even if asset is not active, only prevent for frozen/paused?
    require(asset.config.active, 'ASSET_NOT_ACTIVE');
    require(
      amount <= asset.convertToAssetsDown(spoke.suppliedShares) - spoke.baseDebt,
      'SUPPLIED_AMOUNT_EXCEEDED'
    );
    require(amount <= asset.availableLiquidity, 'NOT_AVAILABLE_LIQUIDITY');
  }

  function _validateDraw(Asset storage asset, uint256 amount, uint256 drawCap) internal view {
    // TODO: Other cases of status (frozen, paused)
    require(asset.config.active, 'ASSET_NOT_ACTIVE');
    require(
      drawCap == type(uint256).max || amount + asset.baseDebt <= drawCap,
      'DRAW_CAP_EXCEEDED'
    );
    require(amount <= asset.availableLiquidity, 'NOT_AVAILABLE_LIQUIDITY');
  }

  function _validateRestore(
    Asset storage asset,
    uint256 amountRestored,
    uint256 amountDrawn
  ) internal view {
    // TODO: Other cases of status (frozen, paused)
    require(asset.config.active, 'ASSET_NOT_ACTIVE');

    // Ensure spoke is not restoring more than supplied
    require(amountRestored <= amountDrawn, 'INVALID_RESTORE_AMOUNT');
  }

  // todo rm, temp
  function _accrueInterestAndUpdateRiskPremium(
    Asset storage asset,
    SpokeData storage spoke,
    uint256 newSpokeRiskPremiumWeightedSum,
    uint256 debtAdded,
    uint256 debtTaken
  ) internal {
    (uint256 cumulatedBaseInterest, uint256 nextBaseBorrowIndex) = asset.previewNextBorrowIndex();
    uint256 existingAssetDebt = asset.baseDebt;

    uint256 cumulatedAssetDebt = existingAssetDebt.rayMul(cumulatedBaseInterest);
    asset.outstandingPremium += (cumulatedAssetDebt - existingAssetDebt).rayMul(
      asset.riskPremiumRay()
    );

    uint256 existingSpokeDebt = spoke.baseDebt;

    uint256 cumulatedSpokeBaseDebt = existingSpokeDebt.rayMul(nextBaseBorrowIndex).rayDiv(
      spoke.baseBorrowIndex
    );

    uint256 existingSpokeRiskPremium = spoke.riskPremiumRay();
    spoke.outstandingPremium += existingSpokeRiskPremium.rayMul(
      cumulatedAssetDebt - existingAssetDebt
    );

    (uint256 assetRiskPremiumWithoutCurrent, ) = MathUtils.subtractFromWeightedAverage(
      asset.riskPremiumWeightedSum,
      existingAssetDebt,
      existingSpokeRiskPremium, // use current spoke risk premium
      existingSpokeDebt
    );

    uint256 newSpokeDebt = cumulatedSpokeBaseDebt + debtAdded - debtTaken;
    uint256 newSpokeRiskPremium = newSpokeDebt == 0
      ? 0
      : newSpokeRiskPremiumWeightedSum.toRay() / newSpokeDebt;

    (uint256 newAssetRiskPremiumWeightedSum, uint256 newAssetDebt) = MathUtils.addToWeightedAverage(
      assetRiskPremiumWithoutCurrent,
      cumulatedAssetDebt - cumulatedSpokeBaseDebt,
      newSpokeRiskPremium, // use new spoke risk premium
      newSpokeDebt
    );

    asset.riskPremiumWeightedSum = newAssetRiskPremiumWeightedSum;
    asset.baseDebt = newAssetDebt;
    asset.baseBorrowIndex = nextBaseBorrowIndex;
    asset.lastUpdateTimestamp = block.timestamp;

    spoke.riskPremiumWeightedSum = newSpokeRiskPremiumWeightedSum;
    spoke.baseDebt = cumulatedSpokeBaseDebt;
    spoke.baseBorrowIndex = nextBaseBorrowIndex;
    spoke.lastUpdateTimestamp = block.timestamp;
  }

  // @dev Utilizes existing asset & spoke: `baseBorrowIndex`, `riskPremiumWeightedSum`
  function _accrueInterest(
    Asset storage asset,
    SpokeData storage spoke,
    AssetCache memory assetCache,
    SpokeDataCache memory spokeCache
  ) internal returns (uint256) {
    (uint256 cumulatedBaseInterest, uint256 nextBaseBorrowIndex) = asset.previewNextBorrowIndex();
    asset.accrueInterest(assetCache, cumulatedBaseInterest, nextBaseBorrowIndex);
    spoke.accrueInterest(spokeCache, nextBaseBorrowIndex);
    return nextBaseBorrowIndex;
  }

  // @dev Does not update `outstandingPremium`
  function _updateRiskPremiumAndBaseDebt(
    Asset storage asset,
    SpokeData storage spoke,
    AssetCache memory assetCache,
    SpokeDataCache memory spokeCache,
    uint256 newSpokeRiskPremiumWeightedSum,
    uint256 debtAdded,
    uint256 debtTaken
  ) internal {
    // weighted average risk premium of all spokes without current `spoke`
    (uint256 assetRiskPremiumWeightedSumWithoutCurrent, uint256 assetDebtWithoutCurrent) = MathUtils
      .subtractFromWeightedAverage(
        assetCache.cumulatedRiskPremiumWeightedSum,
        assetCache.cumulatedBaseDebt,
        spokeCache.existingRiskPremiumRay(), // use current spoke risk premium
        spokeCache.cumulatedBaseDebt
      );

    // use accrued base debt
    uint256 newSpokeDebt = spokeCache.cumulatedBaseDebt + debtAdded - debtTaken;
    uint256 newSpokeRiskPremiumRay = newSpokeDebt == 0
      ? 0
      : newSpokeRiskPremiumWeightedSum.toRay() / newSpokeDebt;

    (uint256 newAssetRiskPremiumWeightedSum, uint256 newAssetDebt) = MathUtils.addToWeightedAverage(
      assetRiskPremiumWeightedSumWithoutCurrent,
      assetDebtWithoutCurrent,
      newSpokeRiskPremiumRay, // use new spoke risk premium
      newSpokeDebt
    );

    asset.baseDebt = newAssetDebt;
    spoke.baseDebt = newSpokeDebt;

    asset.riskPremiumWeightedSum = newAssetRiskPremiumWeightedSum.fromRay();
    spoke.riskPremiumWeightedSum = newSpokeRiskPremiumWeightedSum.fromRay();
  }

  function _addSpoke(uint256 assetId, DataTypes.SpokeConfig memory config, address spoke) internal {
    require(spoke != address(0), 'INVALID_SPOKE');
    _spokes[assetId][spoke] = SpokeData({
      suppliedShares: 0,
      baseDebt: 0,
      outstandingPremium: 0,
      baseBorrowIndex: WadRayMath.RAY,
      riskPremiumWeightedSum: 0,
      lastUpdateTimestamp: block.timestamp,
      config: DataTypes.SpokeConfig({drawCap: config.drawCap, supplyCap: config.supplyCap})
    });
    emit SpokeAdded(assetId, spoke);
  }

  // @dev `amount` can cover at most spoke's outstanding premium
  function _deductFromOutstandingPremium(
    Asset storage asset,
    SpokeData storage spoke,
    uint256 amount
  ) internal returns (uint256) {
    uint256 spokeOutstandingPremium = spoke.outstandingPremium;

    uint256 baseDebtRestored;

    if (amount > spokeOutstandingPremium) {
      baseDebtRestored = amount - spokeOutstandingPremium;
      spoke.outstandingPremium = 0;
      // underflow not possible bc of invariant: asset.outstandingPremium >= spoke.outstandingPremium
      asset.outstandingPremium -= spokeOutstandingPremium;
    } else {
      // no base debt is restored, only outstanding premium
      spoke.outstandingPremium -= amount;
      asset.outstandingPremium -= amount;
    }

    return baseDebtRestored;
  }
}
