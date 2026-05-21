// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/setup/Base.t.sol';

contract FeeSharesMinterTest is Base {
  using SafeCast for uint256;
  using PercentageMath for uint256;

  FeeSharesMinter internal minter;

  function setUp() public override {
    super.setUp();
    minter = new FeeSharesMinter(ADMIN);

    vm.prank(ADMIN);
    accessManager.grantRole(Roles.HUB_FEE_MINTER_ROLE, address(minter), 0);
  }

  function test_setConfig_revertsWith_OwnableUnauthorized() public {
    vm.prank(bob);
    vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, bob));
    minter.setConfig(address(hub1), daiAssetId, 100);
  }

  function test_fuzz_setConfig(uint16 minAccruedFeesPercent) public {
    minAccruedFeesPercent = bound(minAccruedFeesPercent, 0, PercentageMath.PERCENTAGE_FACTOR)
      .toUint16();

    vm.expectEmit(address(minter));
    emit IFeeSharesMinter.ConfigUpdated(address(hub1), daiAssetId, minAccruedFeesPercent);

    vm.prank(ADMIN);
    minter.setConfig(address(hub1), daiAssetId, minAccruedFeesPercent);

    assertEq(minter.getConfig(address(hub1), daiAssetId), minAccruedFeesPercent);
  }

  function test_setConfig_independentPerPair() public {
    uint16 config1 = 100;
    uint16 config2 = 200;

    vm.startPrank(ADMIN);
    minter.setConfig(address(hub1), daiAssetId, config1);
    minter.setConfig(address(hub1), wethAssetId, config2);
    vm.stopPrank();

    assertEq(minter.getConfig(address(hub1), daiAssetId), config1, 'daiAssetId config');
    assertEq(minter.getConfig(address(hub1), wethAssetId), config2, 'wethAssetId config');
    assertEq(minter.getConfig(address(hub1), usdxAssetId), 0, 'usdxAssetId should be unset');
  }

  function test_setConfig_zeroDisables() public {
    _setupHappyPath(daiAssetId, 1);

    vm.prank(ADMIN);
    minter.setConfig(address(hub1), daiAssetId, 0);
    assertEq(minter.getConfig(address(hub1), daiAssetId), 0);

    _assertCheckUpkeepNotNeeded(address(hub1), daiAssetId);
  }

  function test_fuzz_setConfig_revertsWith_InvalidConfig(uint16 minAccruedFeesPercent) public {
    minAccruedFeesPercent = bound(
      minAccruedFeesPercent,
      PercentageMath.PERCENTAGE_FACTOR + 1,
      type(uint16).max
    ).toUint16();

    vm.prank(ADMIN);
    vm.expectRevert(
      abi.encodeWithSelector(IFeeSharesMinter.InvalidConfig.selector, minAccruedFeesPercent)
    );
    minter.setConfig(address(hub1), daiAssetId, minAccruedFeesPercent);
  }

  function test_setConfig_revertsWith_AssetNotListed() public {
    uint256 invalidAssetId = hub1.getAssetCount();
    vm.prank(ADMIN);
    vm.expectRevert(IHub.AssetNotListed.selector);
    minter.setConfig(address(hub1), invalidAssetId, 100);
  }

  function test_rescueToken() public {
    uint256 amount = 1000e18;

    MockERC20 token = new MockERC20();
    token.mint(address(minter), amount);

    assertEq(token.balanceOf(address(minter)), amount, 'Minter should have tokens');

    vm.prank(bob);
    vm.expectRevert(abi.encodeWithSelector(IRescuable.OnlyRescueGuardian.selector));
    minter.rescueToken(address(token), bob, amount);

    vm.prank(ADMIN);
    minter.rescueToken(address(token), ADMIN, amount);

    assertEq(token.balanceOf(address(minter)), 0, 'Minter should be empty');
    assertEq(token.balanceOf(ADMIN), amount, 'Admin should have tokens');
  }

  function test_transferOwnership_2Step() public {
    address newOwner = makeAddr('newOwner');

    vm.prank(ADMIN);
    minter.transferOwnership(newOwner);

    assertEq(minter.owner(), ADMIN, 'Owner should still be ADMIN');
    assertEq(minter.pendingOwner(), newOwner, 'Pending owner should be newOwner');

    vm.prank(newOwner);
    minter.acceptOwnership();

    assertEq(minter.owner(), newOwner, 'Owner should now be newOwner');
    assertEq(minter.pendingOwner(), address(0), 'Pending owner should be cleared');
  }

  function test_checkUpkeep_returnsCheckDataAsPerformData() public view {
    bytes memory checkData = abi.encode(address(hub1), daiAssetId);
    (, bytes memory performData) = minter.checkUpkeep(checkData);
    assertEq(performData, checkData);
  }

  function test_performUpkeep() public {
    _performAndAssertSuccess({
      addAmount: 1000e18,
      drawAmount: 900e18,
      skipTime: 365 days,
      minAccruedFeesPercent: 10
    });
  }

  function test_fuzz_performUpkeep_success(
    uint256 addAmount,
    uint256 drawAmount,
    uint256 skipTime,
    uint16 minAccruedFeesPercent
  ) public {
    addAmount = bound(addAmount, 100e18, 1e26);
    drawAmount = bound(drawAmount, addAmount / 2, (addAmount * 9) / 10);
    skipTime = bound(skipTime, 365 days, MAX_SKIP_TIME);
    minAccruedFeesPercent = bound(minAccruedFeesPercent, 1, 10).toUint16();

    _performAndAssertSuccess(addAmount, drawAmount, skipTime, minAccruedFeesPercent);
  }

  function test_checkUpkeep_returnsFalse_unconfiguredPair() public {
    _setupHappyPath(daiAssetId, 1);

    // wethAssetId was never configured
    assertEq(minter.getConfig(address(hub1), wethAssetId), 0);
    _assertCheckUpkeepNotNeeded(address(hub1), wethAssetId);
  }

  function test_performUpkeep_revertsWith_ConditionsNotMet_noFees() public {
    _setupHappyPath(daiAssetId, 1);

    // Single change: drain accrued fees via performUpkeep
    minter.performUpkeep(abi.encode(address(hub1), daiAssetId));
    assertEq(hub1.getAssetAccruedFees(daiAssetId), 0, 'Fees should be zero');

    _assertCheckUpkeepNotNeeded(address(hub1), daiAssetId);

    vm.expectRevert(IFeeSharesMinter.ConditionsNotMet.selector);
    minter.performUpkeep(abi.encode(address(hub1), daiAssetId));
  }

  function test_performUpkeep_revertsWith_ConditionsNotMet_noAddedAssets() public {
    _setupHappyPath(daiAssetId, 1);

    // Single change: configure a different asset that has no added liquidity
    vm.prank(ADMIN);
    minter.setConfig(address(hub1), wethAssetId, 1);
    assertEq(hub1.getAddedAssets(wethAssetId), 0, 'Total added assets should be zero');

    _assertCheckUpkeepNotNeeded(address(hub1), wethAssetId);

    vm.expectRevert(IFeeSharesMinter.ConditionsNotMet.selector);
    minter.performUpkeep(abi.encode(address(hub1), wethAssetId));
  }

  function test_performUpkeep_revertsWith_ConditionsNotMet_percentThresholdNotMet_withMinShares()
    public
  {
    _setupHappyPath(daiAssetId, 1);

    // Single change: raise threshold above the actual fees/totalAssets ratio
    uint16 highThreshold = 50_00;
    vm.prank(ADMIN);
    minter.setConfig(address(hub1), daiAssetId, highThreshold);

    uint256 fees = hub1.getAssetAccruedFees(daiAssetId);
    assertGt(hub1.previewAddByAssets(daiAssetId, fees), 0, 'At least 1 share would be minted');
    assertLt(
      fees,
      hub1.getAddedAssets(daiAssetId).percentMulDown(highThreshold),
      'Fees must be < threshold of total'
    );

    _assertCheckUpkeepNotNeeded(address(hub1), daiAssetId);

    vm.expectRevert(IFeeSharesMinter.ConditionsNotMet.selector);
    minter.performUpkeep(abi.encode(address(hub1), daiAssetId));
  }

  function test_fuzz_performUpkeep_revertsWith_ConditionsNotMet_thresholdAboveRatio(
    uint256 addAmount,
    uint256 drawAmount,
    uint256 skipTime,
    uint16 setupPercent,
    uint16 newThreshold
  ) public {
    addAmount = bound(addAmount, 100e18, 1e26);
    drawAmount = bound(drawAmount, addAmount / 2, (addAmount * 9) / 10);
    skipTime = bound(skipTime, 365 days, MAX_SKIP_TIME);
    setupPercent = bound(setupPercent, 1, 10).toUint16();

    _setupHappyPath(daiAssetId, setupPercent, addAmount, drawAmount, skipTime);

    uint256 currentRatio = hub1.getAssetAccruedFees(daiAssetId).percentDivDown(
      hub1.getAddedAssets(daiAssetId)
    );
    vm.assume(currentRatio < PercentageMath.PERCENTAGE_FACTOR);
    newThreshold = bound(newThreshold, currentRatio + 1, PercentageMath.PERCENTAGE_FACTOR)
      .toUint16();

    vm.prank(ADMIN);
    minter.setConfig(address(hub1), daiAssetId, newThreshold);

    _assertCheckUpkeepNotNeeded(address(hub1), daiAssetId);

    vm.expectRevert(IFeeSharesMinter.ConditionsNotMet.selector);
    minter.performUpkeep(abi.encode(address(hub1), daiAssetId));
  }

  function test_performUpkeep_revertsWith_ConditionsNotMet_MinShareNotMet_nonzeroFees() public {
    // Setup tiny amounts so a subsequent mint will inflate exchange rate
    vm.prank(ADMIN);
    minter.setConfig(address(hub1), daiAssetId, 1);
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
    _assertCheckUpkeepNeeded(address(hub1), daiAssetId);

    // Single change: mint to inflate exchange rate, then skip a short period so the
    // newly-accrued fees round to zero shares
    minter.performUpkeep(abi.encode(address(hub1), daiAssetId));
    skip(110 days);

    uint256 fees = hub1.getAssetAccruedFees(daiAssetId);
    assertGt(fees, 0, 'Fees must be nonzero');
    assertEq(hub1.previewAddByAssets(daiAssetId, fees), 0, 'Shares must round to zero');

    _assertCheckUpkeepNotNeeded(address(hub1), daiAssetId);

    vm.expectRevert(IFeeSharesMinter.ConditionsNotMet.selector);
    minter.performUpkeep(abi.encode(address(hub1), daiAssetId));
  }

  function _setupHappyPath(uint256 assetId, uint16 minAccruedFeesPercent) internal {
    _setupHappyPath(assetId, minAccruedFeesPercent, 1000e18, 900e18, 365 days);
  }

  function _setupHappyPath(
    uint256 assetId,
    uint16 minAccruedFeesPercent,
    uint256 addAmount,
    uint256 drawAmount,
    uint256 skipTime
  ) internal {
    vm.prank(ADMIN);
    minter.setConfig(address(hub1), assetId, minAccruedFeesPercent);
    _addAndDrawLiquidity({
      hub: hub1,
      assetId: assetId,
      addUser: bob,
      addSpoke: address(spoke1),
      addAmount: addAmount,
      drawUser: bob,
      drawSpoke: address(spoke1),
      drawAmount: drawAmount,
      skipTime: skipTime
    });
    _assertCheckUpkeepNeeded(address(hub1), assetId);
  }

  function _performAndAssertSuccess(
    uint256 addAmount,
    uint256 drawAmount,
    uint256 skipTime,
    uint16 minAccruedFeesPercent
  ) internal {
    _setupHappyPath(daiAssetId, minAccruedFeesPercent, addAmount, drawAmount, skipTime);

    address feeReceiver = _getFeeReceiver(hub1, daiAssetId);
    uint256 sharesBefore = hub1.getSpokeAddedShares(daiAssetId, feeReceiver);
    uint256 expectedMintedShares = hub1.previewAddByAssets(
      daiAssetId,
      hub1.getAssetAccruedFees(daiAssetId)
    );

    vm.expectCall(address(hub1), abi.encodeCall(IHub.mintFeeShares, (daiAssetId)));
    minter.performUpkeep(abi.encode(address(hub1), daiAssetId));

    uint256 sharesAfter = hub1.getSpokeAddedShares(daiAssetId, feeReceiver);
    assertEq(sharesAfter - sharesBefore, expectedMintedShares, 'fee shares minted to receiver');
    _assertCheckUpkeepNotNeeded(address(hub1), daiAssetId);
  }

  function _assertCheckUpkeepNeeded(address hub, uint256 assetId) internal view {
    (bool upkeepNeeded, ) = minter.checkUpkeep(abi.encode(hub, assetId));
    assertTrue(upkeepNeeded, 'checkUpkeep should be true');
  }

  function _assertCheckUpkeepNotNeeded(address hub, uint256 assetId) internal view {
    (bool upkeepNeeded, ) = minter.checkUpkeep(abi.encode(hub, assetId));
    assertFalse(upkeepNeeded, 'checkUpkeep should be false');
  }
}
