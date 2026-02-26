// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/Hub/HubBase.t.sol';
import {SafeCast} from 'src/dependencies/openzeppelin/SafeCast.sol';
import {FeeSharesMinterBase} from 'src/utils/FeeSharesMinterBase.sol';
import {IFeeSharesMinterBase} from 'src/utils/IFeeSharesMinterBase.sol';

contract FeeSharesMinterBaseTest is HubBase {
  using SafeCast for uint256;

  FeeSharesMinterBase internal minter;

  function setUp() public override {
    super.setUp();
    minter = new FeeSharesMinterBase(ADMIN);

    // Grant minter the HUB_ADMIN_ROLE so it can call mintFeeShares
    vm.prank(ADMIN);
    accessManager.grantRole(Roles.HUB_ADMIN_ROLE, address(minter), 0);
  }

  function test_setConfig_revertsWith_OwnableUnauthorized() public {
    IFeeSharesMinterBase.MintConfig memory config = IFeeSharesMinterBase.MintConfig({
      minTimeInterval: 1 days,
      minUnrealizedFeePercent: 100 // 1%
    });

    vm.prank(bob);
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, bob));
    minter.setConfig(address(hub1), daiAssetId, config);
  }

  function test_execute_success() public {
    IFeeSharesMinterBase.MintConfig memory config = IFeeSharesMinterBase.MintConfig({
      minTimeInterval: 1 days,
      minUnrealizedFeePercent: 10 // 0.1%
    });
    vm.prank(ADMIN);
    minter.setConfig(address(hub1), daiAssetId, config);

    // Generate fees
    // Add 1000 DAI, borrow 900 DAI
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

    assertTrue(minter.checkExecute(address(hub1), daiAssetId), 'Should be executable');

    minter.execute(address(hub1), daiAssetId);

    assertEq(minter.lastMintTime(address(hub1), daiAssetId), block.timestamp);
    assertFalse(
      minter.checkExecute(address(hub1), daiAssetId),
      'Should not be executable immediately after'
    );
  }

  function test_fuzz_execute(
    uint256 addAmount,
    uint256 drawAmount,
    uint256 skipTime,
    uint32 minTimeInterval,
    uint16 minUnrealizedFeePercent
  ) public {
    addAmount = bound(addAmount, 2, MAX_SUPPLY_AMOUNT);
    drawAmount = bound(drawAmount, 1, addAmount / 2);
    skipTime = bound(skipTime, 1, MAX_SKIP_TIME);
    minTimeInterval = bound(minTimeInterval, 0, 365 days).toUint32();
    minUnrealizedFeePercent = bound(minUnrealizedFeePercent, 0, 10000).toUint16();

    IFeeSharesMinterBase.MintConfig memory config = IFeeSharesMinterBase.MintConfig({
      minTimeInterval: minTimeInterval,
      minUnrealizedFeePercent: minUnrealizedFeePercent
    });
    vm.prank(ADMIN);
    minter.setConfig(address(hub1), daiAssetId, config);

    _addAndDrawLiquidity({
      hub: hub1,
      assetId: daiAssetId,
      addUser: bob,
      addSpoke: address(spoke1),
      addAmount: addAmount,
      drawUser: bob,
      drawSpoke: address(spoke1),
      drawAmount: drawAmount,
      skipTime: skipTime
    });

    bool shouldExecute = minter.checkExecute(address(hub1), daiAssetId);

    if (shouldExecute) {
      minter.execute(address(hub1), daiAssetId);

      assertEq(minter.lastMintTime(address(hub1), daiAssetId), block.timestamp);
      assertFalse(
        minter.checkExecute(address(hub1), daiAssetId),
        'Should not be executable immediately after'
      );
    } else {
      vm.expectRevert(IFeeSharesMinterBase.ConditionsNotMet.selector);
      minter.execute(address(hub1), daiAssetId);
    }
  }

  function test_execute_revertsWith_TimeIntervalNotMet() public {
    IFeeSharesMinterBase.MintConfig memory config = IFeeSharesMinterBase.MintConfig({
      minTimeInterval: 7 days,
      minUnrealizedFeePercent: 0
    });
    vm.prank(ADMIN);
    minter.setConfig(address(hub1), daiAssetId, config);

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

    minter.execute(address(hub1), daiAssetId); // Success, sets lastMintTime = block.timestamp

    vm.warp(block.timestamp + 1 days); // Only 1 day passed, config needs 7

    vm.expectRevert(IFeeSharesMinterBase.ConditionsNotMet.selector);
    minter.execute(address(hub1), daiAssetId);
  }

  function test_execute_revertsWith_MinShareNotMet() public {
    IFeeSharesMinterBase.MintConfig memory config = IFeeSharesMinterBase.MintConfig({
      minTimeInterval: 0,
      minUnrealizedFeePercent: 0
    });
    vm.prank(ADMIN);
    minter.setConfig(address(hub1), daiAssetId, config);

    // Add liquidity but NO borrow -> No fees
    Utils.add(hub1, daiAssetId, address(spoke1), 1000e18, bob);

    skip(365 days); // Time passes

    uint256 accruedFees = hub1.getAssetAccruedFees(daiAssetId);
    assertEq(accruedFees, 0, 'No fees should be accrued');

    assertFalse(minter.checkExecute(address(hub1), daiAssetId));

    vm.expectRevert(IFeeSharesMinterBase.ConditionsNotMet.selector);
    minter.execute(address(hub1), daiAssetId);
  }

  function test_execute_revertsWith_PercentThresholdNotMet() public {
    IFeeSharesMinterBase.MintConfig memory config = IFeeSharesMinterBase.MintConfig({
      minTimeInterval: 0,
      minUnrealizedFeePercent: 5000 // 50% threshold
    });
    vm.prank(ADMIN);
    minter.setConfig(address(hub1), daiAssetId, config);

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

    assertFalse(minter.checkExecute(address(hub1), daiAssetId));

    vm.expectRevert(IFeeSharesMinterBase.ConditionsNotMet.selector);
    minter.execute(address(hub1), daiAssetId);
  }

  function test_execute_largeScalePrecision() public {
    // 1 billion assets (1e9 * 1e18 = 1e27)
    uint256 hugeAssets = 1_000_000_000e18;
    // 1 bps of that (1e27 / 10000 = 1e23)
    uint256 oneBpsFees = hugeAssets / 10000;

    // Config: 1 bps min
    IFeeSharesMinterBase.MintConfig memory config = IFeeSharesMinterBase.MintConfig({
      minTimeInterval: 0,
      minUnrealizedFeePercent: 1 // 1 BPS
    });
    vm.prank(ADMIN);
    minter.setConfig(address(hub1), daiAssetId, config);

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

    assertTrue(minter.checkExecute(address(hub1), daiAssetId), 'Should pass at exactly 1 bps');

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

    assertFalse(minter.checkExecute(address(hub1), daiAssetId), 'Should fail just below 1 bps');
  }

  function test_fuzz_setConfig_success(
    uint32 minTimeInterval,
    uint16 minUnrealizedFeePercent
  ) public {
    minTimeInterval = bound(minTimeInterval, 0, 365 days).toUint32();
    minUnrealizedFeePercent = bound(minUnrealizedFeePercent, 0, 10000).toUint16();

    IFeeSharesMinterBase.MintConfig memory config = IFeeSharesMinterBase.MintConfig({
      minTimeInterval: minTimeInterval,
      minUnrealizedFeePercent: minUnrealizedFeePercent
    });

    vm.prank(ADMIN);
    minter.setConfig(address(hub1), daiAssetId, config);

    IFeeSharesMinterBase.MintConfig memory savedConfig = minter.getConfig(
      address(hub1),
      daiAssetId
    );
    assertEq(savedConfig.minTimeInterval, minTimeInterval);
    assertEq(savedConfig.minUnrealizedFeePercent, minUnrealizedFeePercent);
  }

  function test_fuzz_setConfig_revertsWith_InvalidConfig_TimeInterval(
    uint32 minTimeInterval
  ) public {
    minTimeInterval = bound(minTimeInterval, 365 days + 1, type(uint32).max).toUint32();

    IFeeSharesMinterBase.MintConfig memory config = IFeeSharesMinterBase.MintConfig({
      minTimeInterval: minTimeInterval,
      minUnrealizedFeePercent: 0
    });

    vm.prank(ADMIN);
    vm.expectRevert(IFeeSharesMinterBase.InvalidConfig.selector);
    minter.setConfig(address(hub1), daiAssetId, config);
  }

  function test_fuzz_setConfig_revertsWith_InvalidConfig_FeePercent(
    uint16 minUnrealizedFeePercent
  ) public {
    minUnrealizedFeePercent = bound(minUnrealizedFeePercent, 10001, type(uint16).max).toUint16();

    IFeeSharesMinterBase.MintConfig memory config = IFeeSharesMinterBase.MintConfig({
      minTimeInterval: 0,
      minUnrealizedFeePercent: minUnrealizedFeePercent
    });

    vm.prank(ADMIN);
    vm.expectRevert(IFeeSharesMinterBase.InvalidConfig.selector);
    minter.setConfig(address(hub1), daiAssetId, config);
  }

  function test_rescueToken() public {
    // Mint some dummy tokens to FeeSharesMinterBase
    MockERC20 token = new MockERC20();
    token.mint(address(minter), 1000e18);

    assertEq(token.balanceOf(address(minter)), 1000e18, 'Minter should have tokens');

    // Attempt rescue by non-owner (should fail)
    vm.prank(bob);
    vm.expectRevert(abi.encodeWithSelector(IRescuable.OnlyRescueGuardian.selector));
    minter.rescueToken(address(token), bob, 1000e18);

    // Rescue by owner (should succeed)
    vm.prank(ADMIN);
    minter.rescueToken(address(token), ADMIN, 1000e18);

    assertEq(token.balanceOf(address(minter)), 0, 'Minter should be empty');
    assertEq(token.balanceOf(ADMIN), 1000e18, 'Admin should have tokens');
  }

  function test_transferOwnership_2Step() public {
    address newOwner = makeAddr('newOwner');

    // Transfer ownership (starts 2-step process)
    vm.prank(ADMIN);
    minter.transferOwnership(newOwner);

    // Verify owner hasn't changed yet
    assertEq(minter.owner(), ADMIN, 'Owner should still be ADMIN');
    // Verify pending owner
    assertEq(minter.pendingOwner(), newOwner, 'Pending owner should be newOwner');

    // Accept ownership
    vm.prank(newOwner);
    minter.acceptOwnership();

    // Verify owner changed
    assertEq(minter.owner(), newOwner, 'Owner should now be newOwner');
    assertEq(minter.pendingOwner(), address(0), 'Pending owner should be cleared');
  }

  function test_checkUpkeep_returnsTrue_whenConditionsMet() public {
    IFeeSharesMinterBase.MintConfig memory config = IFeeSharesMinterBase.MintConfig({
      minTimeInterval: 1 days,
      minUnrealizedFeePercent: 10 // 0.1%
    });
    vm.prank(ADMIN);
    minter.setConfig(address(hub1), daiAssetId, config);

    _addAndDrawLiquidity({
      hub: hub1,
      assetId: daiAssetId,
      addUser: bob,
      addSpoke: address(spoke1),
      addAmount: 1000e18,
      drawUser: bob,
      drawSpoke: address(spoke1),
      drawAmount: 900e18,
      skipTime: 365 days
    });

    bytes memory checkData = abi.encode(address(hub1), daiAssetId);
    (bool upkeepNeeded, bytes memory performData) = minter.checkUpkeep(checkData);

    assertTrue(
      minter.checkExecute(address(hub1), daiAssetId),
      'checkExecute should also return true'
    );
    assertTrue(upkeepNeeded, 'checkUpkeep should return true when conditions are met');
    assertEq(performData, checkData, 'performData should echo checkData');
  }

  function test_checkUpkeep_timeInterval_boundary() public {
    IFeeSharesMinterBase.MintConfig memory config = IFeeSharesMinterBase.MintConfig({
      minTimeInterval: 7 days,
      minUnrealizedFeePercent: 0
    });
    vm.prank(ADMIN);
    minter.setConfig(address(hub1), daiAssetId, config);

    _addAndDrawLiquidity({
      hub: hub1,
      assetId: daiAssetId,
      addUser: bob,
      addSpoke: address(spoke1),
      addAmount: 1000e18,
      drawUser: bob,
      drawSpoke: address(spoke1),
      drawAmount: 100e18,
      skipTime: 6 days
    });

    bytes memory checkData = abi.encode(address(hub1), daiAssetId);
    (bool upkeepNeeded, ) = minter.checkUpkeep(checkData);
    assertFalse(
      minter.checkExecute(address(hub1), daiAssetId),
      'checkExecute should be false at 6 days'
    );
    assertFalse(upkeepNeeded, 'checkUpkeep should be false at 6 days');

    vm.warp(block.timestamp + 1 days);

    (bool upkeepNeededAfter, bytes memory performData) = minter.checkUpkeep(checkData);
    assertTrue(
      minter.checkExecute(address(hub1), daiAssetId),
      'checkExecute should be true at 7 days'
    );
    assertTrue(upkeepNeededAfter, 'checkUpkeep should be true at 7 days');
    assertEq(performData, checkData, 'performData should echo checkData');
  }

  function test_checkUpkeep_returnsFalse_whenNoFees() public {
    IFeeSharesMinterBase.MintConfig memory config = IFeeSharesMinterBase.MintConfig({
      minTimeInterval: 0,
      minUnrealizedFeePercent: 0
    });
    vm.prank(ADMIN);
    minter.setConfig(address(hub1), daiAssetId, config);

    // Liquidity added, but no fees accrued
    Utils.add(hub1, daiAssetId, address(spoke1), 1000e18, bob);
    skip(365 days);

    bytes memory checkData = abi.encode(address(hub1), daiAssetId);
    (bool upkeepNeeded, ) = minter.checkUpkeep(checkData);

    assertFalse(upkeepNeeded, 'checkUpkeep should return false with no fees');
  }

  function test_performUpkeep_success() public {
    IFeeSharesMinterBase.MintConfig memory config = IFeeSharesMinterBase.MintConfig({
      minTimeInterval: 1 days,
      minUnrealizedFeePercent: 10 // 0.1%
    });
    vm.prank(ADMIN);
    minter.setConfig(address(hub1), daiAssetId, config);

    _addAndDrawLiquidity({
      hub: hub1,
      assetId: daiAssetId,
      addUser: bob,
      addSpoke: address(spoke1),
      addAmount: 1000e18,
      drawUser: bob,
      drawSpoke: address(spoke1),
      drawAmount: 900e18,
      skipTime: 365 days
    });

    bytes memory performData = abi.encode(address(hub1), daiAssetId);
    minter.performUpkeep(performData);

    assertEq(
      minter.lastMintTime(address(hub1), daiAssetId),
      block.timestamp,
      'lastMintTime should be updated'
    );
    // Conditions should no longer be met (interval resets)
    assertFalse(
      minter.checkExecute(address(hub1), daiAssetId),
      'Should not be executable immediately after'
    );
  }

  function test_performUpkeep_timeInterval_boundary() public {
    IFeeSharesMinterBase.MintConfig memory config = IFeeSharesMinterBase.MintConfig({
      minTimeInterval: 7 days,
      minUnrealizedFeePercent: 0
    });
    vm.prank(ADMIN);
    minter.setConfig(address(hub1), daiAssetId, config);

    _addAndDrawLiquidity({
      hub: hub1,
      assetId: daiAssetId,
      addUser: bob,
      addSpoke: address(spoke1),
      addAmount: 1000e18,
      drawUser: bob,
      drawSpoke: address(spoke1),
      drawAmount: 100e18,
      skipTime: 6 days
    });

    bytes memory performData = abi.encode(address(hub1), daiAssetId);
    vm.expectRevert(IFeeSharesMinterBase.ConditionsNotMet.selector);
    minter.performUpkeep(performData);

    vm.warp(block.timestamp + 1 days);
    minter.performUpkeep(performData);

    assertEq(
      minter.lastMintTime(address(hub1), daiAssetId),
      block.timestamp,
      'lastMintTime should be updated'
    );
  }

  function test_performUpkeep_revertsWith_ConditionsNotMet_noFees() public {
    IFeeSharesMinterBase.MintConfig memory config = IFeeSharesMinterBase.MintConfig({
      minTimeInterval: 0,
      minUnrealizedFeePercent: 0
    });
    vm.prank(ADMIN);
    minter.setConfig(address(hub1), daiAssetId, config);

    Utils.add(hub1, daiAssetId, address(spoke1), 1000e18, bob);
    skip(365 days);

    bytes memory performData = abi.encode(address(hub1), daiAssetId);
    vm.expectRevert(IFeeSharesMinterBase.ConditionsNotMet.selector);
    minter.performUpkeep(performData);
  }

  function test_fuzz_performUpkeep_and_checkUpkeep_areConsistent(
    uint256 addAmount,
    uint256 drawAmount,
    uint256 skipTime,
    uint32 minTimeInterval,
    uint16 minUnrealizedFeePercent
  ) public {
    addAmount = bound(addAmount, 2, MAX_SUPPLY_AMOUNT);
    drawAmount = bound(drawAmount, 1, addAmount / 2);
    skipTime = bound(skipTime, 1, MAX_SKIP_TIME);
    minTimeInterval = bound(minTimeInterval, 0, 365 days).toUint32();
    minUnrealizedFeePercent = bound(minUnrealizedFeePercent, 0, 10000).toUint16();

    IFeeSharesMinterBase.MintConfig memory config = IFeeSharesMinterBase.MintConfig({
      minTimeInterval: minTimeInterval,
      minUnrealizedFeePercent: minUnrealizedFeePercent
    });
    vm.prank(ADMIN);
    minter.setConfig(address(hub1), daiAssetId, config);

    _addAndDrawLiquidity({
      hub: hub1,
      assetId: daiAssetId,
      addUser: bob,
      addSpoke: address(spoke1),
      addAmount: addAmount,
      drawUser: bob,
      drawSpoke: address(spoke1),
      drawAmount: drawAmount,
      skipTime: skipTime
    });

    bytes memory checkData = abi.encode(address(hub1), daiAssetId);
    (bool upkeepNeeded, bytes memory performData) = minter.checkUpkeep(checkData);

    assertEq(
      upkeepNeeded,
      minter.checkExecute(address(hub1), daiAssetId),
      'checkUpkeep and checkExecute must be consistent'
    );

    if (upkeepNeeded) {
      minter.performUpkeep(performData);

      assertEq(minter.lastMintTime(address(hub1), daiAssetId), block.timestamp);

      (bool upkeepNeededAfter, ) = minter.checkUpkeep(checkData);
      assertFalse(upkeepNeededAfter, 'checkUpkeep should return false after performUpkeep');
      assertFalse(
        minter.checkExecute(address(hub1), daiAssetId),
        'checkExecute should return false after performUpkeep'
      );
    } else {
      vm.expectRevert(IFeeSharesMinterBase.ConditionsNotMet.selector);
      minter.performUpkeep(performData);
    }
  }
}
