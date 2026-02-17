// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import 'tests/unit/Hub/HubBase.t.sol';
import {FeeSharesMinterBase} from 'src/hub/FeeSharesMinterBase.sol';

contract FeeSharesMinterBaseTest is HubBase {
  FeeSharesMinterBase internal minter;

  function setUp() public override {
    super.setUp();
    minter = new FeeSharesMinterBase(ADMIN, hub1);

    // Grant minter the HUB_ADMIN_ROLE so it can call mintFeeShares
    vm.prank(ADMIN);
    accessManager.grantRole(Roles.HUB_ADMIN_ROLE, address(minter), 0);
  }

  function test_setConfig_revertsWith_OwnableUnauthorized() public {
    FeeSharesMinterBase.MintConfig memory config = FeeSharesMinterBase.MintConfig({
      minTimeInterval: 1 days,
      minUnrealizedFeePercent: 100 // 1%
    });

    vm.prank(bob);
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, bob));
    minter.setConfig(daiAssetId, config);
  }

  function test_execute_success() public {
    FeeSharesMinterBase.MintConfig memory config = FeeSharesMinterBase.MintConfig({
      minTimeInterval: 1 days,
      minUnrealizedFeePercent: 10 // 0.1%
    });
    vm.prank(ADMIN);
    minter.setConfig(daiAssetId, config);

    // Generate fees
    // Add 1000 DAI, borrow 100 DAI
    _addAndDrawLiquidity({
      hub: hub1,
      assetId: daiAssetId,
      addUser: bob,
      addSpoke: address(spoke1),
      addAmount: 1000e18,
      drawUser: bob,
      drawSpoke: address(spoke1),
      drawAmount: 900e18,
      skipTime: 365 days // Skip enough time for interval and fee accrual
    });

    assertTrue(minter.checkExecute(daiAssetId), 'Should be executable');

    vm.expectEmit(address(minter));
    emit FeeSharesMinterBase.FeeSharesMinted(
      daiAssetId,
      hub1.previewAddByAssets(daiAssetId, hub1.getAssetAccruedFees(daiAssetId))
    );

    minter.execute(daiAssetId);

    assertEq(minter.lastMintTime(daiAssetId), block.timestamp);
    assertFalse(minter.checkExecute(daiAssetId), 'Should not be executable immediately after');
  }

  function test_execute_revertsWith_TimeIntervalNotMet() public {
    FeeSharesMinterBase.MintConfig memory config = FeeSharesMinterBase.MintConfig({
      minTimeInterval: 7 days,
      minUnrealizedFeePercent: 0
    });
    vm.prank(ADMIN);
    minter.setConfig(daiAssetId, config);

    _addAndDrawLiquidity({
      hub: hub1,
      assetId: daiAssetId,
      addUser: bob,
      addSpoke: address(spoke1),
      addAmount: 1000e18,
      drawUser: bob,
      drawSpoke: address(spoke1),
      drawAmount: 100e18,
      skipTime: 8 days
    });

    minter.execute(daiAssetId); // Success, sets lastMintTime = block.timestamp

    vm.warp(block.timestamp + 1 days); // Only 1 day passed, config needs 7

    vm.expectRevert(FeeSharesMinterBase.ConditionsNotMet.selector);
    minter.execute(daiAssetId);
  }

  function test_execute_revertsWith_MinShareNotMet() public {
    FeeSharesMinterBase.MintConfig memory config = FeeSharesMinterBase.MintConfig({
      minTimeInterval: 0,
      minUnrealizedFeePercent: 0
    });
    vm.prank(ADMIN);
    minter.setConfig(daiAssetId, config);

    // Add liquidity but NO borrow -> No fees
    Utils.add(hub1, daiAssetId, address(spoke1), 1000e18, bob);

    skip(365 days); // Time passes

    uint256 accruedFees = hub1.getAssetAccruedFees(daiAssetId);
    assertEq(accruedFees, 0, 'No fees should be accrued');

    assertFalse(minter.checkExecute(daiAssetId));

    vm.expectRevert(FeeSharesMinterBase.ConditionsNotMet.selector);
    minter.execute(daiAssetId);
  }

  function test_execute_revertsWith_PercentThresholdNotMet() public {
    FeeSharesMinterBase.MintConfig memory config = FeeSharesMinterBase.MintConfig({
      minTimeInterval: 0,
      minUnrealizedFeePercent: 5000 // 50% threshold
    });
    vm.prank(ADMIN);
    minter.setConfig(daiAssetId, config);

    _addAndDrawLiquidity({
      hub: hub1,
      assetId: daiAssetId,
      addUser: bob,
      addSpoke: address(spoke1),
      addAmount: 1000e18,
      drawUser: bob,
      drawSpoke: address(spoke1),
      drawAmount: 100e18,
      skipTime: 1 days
    });

    assertFalse(minter.checkExecute(daiAssetId));

    vm.expectRevert(FeeSharesMinterBase.ConditionsNotMet.selector);
    minter.execute(daiAssetId);
  }

  function test_execute_largeScalePrecision() public {
    // 1 billion assets (1e9 * 1e18 = 1e27)
    uint256 hugeAssets = 1_000_000_000e18;
    // 1 bps of that (1e27 / 10000 = 1e23)
    uint256 oneBpsFees = hugeAssets / 10000;

    // Config: 1 bps min
    FeeSharesMinterBase.MintConfig memory config = FeeSharesMinterBase.MintConfig({
      minTimeInterval: 0,
      minUnrealizedFeePercent: 1 // 1 BPS
    });
    vm.prank(ADMIN);
    minter.setConfig(daiAssetId, config);

    // Mock Hub calls to simulate this exact state
    vm.mockCall(
      address(hub1),
      abi.encodeWithSelector(IHubBase.getAddedAssets.selector, daiAssetId),
      abi.encode(hugeAssets)
    );
    vm.mockCall(
      address(hub1),
      abi.encodeWithSelector(IHub.getAssetAccruedFees.selector, daiAssetId),
      abi.encode(oneBpsFees)
    );
    // Also mock previewAddByAssets to ensure min shares check passes (1e23 fees > 1 share)
    vm.mockCall(
      address(hub1),
      abi.encodeWithSelector(IHubBase.previewAddByAssets.selector, daiAssetId, oneBpsFees),
      abi.encode(100e18) // Just needs to be >= 1
    );

    assertTrue(minter.checkExecute(daiAssetId), 'Should pass at exactly 1 bps');

    // Test just below 1 bps
    vm.mockCall(
      address(hub1),
      abi.encodeWithSelector(IHub.getAssetAccruedFees.selector, daiAssetId),
      abi.encode(oneBpsFees - 1)
    );
    // Mock the preview call for the new fee amount as well
    vm.mockCall(
      address(hub1),
      abi.encodeWithSelector(IHubBase.previewAddByAssets.selector, daiAssetId, oneBpsFees - 1),
      abi.encode(100e18)
    );

    assertFalse(minter.checkExecute(daiAssetId), 'Should fail just below 1 bps');
  }
}
