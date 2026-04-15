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

    vm.prank(ADMIN);
    accessManager.grantRole(Roles.HUB_FEE_MINTER_ROLE, address(_minter), 0);
  }

  function test_setConfig_revertsWith_OwnableUnauthorized() public {
    vm.prank(bob);
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, bob));
    _minter.setConfig(address(hub1), daiAssetId, 100);
  }

  function test_fuzz_setConfig(uint16 minAccruedFeesPercent) public {
    minAccruedFeesPercent = bound(minAccruedFeesPercent, 0, PercentageMath.PERCENTAGE_FACTOR)
      .toUint16();

    vm.expectEmit(address(_minter));
    emit IFeeSharesMinterBase.ConfigUpdated(address(hub1), daiAssetId, minAccruedFeesPercent);

    vm.prank(ADMIN);
    _minter.setConfig(address(hub1), daiAssetId, minAccruedFeesPercent);

    assertEq(_minter.getConfig(address(hub1), daiAssetId), minAccruedFeesPercent);
  }

  function test_setConfig_independentPerPair() public {
    uint16 config1 = 100;
    uint16 config2 = 200;

    vm.startPrank(ADMIN);
    _minter.setConfig(address(hub1), daiAssetId, config1);
    _minter.setConfig(address(hub1), wethAssetId, config2);
    vm.stopPrank();

    assertEq(_minter.getConfig(address(hub1), daiAssetId), config1, 'daiAssetId config');
    assertEq(_minter.getConfig(address(hub1), wethAssetId), config2, 'wethAssetId config');
    assertEq(_minter.getConfig(address(hub1), usdxAssetId), 0, 'usdxAssetId should be unset');
  }

  function test_fuzz_setConfig_revertsWith_InvalidConfig(uint16 minAccruedFeesPercent) public {
    minAccruedFeesPercent = bound(
      minAccruedFeesPercent,
      PercentageMath.PERCENTAGE_FACTOR + 1,
      type(uint16).max
    ).toUint16();

    vm.prank(ADMIN);
    vm.expectRevert(IFeeSharesMinterBase.InvalidConfig.selector);
    _minter.setConfig(address(hub1), daiAssetId, minAccruedFeesPercent);
  }

  function test_rescueToken() public {
    uint256 amount = 1000e18;

    MockERC20 token = new MockERC20();
    token.mint(address(_minter), amount);

    assertEq(token.balanceOf(address(_minter)), amount, 'Minter should have tokens');

    vm.prank(bob);
    vm.expectRevert(abi.encodeWithSelector(IRescuable.OnlyRescueGuardian.selector));
    _minter.rescueToken(address(token), bob, amount);

    vm.prank(ADMIN);
    _minter.rescueToken(address(token), ADMIN, amount);

    assertEq(token.balanceOf(address(_minter)), 0, 'Minter should be empty');
    assertEq(token.balanceOf(ADMIN), amount, 'Admin should have tokens');
  }

  function test_transferOwnership_2Step() public {
    address newOwner = makeAddr('newOwner');

    vm.prank(ADMIN);
    _minter.transferOwnership(newOwner);

    assertEq(_minter.owner(), ADMIN, 'Owner should still be ADMIN');
    assertEq(_minter.pendingOwner(), newOwner, 'Pending owner should be newOwner');

    vm.prank(newOwner);
    _minter.acceptOwnership();

    assertEq(_minter.owner(), newOwner, 'Owner should now be newOwner');
    assertEq(_minter.pendingOwner(), address(0), 'Pending owner should be cleared');
  }

  function test_performUpkeep() public {
    test_fuzz_performUpkeep({
      addAmount: 1000e18,
      drawAmount: 900e18,
      skipTime: 365 days,
      minAccruedFeesPercent: 10
    });
  }

  function test_fuzz_performUpkeep(
    uint256 addAmount,
    uint256 drawAmount,
    uint256 skipTime,
    uint16 minAccruedFeesPercent
  ) public {
    addAmount = bound(addAmount, 2, MAX_SUPPLY_AMOUNT);
    drawAmount = bound(drawAmount, 1, addAmount / 2);
    skipTime = bound(skipTime, 1, MAX_SKIP_TIME);
    minAccruedFeesPercent = bound(minAccruedFeesPercent, 0, PercentageMath.PERCENTAGE_FACTOR)
      .toUint16();

    vm.prank(ADMIN);
    _minter.setConfig(address(hub1), daiAssetId, minAccruedFeesPercent);

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
    assertEq(performData, checkData, 'performData should equal checkData');

    if (upkeepNeeded) {
      _minter.performUpkeep(performData);

      (bool upkeepNeededAfter, ) = _minter.checkUpkeep(checkData);
      assertFalse(upkeepNeededAfter, 'checkUpkeep should return false after performUpkeep');
    } else {
      vm.expectRevert(IFeeSharesMinterBase.ConditionsNotMet.selector);
      _minter.performUpkeep(performData);
    }
  }

  function test_performUpkeep_revertsWith_ConditionsNotMet_noFees() public {
    vm.prank(ADMIN);
    _minter.setConfig(address(hub1), daiAssetId, 0);

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

  function test_performUpkeep_revertsWith_ConditionsNotMet_noAddedAssets() public {
    vm.prank(ADMIN);
    _minter.setConfig(address(hub1), daiAssetId, 0);

    assertEq(hub1.getAddedAssets(daiAssetId), 0, 'Total added assets should be zero');

    bytes memory checkData = abi.encode(address(hub1), daiAssetId);
    (bool upkeepNeeded, bytes memory performData) = _minter.checkUpkeep(checkData);
    assertFalse(upkeepNeeded, 'checkUpkeep should return false when totalAddedAssets is zero');

    vm.expectRevert(IFeeSharesMinterBase.ConditionsNotMet.selector);
    _minter.performUpkeep(performData);
  }

  function test_performUpkeep_revertsWith_ConditionsNotMet_percentThresholdNotMet_withMinShares()
    public
  {
    uint16 threshold = 50_00;
    vm.prank(ADMIN);
    _minter.setConfig(address(hub1), daiAssetId, threshold);

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
      totalAssets.percentMulDown(threshold),
      'Fees must be < minAccruedFeesPercent of total'
    );

    bytes memory checkData = abi.encode(address(hub1), daiAssetId);
    (bool upkeepNeeded, bytes memory performData) = _minter.checkUpkeep(checkData);
    assertFalse(upkeepNeeded, 'checkUpkeep should be false: ratio below threshold');

    vm.expectRevert(IFeeSharesMinterBase.ConditionsNotMet.selector);
    _minter.performUpkeep(performData);
  }

  function test_performUpkeep_revertsWith_ConditionsNotMet_MinShareNotMet_nonzeroFees() public {
    vm.prank(ADMIN);
    _minter.setConfig(address(hub1), daiAssetId, 0);

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

    _minter.performUpkeep(abi.encode(address(hub1), daiAssetId));

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
