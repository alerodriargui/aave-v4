// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/Hub/HubBase.t.sol';

contract HubHorizonTest is HubBase {
  using SharesMath for uint256;
  using SafeCast for uint256;

  uint256 internal assetId;
  IERC20 internal underlying;

  function setUp() public override {
    super.setUp();

    assetId = daiAssetId; // assume dai is RWA and borrowable
    underlying = IERC20(hub1.getAsset(assetId).underlying);

    deal(address(underlying), address(spoke1), MAX_SUPPLY_AMOUNT);
    deal(address(underlying), address(spoke2), MAX_SUPPLY_AMOUNT);
  }

  /// assume that asset is an RWA, and is borrowable
  function test_RWA_virtual_remaining_borrowable() public {
    Utils.add(hub1, assetId, address(spoke1), 100e18, address(spoke1));

    Utils.draw(hub1, assetId, address(spoke2), address(spoke2), 1e18);

    Utils.add(hub1, assetId, address(spoke2), 200e18, address(spoke2));

    // skip time to accrue interest
    skip(365 days);

    Utils.remove(
      hub1,
      assetId,
      address(spoke1),
      hub1.getSpokeAddedAssets(assetId, address(spoke1)),
      address(spoke1)
    );

    Utils.restoreDrawn(
      hub1,
      assetId,
      address(spoke2),
      hub1.getSpokeTotalOwed(assetId, address(spoke2)),
      address(spoke2)
    );

    assertEq(
      hub1.getSpokeTotalOwed(assetId, address(spoke2)),
      0,
      'spoke2 total owed after restore'
    );

    Utils.remove(
      hub1,
      assetId,
      address(spoke2),
      hub1.getSpokeAddedAssets(assetId, address(spoke2)),
      address(spoke2)
    );

    address feeReceiver = _getFeeReceiver(hub1, assetId);

    Utils.remove(
      hub1,
      assetId,
      feeReceiver,
      hub1.getSpokeAddedAssets(assetId, feeReceiver),
      feeReceiver
    );

    assertEq(hub1.getSpokeTotalOwed(assetId, address(spoke1)), 0);
    assertEq(hub1.getAssetTotalOwed(assetId), 0, 'total debt');
    assertEq(hub1.getSpokeAddedAssets(assetId, address(spoke1)), 0, 'spoke1 added assets after');
    assertEq(hub1.getSpokeAddedAssets(assetId, address(spoke2)), 0, 'spoke2 added assets after');
    assertEq(hub1.getSpokeAddedAssets(assetId, feeReceiver), 0, 'fee receiver added assets after');

    // THESE ARE PROBLEMS FOR RWA TOKENS - hub shouldnt have remaining RWA tokens remaining
    assertEq(
      _calculateBurntInterest(hub1, assetId),
      hub1.getAddedAssets(assetId),
      'burnt interest'
    );
    assertEq(hub1.getAddedAssets(assetId), 0, 'hub remaining added assets');
    assertEq(underlying.balanceOf(address(hub1)), 0, 'hub remaining underlying');
  }

  function test_RWA_virtual_remaining() public {
    Utils.add(hub1, assetId, address(spoke1), 200e18, address(spoke1));

    Utils.add(hub1, assetId, address(spoke2), 100e18, address(spoke2));

    skip(365 days);

    Utils.remove(
      hub1,
      assetId,
      address(spoke1),
      hub1.getSpokeAddedAssets(assetId, address(spoke1)),
      address(spoke1)
    );

    Utils.remove(
      hub1,
      assetId,
      address(spoke2),
      hub1.getSpokeAddedAssets(assetId, address(spoke2)),
      address(spoke2)
    );

    address feeReceiver = _getFeeReceiver(hub1, assetId);
    assertEq(hub1.getSpokeAddedAssets(assetId, feeReceiver), 0, 'fee receiver has no fees accrued');
    assertEq(hub1.getSpokeAddedAssets(assetId, address(spoke1)), 0, 'spoke1 added assets after');
    assertEq(hub1.getSpokeAddedAssets(assetId, address(spoke2)), 0, 'spoke2 added assets after');

    assertEq(hub1.getAddedAssets(assetId), 0, 'hub added assets');
    assertEq(underlying.balanceOf(address(hub1)), 0, 'hub remaining underlying');
  }
}
