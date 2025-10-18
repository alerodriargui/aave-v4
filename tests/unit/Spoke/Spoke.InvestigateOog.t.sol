// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/SpokeBase.t.sol';

contract SpokeInvestigateOogTest is SpokeBase {
  function setUp() public override {
    super.setUp();

    // Add a bunch of new reserves and assets to hub1 and spoke1
    _addNewAssetsAndReserves(164);
  }

  function test_oog() public {
    console.log('made it out of setup');

    uint256 i;
    // Supply x collaterals
    for (i = 0; i < spoke1.getReserveCount(); i++) {
      Utils.supplyCollateral(spoke1, i, alice, 1000e18, alice);

      skip(1 days); // Ensure interest accrual

      vm.prank(alice);
      spoke1.borrow(i, 500e18, alice);

      console.log('Alice could borrow using', i + 1, 'collaterals');
    }

    console.log('exited loop');

    skip(10000 days);
    // Alice can be liquidated
    assertLe(
      spoke1.getUserAccountData(alice).healthFactor,
      spoke1.HEALTH_FACTOR_LIQUIDATION_THRESHOLD()
    );

    console.log('Attempting liquidation with alice at ', i, ' collaterals');
    vm.prank(bob);
    spoke1.liquidationCall(0, 1, alice, 1, false);
    console.log('Liquidation succeeded with alice at ', i, ' collaterals');
  }

  function _addNewAssetsAndReserves(uint256 count) internal {
    for (uint256 i = 0; i < count; i++) {
      MockERC20 newToken = new MockERC20();
      newToken.mint(alice, MAX_SUPPLY_AMOUNT * 10 ** 18);
      vm.prank(alice);
      newToken.approve(address(hub1), UINT256_MAX);

      IHub.SpokeConfig memory spokeConfig = IHub.SpokeConfig({
        active: true,
        paused: false,
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

      // Add asset to hub1
      vm.startPrank(ADMIN);
      uint256 newTokenAssetId = hub1.addAsset(
        address(newToken),
        18,
        address(treasurySpoke),
        address(irStrategy),
        encodedIrData
      );
      hub1.updateAssetConfig(
        newTokenAssetId,
        IHub.AssetConfig({
          liquidityFee: 10_00,
          feeReceiver: address(treasurySpoke),
          irStrategy: address(irStrategy),
          reinvestmentController: address(0)
        }),
        new bytes(0)
      );

      // Prepare the reserve configs
      ISpoke.ReserveConfig memory reserveConfig = ISpoke.ReserveConfig({
        paused: false,
        frozen: false,
        borrowable: true,
        collateralRisk: _randomBps()
      });
      ISpoke.DynamicReserveConfig memory dynamicConfig = ISpoke.DynamicReserveConfig({
        collateralFactor: 80_00,
        maxLiquidationBonus: 105_00,
        liquidationFee: 10_00
      });

      // Add reserve to spoke1
      spoke1.addReserve(
        address(hub1),
        newTokenAssetId,
        _deployMockPriceFeed(spoke1, 1e8),
        reserveConfig,
        dynamicConfig
      );

      // Add spoke to hub
      hub1.addSpoke(newTokenAssetId, address(spoke1), spokeConfig);
      vm.stopPrank();
    }
  }
}
