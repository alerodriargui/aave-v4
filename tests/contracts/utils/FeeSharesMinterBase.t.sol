// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/setup/Base.t.sol';
import {FeeSharesMinterBase} from 'src/utils/FeeSharesMinterBase.sol';
import {IFeeSharesMinterBase} from 'src/utils/IFeeSharesMinterBase.sol';

contract FeeSharesMinterBaseTest is Base {
  using SafeCast for uint256;
  using PercentageMath for uint256;

  FeeSharesMinterBase internal _minter;

  function setUp() public override {
    super.setUp();
    _minter = new FeeSharesMinterBase(ADMIN);

    // Grant _minter the HUB_ADMIN_ROLE so it can call mintFeeShares
    vm.prank(ADMIN);
    accessManager.grantRole(Roles.HUB_ADMIN_ROLE, address(_minter), 0);
  }

  function test_setConfig_revertsWith_OwnableUnauthorized() public {
    IFeeSharesMinterBase.MintConfig memory config = IFeeSharesMinterBase.MintConfig({
      minTimeInterval: 1 days,
      minAccruedFeesPercent: 100 // 1%
    });

    vm.prank(bob);
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, bob));
    _minter.setConfig(address(hub1), daiAssetId, config);
  }

  function test_execute() public {
    test_fuzz_execute({
      addAmount: 1000e18,
      drawAmount: 900e18,
      skipTime: 365 days,
      minTimeInterval: 1 days,
      minAccruedFeesPercent: 10
    });
  }

  function test_fuzz_execute(
    uint256 addAmount,
    uint256 drawAmount,
    uint256 skipTime,
    uint32 minTimeInterval,
    uint16 minAccruedFeesPercent
  ) public {
    addAmount = bound(addAmount, 2, MAX_SUPPLY_AMOUNT);
    drawAmount = bound(drawAmount, 1, addAmount / 2);
    skipTime = bound(skipTime, 1, MAX_SKIP_TIME);
    minTimeInterval = bound(minTimeInterval, 0, _minter.MAX_TIME_INTERVAL()).toUint32();
    minAccruedFeesPercent = bound(minAccruedFeesPercent, 0, PercentageMath.PERCENTAGE_FACTOR)
      .toUint16();

    IFeeSharesMinterBase.MintConfig memory config = IFeeSharesMinterBase.MintConfig({
      minTimeInterval: minTimeInterval,
      minAccruedFeesPercent: minAccruedFeesPercent
    });
    vm.prank(ADMIN);
    _minter.setConfig(address(hub1), daiAssetId, config);

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

    if (_minter.checkExecute(address(hub1), daiAssetId)) {
      _minter.execute(address(hub1), daiAssetId);

      assertEq(_minter.lastMintTime(address(hub1), daiAssetId), block.timestamp);
      assertFalse(
        _minter.checkExecute(address(hub1), daiAssetId),
        'Should not be executable immediately after'
      );
    } else {
      vm.expectRevert(IFeeSharesMinterBase.ConditionsNotMet.selector);
      _minter.execute(address(hub1), daiAssetId);
    }
  }

  function test_execute_revertsWith_ConditionsNotMet_TimeIntervalNotMet() public {
    IFeeSharesMinterBase.MintConfig memory config = IFeeSharesMinterBase.MintConfig({
      minTimeInterval: 7 days,
      minAccruedFeesPercent: 0
    });
    vm.prank(ADMIN);
    _minter.setConfig(address(hub1), daiAssetId, config);

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

    assertFalse(_minter.checkExecute(address(hub1), daiAssetId), 'Not enough time elapsed');
    vm.expectRevert(IFeeSharesMinterBase.ConditionsNotMet.selector);
    _minter.execute(address(hub1), daiAssetId);

    vm.warp(block.timestamp + 1 days);
    assertTrue(
      _minter.checkExecute(address(hub1), daiAssetId),
      'Sufficient conditions for execute'
    );
    _minter.execute(address(hub1), daiAssetId);

    assertEq(_minter.lastMintTime(address(hub1), daiAssetId), block.timestamp, 'Just minted');
    assertFalse(_minter.checkExecute(address(hub1), daiAssetId), 'Cannot mint again immediately');
  }

  function test_execute_revertsWith_ConditionsNotMet_zeroFees() public {
    IFeeSharesMinterBase.MintConfig memory config = IFeeSharesMinterBase.MintConfig({
      minTimeInterval: 0,
      minAccruedFeesPercent: 0
    });
    vm.prank(ADMIN);
    _minter.setConfig(address(hub1), daiAssetId, config);

    // Add liquidity, but no borrow, so no fees
    HubActions.add({
      hub: hub1,
      assetId: daiAssetId,
      caller: address(spoke1),
      amount: 1000e18,
      user: bob
    });

    skip(365 days);

    uint256 accruedFees = hub1.getAssetAccruedFees(daiAssetId);
    assertEq(accruedFees, 0, 'No fees should be accrued');

    assertFalse(_minter.checkExecute(address(hub1), daiAssetId));

    vm.expectRevert(IFeeSharesMinterBase.ConditionsNotMet.selector);
    _minter.execute(address(hub1), daiAssetId);
  }

  function test_execute_revertsWith_ConditionsNotMet_PercentThresholdNotMet() public {
    IFeeSharesMinterBase.MintConfig memory config = IFeeSharesMinterBase.MintConfig({
      minTimeInterval: 0,
      minAccruedFeesPercent: 5000 // 50% threshold
    });
    vm.prank(ADMIN);
    _minter.setConfig(address(hub1), daiAssetId, config);

    _addAndDrawLiquidity({
      hub: hub1,
      assetId: daiAssetId,
      addUser: bob,
      addSpoke: address(spoke1),
      addAmount: 1000e18,
      drawUser: bob,
      drawSpoke: address(spoke1),
      drawAmount: 100e18,
      skipTime: 365 days
    });

    uint256 fees = hub1.getAssetAccruedFees(daiAssetId);
    uint256 totalAssets = hub1.getAddedAssets(daiAssetId);

    assertGt(fees, 0, 'Fees must be nonzero');
    assertGt(hub1.previewAddByAssets(daiAssetId, fees), 0, 'At least 1 share would be minted');
    assertLt(fees, totalAssets / 2, 'Fees must be < 50% of total');

    assertFalse(_minter.checkExecute(address(hub1), daiAssetId));

    vm.expectRevert(IFeeSharesMinterBase.ConditionsNotMet.selector);
    _minter.execute(address(hub1), daiAssetId);
  }

  function test_execute_revertsWith_ConditionsNotMet_MinShareNotMet_nonzeroFees() public {
    IFeeSharesMinterBase.MintConfig memory config = IFeeSharesMinterBase.MintConfig({
      minTimeInterval: 0,
      minAccruedFeesPercent: 0
    });
    vm.prank(ADMIN);
    _minter.setConfig(address(hub1), daiAssetId, config);

    // Inflate exchange rate
    _addAndDrawLiquidity({
      hub: hub1,
      assetId: daiAssetId,
      addUser: bob,
      addSpoke: address(spoke1),
      addAmount: 300 wei,
      drawUser: bob,
      drawSpoke: address(spoke1),
      drawAmount: 200 wei,
      skipTime: MAX_SKIP_TIME - 110 days
    });

    // Clear accrued fees
    _minter.execute(address(hub1), daiAssetId);

    // Accrue some fees
    skip(110 days);

    uint256 fees = hub1.getAssetAccruedFees(daiAssetId);
    assertGt(fees, 0, 'Fees must be nonzero');
    assertEq(hub1.previewAddByAssets(daiAssetId, fees), 0, 'Shares must round to zero');

    assertFalse(_minter.checkExecute(address(hub1), daiAssetId));

    vm.expectRevert(IFeeSharesMinterBase.ConditionsNotMet.selector);
    _minter.execute(address(hub1), daiAssetId);
  }

  function test_fuzz_setConfig_success(
    uint32 minTimeInterval,
    uint16 minAccruedFeesPercent
  ) public {
    minTimeInterval = bound(minTimeInterval, 0, _minter.MAX_TIME_INTERVAL()).toUint32();
    minAccruedFeesPercent = bound(minAccruedFeesPercent, 0, PercentageMath.PERCENTAGE_FACTOR)
      .toUint16();

    IFeeSharesMinterBase.MintConfig memory config = IFeeSharesMinterBase.MintConfig({
      minTimeInterval: minTimeInterval,
      minAccruedFeesPercent: minAccruedFeesPercent
    });

    vm.prank(ADMIN);
    _minter.setConfig(address(hub1), daiAssetId, config);

    IFeeSharesMinterBase.MintConfig memory savedConfig = _minter.getConfig(
      address(hub1),
      daiAssetId
    );
    assertEq(savedConfig.minTimeInterval, minTimeInterval);
    assertEq(savedConfig.minAccruedFeesPercent, minAccruedFeesPercent);
  }

  function test_fuzz_setConfig_revertsWith_InvalidConfig_TimeInterval(
    uint32 minTimeInterval
  ) public {
    minTimeInterval = bound(minTimeInterval, _minter.MAX_TIME_INTERVAL() + 1, type(uint32).max)
      .toUint32();

    IFeeSharesMinterBase.MintConfig memory config = IFeeSharesMinterBase.MintConfig({
      minTimeInterval: minTimeInterval,
      minAccruedFeesPercent: 0
    });

    vm.prank(ADMIN);
    vm.expectRevert(IFeeSharesMinterBase.InvalidConfig.selector);
    _minter.setConfig(address(hub1), daiAssetId, config);
  }

  function test_fuzz_setConfig_revertsWith_InvalidConfig_FeePercent(
    uint16 minAccruedFeesPercent
  ) public {
    minAccruedFeesPercent = bound(
      minAccruedFeesPercent,
      PercentageMath.PERCENTAGE_FACTOR + 1,
      type(uint16).max
    ).toUint16();

    IFeeSharesMinterBase.MintConfig memory config = IFeeSharesMinterBase.MintConfig({
      minTimeInterval: 0,
      minAccruedFeesPercent: minAccruedFeesPercent
    });

    vm.prank(ADMIN);
    vm.expectRevert(IFeeSharesMinterBase.InvalidConfig.selector);
    _minter.setConfig(address(hub1), daiAssetId, config);
  }

  function test_rescueToken() public {
    uint256 amount = 1000e18;

    // Mint some dummy tokens to FeeSharesMinterBase
    MockERC20 token = new MockERC20();
    token.mint(address(_minter), amount);

    assertEq(token.balanceOf(address(_minter)), amount, 'Minter should have tokens');

    // Attempt rescue by non-owner (should fail)
    vm.prank(bob);
    vm.expectRevert(abi.encodeWithSelector(IRescuable.OnlyRescueGuardian.selector));
    _minter.rescueToken(address(token), bob, amount);

    // Rescue by owner (should succeed)
    vm.prank(ADMIN);
    _minter.rescueToken(address(token), ADMIN, amount);

    assertEq(token.balanceOf(address(_minter)), 0, 'Minter should be empty');
    assertEq(token.balanceOf(ADMIN), amount, 'Admin should have tokens');
  }

  function test_transferOwnership_2Step() public {
    address newOwner = makeAddr('newOwner');

    // Transfer ownership (starts 2-step process)
    vm.prank(ADMIN);
    _minter.transferOwnership(newOwner);

    // Verify owner hasn't changed yet
    assertEq(_minter.owner(), ADMIN, 'Owner should still be ADMIN');
    // Verify pending owner
    assertEq(_minter.pendingOwner(), newOwner, 'Pending owner should be newOwner');

    // Accept ownership
    vm.prank(newOwner);
    _minter.acceptOwnership();

    // Verify owner changed
    assertEq(_minter.owner(), newOwner, 'Owner should now be newOwner');
    assertEq(_minter.pendingOwner(), address(0), 'Pending owner should be cleared');
  }

  function test_performUpkeep() public {
    test_fuzz_performUpkeep({
      addAmount: 1000e18,
      drawAmount: 900e18,
      skipTime: 365 days,
      minTimeInterval: 1 days,
      minAccruedFeesPercent: 10
    });
  }

  function test_fuzz_performUpkeep(
    uint256 addAmount,
    uint256 drawAmount,
    uint256 skipTime,
    uint32 minTimeInterval,
    uint16 minAccruedFeesPercent
  ) public {
    addAmount = bound(addAmount, 2, MAX_SUPPLY_AMOUNT);
    drawAmount = bound(drawAmount, 1, addAmount / 2);
    skipTime = bound(skipTime, 1, MAX_SKIP_TIME);
    minTimeInterval = bound(minTimeInterval, 0, _minter.MAX_TIME_INTERVAL()).toUint32();
    minAccruedFeesPercent = bound(minAccruedFeesPercent, 0, PercentageMath.PERCENTAGE_FACTOR)
      .toUint16();

    IFeeSharesMinterBase.MintConfig memory config = IFeeSharesMinterBase.MintConfig({
      minTimeInterval: minTimeInterval,
      minAccruedFeesPercent: minAccruedFeesPercent
    });
    vm.prank(ADMIN);
    _minter.setConfig(address(hub1), daiAssetId, config);

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
    (bool upkeepNeeded, bytes memory performData) = _minter.checkUpkeep(checkData);

    assertEq(
      upkeepNeeded,
      _minter.checkExecute(address(hub1), daiAssetId),
      'checkUpkeep and checkExecute must be consistent'
    );

    if (upkeepNeeded) {
      _minter.performUpkeep(performData);

      assertEq(_minter.lastMintTime(address(hub1), daiAssetId), block.timestamp);

      (bool upkeepNeededAfter, ) = _minter.checkUpkeep(checkData);
      assertFalse(upkeepNeededAfter, 'checkUpkeep should return false after performUpkeep');
      assertFalse(
        _minter.checkExecute(address(hub1), daiAssetId),
        'checkExecute should return false after performUpkeep'
      );
    } else {
      vm.expectRevert(IFeeSharesMinterBase.ConditionsNotMet.selector);
      _minter.performUpkeep(performData);
    }
  }

  function test_performUpkeep_revertsWith_ConditionsNotMet_timeIntervalNotMet() public {
    IFeeSharesMinterBase.MintConfig memory config = IFeeSharesMinterBase.MintConfig({
      minTimeInterval: 7 days,
      minAccruedFeesPercent: 0
    });
    vm.prank(ADMIN);
    _minter.setConfig(address(hub1), daiAssetId, config);

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
    (bool upkeepNeeded, bytes memory performData) = _minter.checkUpkeep(checkData);

    assertFalse(upkeepNeeded, 'checkUpkeep should be false at 6 days');
    vm.expectRevert(IFeeSharesMinterBase.ConditionsNotMet.selector);
    _minter.performUpkeep(performData);

    vm.warp(block.timestamp + 1 days);

    (bool upkeepNeededAfter, bytes memory performDataAfter) = _minter.checkUpkeep(checkData);
    assertTrue(upkeepNeededAfter, 'checkUpkeep should be true at 7 days');
    _minter.performUpkeep(performDataAfter);

    assertEq(
      _minter.lastMintTime(address(hub1), daiAssetId),
      block.timestamp,
      'lastMintTime should be updated'
    );
    (upkeepNeeded, ) = _minter.checkUpkeep(checkData);
    assertFalse(upkeepNeeded, 'checkUpkeep should be false after performUpkeep');
  }

  function test_performUpkeep_revertsWith_ConditionsNotMet_noFees() public {
    IFeeSharesMinterBase.MintConfig memory config = IFeeSharesMinterBase.MintConfig({
      minTimeInterval: 0,
      minAccruedFeesPercent: 0
    });
    vm.prank(ADMIN);
    _minter.setConfig(address(hub1), daiAssetId, config);

    // Liquidity added, but no fees accrued
    HubActions.add({
      hub: hub1,
      assetId: daiAssetId,
      caller: address(spoke1),
      amount: 1000e18,
      user: bob
    });
    skip(365 days);

    assertEq(hub1.getAssetAccruedFees(daiAssetId), 0, 'Fees should be zero');

    bytes memory checkData = abi.encode(address(hub1), daiAssetId);
    (bool upkeepNeeded, bytes memory performData) = _minter.checkUpkeep(checkData);
    assertFalse(upkeepNeeded, 'checkUpkeep should return false with no fees');

    vm.expectRevert(IFeeSharesMinterBase.ConditionsNotMet.selector);
    _minter.performUpkeep(performData);
  }

  function test_performUpkeep_revertsWith_ConditionsNotMet_percentThresholdNotMet_withMinShares()
    public
  {
    IFeeSharesMinterBase.MintConfig memory config = IFeeSharesMinterBase.MintConfig({
      minTimeInterval: 0,
      minAccruedFeesPercent: 5000
    });
    vm.prank(ADMIN);
    _minter.setConfig(address(hub1), daiAssetId, config);

    _addAndDrawLiquidity({
      hub: hub1,
      assetId: daiAssetId,
      addUser: bob,
      addSpoke: address(spoke1),
      addAmount: 1000e18,
      drawUser: bob,
      drawSpoke: address(spoke1),
      drawAmount: 100e18,
      skipTime: 365 days
    });

    uint256 fees = hub1.getAssetAccruedFees(daiAssetId);
    uint256 totalAssets = hub1.getAddedAssets(daiAssetId);

    assertGt(fees, 0, 'Fees must be nonzero');
    assertGt(hub1.previewAddByAssets(daiAssetId, fees), 0, 'At least 1 share would be minted');
    assertLt(
      fees,
      totalAssets.percentMulDown(config.minAccruedFeesPercent),
      'Fees must be < minAccruedFeesPercent of total'
    );

    bytes memory checkData = abi.encode(address(hub1), daiAssetId);
    (bool upkeepNeeded, bytes memory performData) = _minter.checkUpkeep(checkData);
    assertFalse(upkeepNeeded, 'checkUpkeep should be false: ratio below threshold');

    vm.expectRevert(IFeeSharesMinterBase.ConditionsNotMet.selector);
    _minter.performUpkeep(performData);
  }

  function test_performUpkeep_revertsWith_ConditionsNotMet_MinShareNotMet_nonzeroFees() public {
    IFeeSharesMinterBase.MintConfig memory config = IFeeSharesMinterBase.MintConfig({
      minTimeInterval: 0,
      minAccruedFeesPercent: 0
    });
    vm.prank(ADMIN);
    _minter.setConfig(address(hub1), daiAssetId, config);

    // Inflate exchange rate
    _addAndDrawLiquidity({
      hub: hub1,
      assetId: daiAssetId,
      addUser: bob,
      addSpoke: address(spoke1),
      addAmount: 300 wei,
      drawUser: bob,
      drawSpoke: address(spoke1),
      drawAmount: 200 wei,
      skipTime: MAX_SKIP_TIME - 110 days
    });

    // Clear accrued fees
    _minter.execute(address(hub1), daiAssetId);

    // Accrue some fees
    skip(110 days);

    uint256 fees = hub1.getAssetAccruedFees(daiAssetId);
    assertGt(fees, 0, 'Fees must be nonzero');
    assertEq(hub1.previewAddByAssets(daiAssetId, fees), 0, 'Shares must round to zero');

    bytes memory checkData = abi.encode(address(hub1), daiAssetId);
    (bool upkeepNeeded, bytes memory performData) = _minter.checkUpkeep(checkData);
    assertFalse(upkeepNeeded, 'checkUpkeep should be false when 0 shares minted');

    vm.expectRevert(IFeeSharesMinterBase.ConditionsNotMet.selector);
    _minter.performUpkeep(performData);
  }
}
