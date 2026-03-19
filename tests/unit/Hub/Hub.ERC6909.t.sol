// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/Hub/HubBase.t.sol';
import {IERC6909} from 'src/dependencies/openzeppelin/IERC6909.sol';

contract HubERC6909Test is HubBase {
  using SharesMath for uint256;
  using SafeCast for uint256;

  function test_balanceOf_returns_addedShares() public {
    uint256 supplyAmount = 1000e18;
    Utils.add(hub1, daiAssetId, address(spoke1), supplyAmount, bob);

    uint256 expectedBalance = hub1.getSpokeAddedShares(daiAssetId, address(spoke1));
    uint256 balance = hub1.balanceOf(address(spoke1), daiAssetId);

    assertEq(balance, expectedBalance);
    assertGt(balance, 0);
  }

  function test_balanceOf_returns_zero_for_no_balance() public view {
    uint256 balance = hub1.balanceOf(address(spoke1), daiAssetId);
    assertEq(balance, 0);
  }

  function test_balanceOf_fuzz(uint256 supplyAmount) public {
    supplyAmount = bound(supplyAmount, 1, MAX_SUPPLY_AMOUNT);
    Utils.add(hub1, daiAssetId, address(spoke1), supplyAmount, bob);

    uint256 expectedBalance = hub1.getSpokeAddedShares(daiAssetId, address(spoke1));
    uint256 balance = hub1.balanceOf(address(spoke1), daiAssetId);

    assertEq(balance, expectedBalance);
  }

  function test_approve_returns_false() public {
    vm.prank(address(spoke1));
    bool success = hub1.approve(address(spoke2), daiAssetId, 100e18);
    assertFalse(success);
  }

  function test_allowance_always_returns_zero() public view {
    assertEq(hub1.allowance(address(spoke1), address(spoke2), daiAssetId), 0);
  }

  function test_setOperator_approves_operator() public {
    vm.prank(address(spoke1));
    bool success = hub1.setOperator(address(spoke2), true);

    assertTrue(success);
    assertTrue(hub1.isOperator(address(spoke1), address(spoke2)));
  }

  function test_setOperator_revokes_operator() public {
    vm.prank(address(spoke1));
    hub1.setOperator(address(spoke2), true);
    assertTrue(hub1.isOperator(address(spoke1), address(spoke2)));

    vm.prank(address(spoke1));
    hub1.setOperator(address(spoke2), false);
    assertFalse(hub1.isOperator(address(spoke1), address(spoke2)));
  }

  function test_setOperator_emits_OperatorSet_event() public {
    vm.expectEmit(address(hub1));
    emit IERC6909.OperatorSet(address(spoke1), address(spoke2), true);

    vm.prank(address(spoke1));
    hub1.setOperator(address(spoke2), true);
  }

  function test_setOperator_revertsWith_InvalidAddress_when_setting_self() public {
    vm.prank(address(spoke1));
    vm.expectRevert(IHub.InvalidAddress.selector);
    hub1.setOperator(address(spoke1), true);
  }

  function test_transfer() public {
    uint256 supplyAmount = 1000e18;
    uint256 transferAmount = 500e18;

    Utils.add(hub1, daiAssetId, address(spoke1), supplyAmount, bob);

    uint256 balanceBefore = hub1.balanceOf(address(spoke1), daiAssetId);
    assertGt(balanceBefore, 0);

    vm.expectEmit(address(hub1));
    emit IERC6909.Transfer(address(spoke1), address(spoke1), address(spoke2), daiAssetId, transferAmount);

    vm.prank(address(spoke1));
    bool success = hub1.transfer(address(spoke2), daiAssetId, transferAmount);

    assertTrue(success);
    assertEq(hub1.balanceOf(address(spoke1), daiAssetId), balanceBefore - transferAmount);
    assertEq(hub1.balanceOf(address(spoke2), daiAssetId), transferAmount);
  }

  function test_transfer_fuzz(uint256 supplyAmount, uint256 transferAmount) public {
    supplyAmount = bound(supplyAmount, 1, MAX_SUPPLY_AMOUNT);
    transferAmount = bound(transferAmount, 1, supplyAmount);

    Utils.add(hub1, daiAssetId, address(spoke1), supplyAmount, bob);

    uint256 balanceBefore = hub1.balanceOf(address(spoke1), daiAssetId);

    vm.prank(address(spoke1));
    hub1.transfer(address(spoke2), daiAssetId, transferAmount);

    assertEq(hub1.balanceOf(address(spoke1), daiAssetId), balanceBefore - transferAmount);
    assertEq(hub1.balanceOf(address(spoke2), daiAssetId), transferAmount);
  }

  function test_transfer_revertsWith_InvalidShares_on_zero() public {
    vm.prank(address(spoke1));
    vm.expectRevert(IHub.InvalidShares.selector);
    hub1.transfer(address(spoke2), daiAssetId, 0);
  }

  function test_transfer_revertsWith_InvalidAddress_on_zero_address() public {
    vm.prank(address(spoke1));
    vm.expectRevert(IHub.InvalidAddress.selector);
    hub1.transfer(address(0), daiAssetId, 100);
  }

  function test_transfer_revertsWith_SpokeNotActive_sender() public {
    uint256 supplyAmount = 1000e18;
    Utils.add(hub1, daiAssetId, address(spoke1), supplyAmount, bob);

    _updateSpokeActive(hub1, daiAssetId, address(spoke1), false);

    vm.prank(address(spoke1));
    vm.expectRevert(IHub.SpokeNotActive.selector);
    hub1.transfer(address(spoke2), daiAssetId, 100e18);
  }

  function test_transfer_revertsWith_SpokePaused_sender() public {
    uint256 supplyAmount = 1000e18;
    Utils.add(hub1, daiAssetId, address(spoke1), supplyAmount, bob);

    _updateSpokePaused(hub1, daiAssetId, address(spoke1), true);

    vm.prank(address(spoke1));
    vm.expectRevert(IHub.SpokePaused.selector);
    hub1.transfer(address(spoke2), daiAssetId, 100e18);
  }

  function test_transfer_revertsWith_AddCapExceeded_receiver() public {
    uint40 newAddCap = 500;
    uint256 supplyAmount = 1000e18;

    Utils.add(hub1, daiAssetId, address(spoke1), supplyAmount, bob);

    _updateAddCap(daiAssetId, address(spoke2), newAddCap);

    uint256 transferAmount = (newAddCap * 10 ** tokenList.dai.decimals()) + 1;

    vm.prank(address(spoke1));
    vm.expectRevert(abi.encodeWithSelector(IHub.AddCapExceeded.selector, newAddCap));
    hub1.transfer(address(spoke2), daiAssetId, transferAmount);
  }

  function test_transfer_revertsWith_underflow_when_insufficient_balance() public {
    uint256 supplyAmount = 1000e18;
    Utils.add(hub1, daiAssetId, address(spoke1), supplyAmount, bob);

    uint256 balance = hub1.balanceOf(address(spoke1), daiAssetId);

    vm.prank(address(spoke1));
    vm.expectRevert(stdError.arithmeticError);
    hub1.transfer(address(spoke2), daiAssetId, balance + 1);
  }

  function test_transferFrom_with_operator() public {
    uint256 supplyAmount = 1000e18;
    uint256 transferAmount = 500e18;

    Utils.add(hub1, daiAssetId, address(spoke1), supplyAmount, bob);

    vm.prank(address(spoke1));
    hub1.setOperator(address(spoke2), true);

    uint256 balanceBefore = hub1.balanceOf(address(spoke1), daiAssetId);
    address recipient = vm.randomAddress();

    vm.prank(ADMIN);
    hub1.addSpoke(
      daiAssetId,
      recipient,
      IHub.SpokeConfig({
        addCap: Constants.MAX_ALLOWED_SPOKE_CAP,
        drawCap: Constants.MAX_ALLOWED_SPOKE_CAP,
        riskPremiumThreshold: Constants.MAX_ALLOWED_COLLATERAL_RISK,
        active: true,
        paused: false
      })
    );

    vm.prank(address(spoke2));
    bool success = hub1.transferFrom(address(spoke1), recipient, daiAssetId, transferAmount);

    assertTrue(success);
    assertEq(hub1.balanceOf(address(spoke1), daiAssetId), balanceBefore - transferAmount);
    assertEq(hub1.balanceOf(recipient, daiAssetId), transferAmount);
  }

  function test_transferFrom_revertsWith_InsufficientAllowance_without_operator() public {
    uint256 supplyAmount = 1000e18;
    uint256 transferAmount = 500e18;

    Utils.add(hub1, daiAssetId, address(spoke1), supplyAmount, bob);

    vm.prank(address(spoke2));
    vm.expectRevert(IHub.InsufficientAllowance.selector);
    hub1.transferFrom(address(spoke1), address(spoke2), daiAssetId, transferAmount);
  }

  function test_transferFrom_owner_can_transfer_without_approval() public {
    uint256 supplyAmount = 1000e18;
    uint256 transferAmount = 500e18;

    Utils.add(hub1, daiAssetId, address(spoke1), supplyAmount, bob);

    vm.prank(address(spoke1));
    bool success = hub1.transferFrom(address(spoke1), address(spoke2), daiAssetId, transferAmount);

    assertTrue(success);
    assertEq(hub1.balanceOf(address(spoke2), daiAssetId), transferAmount);
  }

  function test_transferFrom_revertsWith_InvalidShares_on_zero() public {
    vm.prank(address(spoke1));
    vm.expectRevert(IHub.InvalidShares.selector);
    hub1.transferFrom(address(spoke1), address(spoke2), daiAssetId, 0);
  }

  function test_transferFrom_revertsWith_InvalidAddress_on_zero_address() public {
    vm.prank(address(spoke1));
    vm.expectRevert(IHub.InvalidAddress.selector);
    hub1.transferFrom(address(spoke1), address(0), daiAssetId, 100);
  }

  function test_transferFrom_revertsWith_AssetNotListed() public {
    uint256 invalidAssetId = 999;
    vm.prank(address(spoke1));
    vm.expectRevert(IHub.AssetNotListed.selector);
    hub1.transferFrom(address(spoke1), address(spoke2), invalidAssetId, 100);
  }

  function test_transferFrom_revertsWith_SpokeNotActive_sender() public {
    uint256 supplyAmount = 1000e18;
    Utils.add(hub1, daiAssetId, address(spoke1), supplyAmount, bob);

    vm.prank(address(spoke1));
    hub1.setOperator(address(spoke2), true);

    _updateSpokeActive(hub1, daiAssetId, address(spoke1), false);

    vm.prank(address(spoke2));
    vm.expectRevert(IHub.SpokeNotActive.selector);
    hub1.transferFrom(address(spoke1), address(spoke2), daiAssetId, 100e18);
  }

  function test_transferFrom_revertsWith_SpokePaused_sender() public {
    uint256 supplyAmount = 1000e18;
    Utils.add(hub1, daiAssetId, address(spoke1), supplyAmount, bob);

    vm.prank(address(spoke1));
    hub1.setOperator(address(spoke2), true);

    _updateSpokePaused(hub1, daiAssetId, address(spoke1), true);

    vm.prank(address(spoke2));
    vm.expectRevert(IHub.SpokePaused.selector);
    hub1.transferFrom(address(spoke1), address(spoke2), daiAssetId, 100e18);
  }

  function test_transferFrom_revertsWith_AddCapExceeded_receiver() public {
    uint40 newAddCap = 500;
    uint256 supplyAmount = 1000e18;

    Utils.add(hub1, daiAssetId, address(spoke1), supplyAmount, bob);

    vm.prank(address(spoke1));
    hub1.setOperator(address(spoke2), true);

    _updateAddCap(daiAssetId, address(spoke2), newAddCap);

    uint256 transferAmount = (newAddCap * 10 ** tokenList.dai.decimals()) + 1;

    vm.prank(address(spoke2));
    vm.expectRevert(abi.encodeWithSelector(IHub.AddCapExceeded.selector, newAddCap));
    hub1.transferFrom(address(spoke1), address(spoke2), daiAssetId, transferAmount);
  }

  function test_supportsInterface_ERC6909() public view {
    bytes4 erc6909InterfaceId = 0x0f632fb3;
    assertTrue(hub1.supportsInterface(erc6909InterfaceId));
  }

  function test_supportsInterface_ERC165() public view {
    bytes4 erc165InterfaceId = 0x01ffc9a7;
    assertTrue(hub1.supportsInterface(erc165InterfaceId));
  }

  function test_supportsInterface_invalid_interface() public view {
    bytes4 invalidInterfaceId = 0xffffffff;
    assertFalse(hub1.supportsInterface(invalidInterfaceId));
  }

  function test_integration_transfer_and_transferFrom() public {
    uint256 supplyAmount = 1000e18;
    Utils.add(hub1, daiAssetId, address(spoke1), supplyAmount, bob);

    vm.prank(address(spoke1));
    hub1.transfer(address(spoke2), daiAssetId, 300e18);

    assertEq(hub1.balanceOf(address(spoke1), daiAssetId), 700e18);
    assertEq(hub1.balanceOf(address(spoke2), daiAssetId), 300e18);

    vm.prank(address(spoke2));
    hub1.setOperator(address(spoke1), true);

    vm.prank(address(spoke1));
    hub1.transferFrom(address(spoke2), address(spoke1), daiAssetId, 100e18);

    assertEq(hub1.balanceOf(address(spoke1), daiAssetId), 800e18);
    assertEq(hub1.balanceOf(address(spoke2), daiAssetId), 200e18);
  }

  function test_integration_transferShares_uses_same_logic() public {
    uint256 supplyAmount = 1000e18;
    uint256 transferAmount = 500e18;

    Utils.add(hub1, daiAssetId, address(spoke1), supplyAmount, bob);

    uint256 balanceBefore = hub1.balanceOf(address(spoke1), daiAssetId);

    vm.expectEmit(address(hub1));
    emit IHubBase.TransferShares(daiAssetId, address(spoke1), address(spoke2), transferAmount);

    vm.prank(address(spoke1));
    hub1.transferShares(daiAssetId, transferAmount, address(spoke2));

    assertEq(hub1.balanceOf(address(spoke1), daiAssetId), balanceBefore - transferAmount);
    assertEq(hub1.balanceOf(address(spoke2), daiAssetId), transferAmount);
  }

  function test_integration_multiple_assets() public {
    uint256 daiSupply = 1000e18;
    uint256 wethSupply = 10e18;

    Utils.add(hub1, daiAssetId, address(spoke1), daiSupply, bob);
    Utils.add(hub1, wethAssetId, address(spoke1), wethSupply, bob);

    assertEq(hub1.balanceOf(address(spoke1), daiAssetId), daiSupply);
    assertEq(hub1.balanceOf(address(spoke1), wethAssetId), wethSupply);

    vm.prank(address(spoke1));
    hub1.transfer(address(spoke2), daiAssetId, 500e18);

    vm.prank(address(spoke1));
    hub1.transfer(address(spoke2), wethAssetId, 5e18);

    assertEq(hub1.balanceOf(address(spoke1), daiAssetId), 500e18);
    assertEq(hub1.balanceOf(address(spoke2), daiAssetId), 500e18);
    assertEq(hub1.balanceOf(address(spoke1), wethAssetId), 5e18);
    assertEq(hub1.balanceOf(address(spoke2), wethAssetId), 5e18);
  }

  function test_integration_operator_approval() public {
    uint256 supplyAmount = 1000e18;
    Utils.add(hub1, daiAssetId, address(spoke1), supplyAmount, bob);

    address operator = vm.randomAddress();

    vm.prank(ADMIN);
    hub1.addSpoke(
      daiAssetId,
      operator,
      IHub.SpokeConfig({
        addCap: Constants.MAX_ALLOWED_SPOKE_CAP,
        drawCap: Constants.MAX_ALLOWED_SPOKE_CAP,
        riskPremiumThreshold: Constants.MAX_ALLOWED_COLLATERAL_RISK,
        active: true,
        paused: false
      })
    );

    vm.prank(address(spoke1));
    hub1.setOperator(operator, true);

    vm.prank(operator);
    hub1.transferFrom(address(spoke1), operator, daiAssetId, 300e18);

    assertEq(hub1.balanceOf(operator, daiAssetId), 300e18);

    vm.prank(address(spoke1));
    hub1.setOperator(operator, false);

    vm.prank(operator);
    vm.expectRevert(IHub.InsufficientAllowance.selector);
    hub1.transferFrom(address(spoke1), operator, daiAssetId, 100e18);
  }
}
