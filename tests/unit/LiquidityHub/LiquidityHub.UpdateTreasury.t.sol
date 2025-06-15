// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/unit/LiquidityHub/LiquidityHubBase.t.sol';

contract LiquidityHubUpdateTreasuryTest is LiquidityHubBase {
  using SharesMath for uint256;
  using WadRayMath for uint256;

  /// Treasury update triggers an accrual, with previously accrued fees not transferred to the new spoke.
  function test_updateTreasury() public {
    uint256 assetId = daiAssetId;

    uint256 amount = 1000e18;
    _addLiquidity(assetId, amount);
    _drawLiquidity(assetId, amount, true);

    address currentTreasury = hub.getTreasurySpoke(assetId);
    address newTreasury = makeAddr('newTreasury');

    uint256 treasuryFees = hub.getSpokeSuppliedShares(assetId, currentTreasury);
    assertTrue(treasuryFees > 0, 'no fees');

    vm.expectEmit(address(hub));
    emit ILiquidityHub.DrawnIndexUpdate(assetId, hub.previewDrawnIndex(assetId), block.timestamp);

    vm.expectEmit(address(hub));
    emit ILiquidityHub.SpokeConfigUpdated(assetId, currentTreasury, 0, 0);

    vm.expectEmit(address(hub));
    emit ILiquidityHub.SpokeAdded(assetId, newTreasury);

    vm.expectEmit(address(hub));
    emit ILiquidityHub.TreasuryUpdated(assetId, currentTreasury, newTreasury);
    hub.updateTreasury(assetId, newTreasury);

    assertEq(hub.getSpokeSuppliedShares(assetId, currentTreasury), treasuryFees);
    assertEq(hub.getSpokeSuppliedShares(assetId, newTreasury), 0);
    assertEq(hub.getTreasurySpoke(assetId), newTreasury);
  }

  /// Updates treasury with a previously used spoke, reusing it, with no impact
  function test_updateTreasury_reuse() public {
    uint256 assetId = daiAssetId;

    uint256 amount = 1000e18;
    _addLiquidity(assetId, amount);
    _drawLiquidity(assetId, amount, true);

    address currentTreasury = hub.getTreasurySpoke(assetId);
    address newTreasury = makeAddr('newTreasury');

    uint256 currentFees = hub.getSpokeSuppliedShares(assetId, currentTreasury);
    assertTrue(currentFees > 0);

    vm.expectEmit(address(hub));
    emit ILiquidityHub.SpokeConfigUpdated(assetId, currentTreasury, 0, 0);

    vm.expectEmit(address(hub));
    emit ILiquidityHub.SpokeAdded(assetId, newTreasury);

    hub.updateTreasury(assetId, newTreasury);

    assertEq(hub.getSpokeSuppliedShares(assetId, currentTreasury), currentFees);
    assertEq(hub.getSpokeSuppliedShares(assetId, newTreasury), 0);
    assertEq(hub.getTreasurySpoke(assetId), newTreasury);

    skip(365 days);

    uint256 newFees = hub.getSpokeSuppliedShares(assetId, newTreasury);
    assertTrue(newFees > 0);

    // treasury is set back to original spoke
    vm.expectEmit(address(hub));
    emit ILiquidityHub.SpokeConfigUpdated(assetId, newTreasury, 0, 0);

    vm.expectEmit(address(hub));
    emit ILiquidityHub.SpokeConfigUpdated(
      assetId,
      currentTreasury,
      type(uint256).max,
      type(uint256).max
    );

    hub.updateTreasury(assetId, currentTreasury);

    assertEq(hub.getSpokeSuppliedShares(assetId, currentTreasury), currentFees);
    assertEq(hub.getSpokeSuppliedShares(assetId, newTreasury), newFees);
    assertEq(hub.getTreasurySpoke(assetId), currentTreasury);
  }

  function test_updateTreasury_from_zero() public {
    uint256 assetId = daiAssetId;

    updateReserveFactor(hub, assetId, 0);
    hub.updateTreasury(assetId, address(0));

    uint256 amount = 1000e18;
    _addLiquidity(assetId, amount);
    _drawLiquidity(assetId, amount, true);

    address newTreasury = makeAddr('newTreasury');

    vm.expectEmit(address(hub));
    emit ILiquidityHub.SpokeAdded(assetId, newTreasury);

    vm.expectEmit(address(hub));
    emit ILiquidityHub.TreasuryUpdated(assetId, address(0), newTreasury);
    hub.updateTreasury(assetId, newTreasury);

    assertEq(hub.getSpokeSuppliedShares(assetId, newTreasury), 0);
    assertEq(hub.getTreasurySpoke(assetId), newTreasury);
  }

  function test_updateTreasury_revertsWith_InvalidTreasurySpoke() public {
    uint256 assetId = daiAssetId;

    // reserve factor is non-zero so it reverts
    assertNotEq(_getReserveFactor(assetId), 0);

    vm.expectRevert(ILiquidityHub.InvalidTreasurySpoke.selector);
    hub.updateTreasury(assetId, address(0));
  }

  // todo: updateReserveFactor within bounds (<100.00%)
  // todo: updateReserveFactor accrues before new value
}
