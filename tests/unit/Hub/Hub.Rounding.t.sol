// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/Hub/HubBase.t.sol';

/// forge-config: default.disable_block_gas_limit = true
contract HubRoundingTest is HubBase {
  using Math for uint256;

  /// @dev Added share price is not significantly affected by multiple donations
  function test_sharePriceWithMultipleDonations() public {
    // add and draw 1 dai and wait 12 seconds to start accruing interest
    _addAndDrawLiquidity({
      hub: hub1,
      assetId: daiAssetId,
      addUser: bob,
      addSpoke: address(spoke1),
      addAmount: 1,
      drawUser: bob,
      drawSpoke: address(spoke1),
      drawAmount: 1,
      skipTime: 12
    });

    uint256 initialSharePrice = getAddExRate(daiAssetId);
    assertGt(initialSharePrice, 1e30);
    assertLt(initialSharePrice, 1.000001e30);

    for (uint256 i = 0; i < 1e4; ++i) {
      Utils.supply({
        spoke: spoke1,
        reserveId: _daiReserveId(spoke1),
        caller: alice,
        amount: hub1.previewAddByShares(daiAssetId, 1),
        onBehalfOf: alice
      });

      Utils.withdraw({
        spoke: spoke1,
        reserveId: _daiReserveId(spoke1),
        caller: alice,
        amount: 1,
        onBehalfOf: alice
      });

      assertLt(
        getAddExRate(daiAssetId),
        initialSharePrice +
          initialSharePrice.mulDiv(i + 1, SharesMath.VIRTUAL_ASSETS, Math.Rounding.Ceil)
      );
    }
  }
}

contract HubRoundingPrecisionSymTest is Test {
  using WadRayMath for *;
  using MathUtils for *;

  IHub public hub;

  function setUp() public {
    hub = new Hub(makeAddr('authority'));
  }

  function test_previewRemoveByShares(bytes32) public {
    vm.setArbitraryStorage(address(hub));
    uint256 assetId = vm.randomUint();

    // uint256 blockTimestamp = vm.randomUint(32);
    // vm.warp(blockTimestamp);
    // vm.assume(hub.getAsset(assetId).lastUpdateTimestamp <= blockTimestamp);
    IHub.Asset memory asset = hub.getAsset(assetId);
    vm.warp(asset.lastUpdateTimestamp);
    vm.assume(asset.liquidity <= type(uint96).max);
    vm.assume(asset.swept <= type(uint96).max);
    vm.assume(asset.deficit <= type(uint96).max);
    vm.assume(asset.premiumShares <= type(uint96).max);
    vm.assume(asset.premiumShares.rayMulUp(asset.drawnIndex) >= asset.premiumOffset);
    vm.assume(hub.getAddedAssets(assetId) >= hub.getAddedShares(assetId));

    uint256 shares = vm.randomUint(128);
    vm.assume(shares > 0);

    assertNotEq(hub.previewRemoveByShares(assetId, shares), 0);
  }

  function test_previewRemoveByShares2(bytes32) public view {
    uint256 totalAssets = vm.randomUint(128);
    uint256 totalShares = vm.randomUint(128);

    vm.assume(totalAssets >= totalShares);

    uint256 shares = vm.randomUint(128);
    vm.assume(shares > 0);

    uint256 assets = shares.mulDivDown(totalAssets + 1e6, totalShares + 1e6);
    assertNotEq(assets, 0);
  }
}
