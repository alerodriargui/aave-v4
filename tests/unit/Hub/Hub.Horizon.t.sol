// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/Hub/HubBase.t.sol';

contract HubHorizonTest is HubBase {
  using SharesMath for uint256;
  using SafeCast for uint256;

  uint256 zeroDecimalAssetId;

  function setUp() public override {
    super.setUp();

    /// @dev add a zero decimal asset to test add cap rounding
    IHub.SpokeConfig memory spokeConfig = IHub.SpokeConfig({
      active: true,
      addCap: Constants.MAX_ALLOWED_SPOKE_CAP,
      drawCap: Constants.MAX_ALLOWED_SPOKE_CAP
    });
    bytes memory encodedIrData = abi.encode(
      IAssetInterestRateStrategy.InterestRateData({
        optimalUsageRatio: 90_00, // 90.00%
        baseVariableBorrowRate: 5_00, // 5.00%
        variableRateSlope1: 5_00, // 5.00%
        variableRateSlope2: 5_00 // 5.00%
      })
    );
    vm.startPrank(ADMIN);
    zeroDecimalAssetId = hub1.addAsset(
      address(tokenList.dai),
      0,
      address(treasurySpoke),
      address(irStrategy),
      encodedIrData
    );
    hub1.updateAssetConfig(
      zeroDecimalAssetId,
      IHub.AssetConfig({
        liquidityFee: 5_00,
        feeReceiver: address(treasurySpoke),
        irStrategy: address(irStrategy),
        reinvestmentController: address(0)
      }),
      new bytes(0)
    );
    hub1.addSpoke(zeroDecimalAssetId, address(spoke1), spokeConfig);
    vm.stopPrank();
  }

  /// assume that asset is an RWA, and is borrowable
  function test_RWA_virtual_remaining() public {
    uint256 assetId = daiAssetId;
    address user = alice;
    uint256 amount = 100e18;

    _assumeValidSupplier(user);

    IERC20 underlying = IERC20(hub1.getAsset(assetId).underlying);

    deal(address(underlying), address(spoke2), MAX_SUPPLY_AMOUNT);

    vm.prank(user);
    underlying.approve(address(hub1), amount);
    deal(address(underlying), user, MAX_SUPPLY_AMOUNT);

    vm.prank(address(spoke1));
    uint256 addedShares = hub1.add(assetId, amount, user);

    Utils.draw(hub1, assetId, address(spoke2), address(spoke2), 1e18);

    Utils.add(hub1, assetId, address(spoke2), 100e18, user);

    skip(365 days);

    console.log('added amt %e %e', addedShares, hub1.getSpokeAddedAssets(assetId, address(spoke1)));

    Utils.remove(
      hub1,
      assetId,
      address(spoke1),
      hub1.getSpokeAddedAssets(assetId, address(spoke1)),
      address(spoke1)
    );

    console.log('remaining spoke1 amt %e', hub1.getSpokeAddedAssets(assetId, address(spoke1)));

    Utils.restoreDrawn(
      hub1,
      assetId,
      address(spoke2),
      hub1.getSpokeTotalOwed(assetId, address(spoke2)),
      address(spoke2)
    );

    Utils.remove(
      hub1,
      assetId,
      address(spoke2),
      hub1.getSpokeAddedAssets(assetId, address(spoke2)),
      address(spoke2)
    );

    console.log(
      'total added amt %e; spoke1 %e; spoke2 %e',
      hub1.getAddedAssets(assetId),
      hub1.getSpokeAddedAssets(assetId, address(spoke2)),
      hub1.getSpokeAddedAssets(assetId, address(spoke1))
    );
    console.log('remaining underlying %e', underlying.balanceOf(address(hub1)));
  }
}
