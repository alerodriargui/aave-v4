// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/SpokeBase.t.sol';

contract SpokeMaxReservesTest is SpokeBase {
  uint256 public constant MAX_TX_GAS = 16_780_000;

  function setUp() public override {
    super.setUp();

    // Add a bunch of new reserves and assets to hub1 and spoke1
    _addNewAssetsAndReserves(161);
  }

  function test_spokeMaxReserves() public {
    uint256 i;
    uint256 gasUsed;
    // Supply x collaterals
    for (i = 0; i < spoke1.getReserveCount(); i++) {
      Utils.supplyCollateral(spoke1, i, alice, 1000e18, alice);

      skip(1 days); // Ensure interest accrual

      vm.prank(alice);
      spoke1.borrow(i, 500e18, alice);
      gasUsed = vm.snapshotGasLastCall('Spoke.Investigation', 'borrow');

      if (gasUsed > MAX_TX_GAS) {
        console.log('OOG at', i + 1, 'collaterals');
        break;
      }

      console.log('Alice could borrow using', i + 1, 'collaterals');
      console.log('Cost', gasUsed);
    }

    skip(10000 days);
    // Alice can be liquidated
    assertLe(
      spoke1.getUserAccountData(alice).healthFactor,
      LiquidationLogic.HEALTH_FACTOR_LIQUIDATION_THRESHOLD
    );

    console.log('Attempting liquidation with alice at ', i, ' collaterals');
    vm.prank(bob);
    spoke1.liquidationCall(0, 1, alice, 1, false);
    gasUsed = vm.snapshotGasLastCall('Spoke.Investigation', 'liquidationCall');
    if (gasUsed > MAX_TX_GAS) {
      console.log('Liquidation OOG at ', i, ' collaterals');
      return;
    }
    console.log('Liquidation succeeded with alice at ', i, ' collaterals');
    console.log('Cost', gasUsed);
  }

  function test_quote_oracles() public {
    // Check gas price of mock oracle
    IAaveOracle oracle = IAaveOracle(spoke1.ORACLE());
    oracle.getReservePrice(0);
    uint256 gasUsed = vm.snapshotGasLastCall('Spoke.Investigation', 'getReservePrice');
    console.log('Mock oracle gas cost:', gasUsed);

    // Check gas price of chainlink oracle
    vm.createSelectFork('mainnet', 23931982);
    address ethUsdFeed = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419;
    AggregatorV3Interface priceFeed = AggregatorV3Interface(ethUsdFeed);
    priceFeed.latestRoundData();
    gasUsed = vm.snapshotGasLastCall('Spoke.Investigation', 'latestRoundData');
    console.log('Chainlink oracle gas cost:', gasUsed);
  }

  function _addNewAssetsAndReserves(uint256 count) internal {
    // Ensure spoke1's collateral risks are sorted
    uint24 collateralRisk;
    for (uint256 i = 0; i < spoke1.getReserveCount(); i++) {
      assertLe(
        collateralRisk,
        spoke1.getReserveConfig(i).collateralRisk,
        'Spoke1 reserves not sorted by collateral risk'
      );
      collateralRisk = spoke1.getReserveConfig(i).collateralRisk;
    }

    collateralRisk = spoke1.getReserveConfig(spoke1.getReserveCount() - 1).collateralRisk; // Get the last reserve's collateral risk
    for (uint256 i = 0; i < count; i++) {
      MockERC20 newToken = new MockERC20();
      newToken.mint(alice, MAX_SUPPLY_AMOUNT * 10 ** 18);
      vm.prank(alice);
      newToken.approve(address(spoke1), UINT256_MAX);

      IHub.SpokeConfig memory spokeConfig = IHub.SpokeConfig({
        active: true,
        paused: false,
        addCap: Constants.MAX_ALLOWED_SPOKE_CAP,
        drawCap: Constants.MAX_ALLOWED_SPOKE_CAP,
        riskPremiumThreshold: 1000_00
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
        collateralRisk: ++collateralRisk, // Increasing collateral risk to maintain sorted order (worst case for quicksort)
        liquidatable: true,
        receiveSharesEnabled: true
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
