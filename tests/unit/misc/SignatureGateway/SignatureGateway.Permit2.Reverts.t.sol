// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/misc/SignatureGateway/SignatureGateway.Permit2.Base.t.sol';
import {IGatewayBase} from 'src/position-manager/interfaces/IGatewayBase.sol';

contract SignatureGatewayPermit2RevertsTest is SignatureGatewayPermit2BaseTest {
  error InvalidSigner();
  error SignatureExpired(uint256 signatureDeadline);

  function test_supplyWithPermit2_revertsWith_InvalidSigner() public {
    (
      ISignatureTransfer.PermitTransferFrom memory permit,
      ISignatureGateway.Supply memory p
    ) = _permit2SupplyData(spoke1, alice, _warpBeforeRandomDeadline());

    (, uint256 bobPk) = makeAddrAndKey('bob');
    bytes memory signature = _getPermit2SupplySignature(permit, p, bobPk);

    _approvePermit2(spoke1, p.reserveId, alice);
    deal(permit.permitted.token, alice, p.amount);

    vm.expectRevert(InvalidSigner.selector);
    vm.prank(vm.randomAddress());
    gateway.supplyWithPermit2(permit, p, signature);
  }

  function test_supplyWithPermit2_revertsWith_SignatureExpired() public {
    (
      ISignatureTransfer.PermitTransferFrom memory permit,
      ISignatureGateway.Supply memory p
    ) = _permit2SupplyData(spoke1, alice, _warpAfterRandomDeadline());

    bytes memory signature = _getPermit2SupplySignature(permit, p, alicePk);

    _approvePermit2(spoke1, p.reserveId, alice);
    deal(permit.permitted.token, alice, p.amount);

    vm.expectRevert(abi.encodeWithSelector(SignatureExpired.selector, permit.deadline));
    vm.prank(vm.randomAddress());
    gateway.supplyWithPermit2(permit, p, signature);
  }

  function test_supplyWithPermit2_revertsWith_SpokeNotRegistered() public {
    address unregisteredSpoke = vm.randomAddress();

    ISignatureTransfer.PermitTransferFrom memory permit = ISignatureTransfer.PermitTransferFrom({
      permitted: ISignatureTransfer.TokenPermissions({token: address(0), amount: 1e18}),
      nonce: vm.randomUint(),
      deadline: _warpBeforeRandomDeadline()
    });

    ISignatureGateway.Supply memory p = ISignatureGateway.Supply({
      spoke: unregisteredSpoke,
      reserveId: 0,
      amount: 1e18,
      onBehalfOf: alice,
      nonce: permit.nonce,
      deadline: permit.deadline
    });

    bytes memory signature = _getPermit2SupplySignature(permit, p, alicePk);

    vm.expectRevert(abi.encodeWithSelector(IGatewayBase.SpokeNotRegistered.selector, unregisteredSpoke));
    vm.prank(vm.randomAddress());
    gateway.supplyWithPermit2(permit, p, signature);
  }

  function test_repayWithPermit2_revertsWith_InvalidSigner() public {
    uint256 deadline = _warpBeforeRandomDeadline();
    uint256 reserveId = _daiReserveId(spoke1);
    uint256 borrowAmount = 1e18;

    Utils.supplyCollateral(spoke1, reserveId, alice, borrowAmount * 2, alice);
    Utils.borrow(spoke1, reserveId, alice, borrowAmount, alice);

    ISignatureTransfer.PermitTransferFrom memory permit = ISignatureTransfer.PermitTransferFrom({
      permitted: ISignatureTransfer.TokenPermissions({
        token: address(_underlying(spoke1, reserveId)),
        amount: borrowAmount
      }),
      nonce: vm.randomUint(),
      deadline: deadline
    });

    ISignatureGateway.Repay memory p = ISignatureGateway.Repay({
      spoke: address(spoke1),
      reserveId: reserveId,
      amount: borrowAmount,
      onBehalfOf: alice,
      nonce: permit.nonce,
      deadline: deadline
    });

    (, uint256 bobPk) = makeAddrAndKey('bob');
    bytes memory signature = _getPermit2RepaySignature(permit, p, bobPk);

    _approvePermit2(spoke1, p.reserveId, alice);

    vm.expectRevert(InvalidSigner.selector);
    vm.prank(vm.randomAddress());
    gateway.repayWithPermit2(permit, p, signature);
  }

  function test_repayWithPermit2_revertsWith_SignatureExpired() public {
    uint256 deadline = _warpAfterRandomDeadline();
    uint256 reserveId = _daiReserveId(spoke1);
    uint256 borrowAmount = 1e18;

    Utils.supplyCollateral(spoke1, reserveId, alice, borrowAmount * 2, alice);
    Utils.borrow(spoke1, reserveId, alice, borrowAmount, alice);

    ISignatureTransfer.PermitTransferFrom memory permit = ISignatureTransfer.PermitTransferFrom({
      permitted: ISignatureTransfer.TokenPermissions({
        token: address(_underlying(spoke1, reserveId)),
        amount: borrowAmount
      }),
      nonce: vm.randomUint(),
      deadline: deadline
    });

    ISignatureGateway.Repay memory p = ISignatureGateway.Repay({
      spoke: address(spoke1),
      reserveId: reserveId,
      amount: borrowAmount,
      onBehalfOf: alice,
      nonce: permit.nonce,
      deadline: deadline
    });

    bytes memory signature = _getPermit2RepaySignature(permit, p, alicePk);

    _approvePermit2(spoke1, p.reserveId, alice);

    vm.expectRevert(abi.encodeWithSelector(SignatureExpired.selector, permit.deadline));
    vm.prank(vm.randomAddress());
    gateway.repayWithPermit2(permit, p, signature);
  }

  function test_repayWithPermit2_revertsWith_SpokeNotRegistered() public {
    address unregisteredSpoke = vm.randomAddress();

    ISignatureTransfer.PermitTransferFrom memory permit = ISignatureTransfer.PermitTransferFrom({
      permitted: ISignatureTransfer.TokenPermissions({token: address(0), amount: 1e18}),
      nonce: vm.randomUint(),
      deadline: _warpBeforeRandomDeadline()
    });

    ISignatureGateway.Repay memory p = ISignatureGateway.Repay({
      spoke: unregisteredSpoke,
      reserveId: 0,
      amount: 1e18,
      onBehalfOf: alice,
      nonce: permit.nonce,
      deadline: permit.deadline
    });

    bytes memory signature = _getPermit2RepaySignature(permit, p, alicePk);

    vm.expectRevert(abi.encodeWithSelector(IGatewayBase.SpokeNotRegistered.selector, unregisteredSpoke));
    vm.prank(vm.randomAddress());
    gateway.repayWithPermit2(permit, p, signature);
  }
}
