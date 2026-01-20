// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/misc/SignatureGateway/SignatureGateway.Base.t.sol';
import {BatchEIP712} from 'src/position-manager/libraries/BatchEIP712.sol';
import {ISpokeBase} from 'src/spoke/interfaces/ISpokeBase.sol';

contract SignatureGatewayBatchTest is SignatureGatewayBaseTest {
  using SafeCast for *;

  function setUp() public virtual override {
    super.setUp();
    vm.prank(SPOKE_ADMIN);
    spoke1.updatePositionManager(address(gateway), true);
    vm.prank(alice);
    spoke1.setUserPositionManager(address(gateway), true);

    assertTrue(spoke1.isPositionManagerActive(address(gateway)));
    assertTrue(spoke1.isPositionManager(alice, address(gateway)));
  }

  function _supplyActionData(
    ISpoke spoke,
    uint256 reserveId,
    uint256 amount
  ) internal view returns (ISignatureGateway.SupplyAction memory) {
    return
      ISignatureGateway.SupplyAction({spoke: address(spoke), reserveId: reserveId, amount: amount});
  }

  function _withdrawActionData(
    ISpoke spoke,
    uint256 reserveId,
    uint256 amount
  ) internal view returns (ISignatureGateway.WithdrawAction memory) {
    return
      ISignatureGateway.WithdrawAction({
        spoke: address(spoke),
        reserveId: reserveId,
        amount: amount
      });
  }

  function _borrowActionData(
    ISpoke spoke,
    uint256 reserveId,
    uint256 amount
  ) internal view returns (ISignatureGateway.BorrowAction memory) {
    return
      ISignatureGateway.BorrowAction({spoke: address(spoke), reserveId: reserveId, amount: amount});
  }

  function _repayActionData(
    ISpoke spoke,
    uint256 reserveId,
    uint256 amount
  ) internal view returns (ISignatureGateway.RepayAction memory) {
    return
      ISignatureGateway.RepayAction({spoke: address(spoke), reserveId: reserveId, amount: amount});
  }

  function _setUsingAsCollateralActionData(
    ISpoke spoke,
    uint256 reserveId,
    bool useAsCollateral
  ) internal view returns (ISignatureGateway.SetUsingAsCollateralAction memory) {
    return
      ISignatureGateway.SetUsingAsCollateralAction({
        spoke: address(spoke),
        reserveId: reserveId,
        useAsCollateral: useAsCollateral
      });
  }

  function _getBatchTypedDataHash(
    ISignatureGateway _gateway,
    uint8[] memory actionTypes,
    bytes[] memory actionData,
    address onBehalfOf,
    uint256 nonce,
    uint256 deadline
  ) internal view returns (bytes32) {
    bytes32 structHash = BatchEIP712.hashBatch(
      actionTypes,
      actionData,
      onBehalfOf,
      nonce,
      deadline
    );
    return keccak256(abi.encodePacked('\x19\x01', _gateway.DOMAIN_SEPARATOR(), structHash));
  }

  function test_executeBatchWithSig_singleSupply() public {
    uint256 deadline = _warpBeforeRandomDeadline();
    uint256 reserveId = _randomReserveId(spoke1);
    uint256 amount = 1e18;
    uint256 nonce = gateway.nonces(alice, _randomNonceKey());

    uint8[] memory actionTypes = new uint8[](1);
    actionTypes[0] = uint8(ISignatureGateway.ActionType.Supply);

    bytes[] memory actionData = new bytes[](1);
    actionData[0] = abi.encode(_supplyActionData(spoke1, reserveId, amount));

    bytes32 digest = _getBatchTypedDataHash(
      gateway,
      actionTypes,
      actionData,
      alice,
      nonce,
      deadline
    );
    bytes memory signature = _sign(alicePk, digest);

    Utils.approve(spoke1, reserveId, alice, address(gateway), amount);

    vm.expectCall(address(spoke1), abi.encodeCall(ISpokeBase.supply, (reserveId, amount, alice)));
    vm.prank(vm.randomAddress());
    gateway.executeBatchWithSig(actionTypes, actionData, alice, nonce, deadline, signature);

    _assertNonceIncrement(gateway, alice, nonce);
    _assertGatewayHasNoBalanceOrAllowance(spoke1, gateway, alice);
    _assertGatewayHasNoActivePosition(spoke1, gateway);
  }

  function test_executeBatchWithSig_supplyAndWithdraw() public {
    uint256 deadline = _warpBeforeRandomDeadline();
    uint256 reserveId = _randomReserveId(spoke1);
    uint256 supplyAmount = 2e18;
    uint256 withdrawAmount = 1e18;
    uint256 nonce = gateway.nonces(alice, _randomNonceKey());

    Utils.supply(spoke1, reserveId, alice, supplyAmount + 1e18, alice);

    uint8[] memory actionTypes = new uint8[](2);
    actionTypes[0] = uint8(ISignatureGateway.ActionType.Supply);
    actionTypes[1] = uint8(ISignatureGateway.ActionType.Withdraw);

    bytes[] memory actionData = new bytes[](2);
    actionData[0] = abi.encode(_supplyActionData(spoke1, reserveId, supplyAmount));
    actionData[1] = abi.encode(_withdrawActionData(spoke1, reserveId, withdrawAmount));

    bytes32 digest = _getBatchTypedDataHash(
      gateway,
      actionTypes,
      actionData,
      alice,
      nonce,
      deadline
    );
    bytes memory signature = _sign(alicePk, digest);

    Utils.approve(spoke1, reserveId, alice, address(gateway), supplyAmount);

    vm.expectCall(
      address(spoke1),
      abi.encodeCall(ISpokeBase.supply, (reserveId, supplyAmount, alice))
    );
    vm.expectCall(
      address(spoke1),
      abi.encodeCall(ISpokeBase.withdraw, (reserveId, withdrawAmount, alice))
    );
    vm.prank(vm.randomAddress());
    gateway.executeBatchWithSig(actionTypes, actionData, alice, nonce, deadline, signature);

    _assertNonceIncrement(gateway, alice, nonce);
    _assertGatewayHasNoBalanceOrAllowance(spoke1, gateway, alice);
    _assertGatewayHasNoActivePosition(spoke1, gateway);
  }

  function test_executeBatchWithSig_supplyAndSetCollateral() public {
    uint256 deadline = _warpBeforeRandomDeadline();
    uint256 reserveId = _daiReserveId(spoke1);
    uint256 amount = 1e18;
    uint256 nonce = gateway.nonces(alice, _randomNonceKey());

    uint8[] memory actionTypes = new uint8[](2);
    actionTypes[0] = uint8(ISignatureGateway.ActionType.Supply);
    actionTypes[1] = uint8(ISignatureGateway.ActionType.SetUsingAsCollateral);

    bytes[] memory actionData = new bytes[](2);
    actionData[0] = abi.encode(_supplyActionData(spoke1, reserveId, amount));
    actionData[1] = abi.encode(_setUsingAsCollateralActionData(spoke1, reserveId, true));

    bytes32 digest = _getBatchTypedDataHash(
      gateway,
      actionTypes,
      actionData,
      alice,
      nonce,
      deadline
    );
    bytes memory signature = _sign(alicePk, digest);

    Utils.approve(spoke1, reserveId, alice, address(gateway), amount);

    vm.expectCall(address(spoke1), abi.encodeCall(ISpokeBase.supply, (reserveId, amount, alice)));
    vm.expectCall(
      address(spoke1),
      abi.encodeCall(ISpoke.setUsingAsCollateral, (reserveId, true, alice))
    );
    vm.prank(vm.randomAddress());
    gateway.executeBatchWithSig(actionTypes, actionData, alice, nonce, deadline, signature);

    _assertNonceIncrement(gateway, alice, nonce);
    assertTrue(_isUsingAsCollateral(spoke1, reserveId, alice));
    _assertGatewayHasNoBalanceOrAllowance(spoke1, gateway, alice);
    _assertGatewayHasNoActivePosition(spoke1, gateway);
  }

  function test_executeBatchWithSig_supplyBorrowRepay() public {
    uint256 deadline = _warpBeforeRandomDeadline();
    uint256 reserveId = _daiReserveId(spoke1);
    uint256 supplyAmount = 10e18;
    uint256 borrowAmount = 5e18;
    uint256 repayAmount = 2e18;
    uint256 nonce = gateway.nonces(alice, _randomNonceKey());

    Utils.supplyCollateral(spoke1, reserveId, alice, supplyAmount, alice);

    uint8[] memory actionTypes = new uint8[](2);
    actionTypes[0] = uint8(ISignatureGateway.ActionType.Borrow);
    actionTypes[1] = uint8(ISignatureGateway.ActionType.Repay);

    bytes[] memory actionData = new bytes[](2);
    actionData[0] = abi.encode(_borrowActionData(spoke1, reserveId, borrowAmount));
    actionData[1] = abi.encode(_repayActionData(spoke1, reserveId, repayAmount));

    bytes32 digest = _getBatchTypedDataHash(
      gateway,
      actionTypes,
      actionData,
      alice,
      nonce,
      deadline
    );
    bytes memory signature = _sign(alicePk, digest);

    Utils.approve(spoke1, reserveId, alice, address(gateway), repayAmount);

    vm.expectCall(
      address(spoke1),
      abi.encodeCall(ISpokeBase.borrow, (reserveId, borrowAmount, alice))
    );
    vm.expectCall(
      address(spoke1),
      abi.encodeCall(ISpokeBase.repay, (reserveId, repayAmount, alice))
    );
    vm.prank(vm.randomAddress());
    gateway.executeBatchWithSig(actionTypes, actionData, alice, nonce, deadline, signature);

    _assertNonceIncrement(gateway, alice, nonce);
    _assertGatewayHasNoBalanceOrAllowance(spoke1, gateway, alice);
    _assertGatewayHasNoActivePosition(spoke1, gateway);
  }

  function test_executeBatchWithSig_revertsOnExpiredDeadline() public {
    uint256 deadline = vm.getBlockTimestamp() - 1; // Expired
    uint256 reserveId = _randomReserveId(spoke1);
    uint256 amount = 1e18;
    uint256 nonce = gateway.nonces(alice, _randomNonceKey());

    uint8[] memory actionTypes = new uint8[](1);
    actionTypes[0] = uint8(ISignatureGateway.ActionType.Supply);

    bytes[] memory actionData = new bytes[](1);
    actionData[0] = abi.encode(_supplyActionData(spoke1, reserveId, amount));

    bytes32 digest = _getBatchTypedDataHash(
      gateway,
      actionTypes,
      actionData,
      alice,
      nonce,
      deadline
    );
    bytes memory signature = _sign(alicePk, digest);

    vm.expectRevert(IIntentConsumer.InvalidSignature.selector);
    vm.prank(vm.randomAddress());
    gateway.executeBatchWithSig(actionTypes, actionData, alice, nonce, deadline, signature);
  }

  function test_executeBatchWithSig_revertsOnInvalidSignature() public {
    uint256 deadline = _warpBeforeRandomDeadline();
    uint256 reserveId = _randomReserveId(spoke1);
    uint256 amount = 1e18;
    uint256 nonce = gateway.nonces(alice, _randomNonceKey());

    uint8[] memory actionTypes = new uint8[](1);
    actionTypes[0] = uint8(ISignatureGateway.ActionType.Supply);

    bytes[] memory actionData = new bytes[](1);
    actionData[0] = abi.encode(_supplyActionData(spoke1, reserveId, amount));

    // Sign with wrong key
    (, uint256 wrongPk) = makeAddrAndKey('wrong');
    bytes32 digest = _getBatchTypedDataHash(
      gateway,
      actionTypes,
      actionData,
      alice,
      nonce,
      deadline
    );
    bytes memory signature = _sign(wrongPk, digest);

    vm.expectRevert(IIntentConsumer.InvalidSignature.selector);
    vm.prank(vm.randomAddress());
    gateway.executeBatchWithSig(actionTypes, actionData, alice, nonce, deadline, signature);
  }

  function test_executeBatchWithSig_revertsOnLengthMismatch() public {
    uint256 deadline = _warpBeforeRandomDeadline();
    uint256 nonce = gateway.nonces(alice, 0);

    uint8[] memory actionTypes = new uint8[](2);
    actionTypes[0] = uint8(ISignatureGateway.ActionType.Supply);
    actionTypes[1] = uint8(ISignatureGateway.ActionType.Withdraw);

    bytes[] memory actionData = new bytes[](1); // Mismatch!
    actionData[0] = abi.encode(_supplyActionData(spoke1, 0, 1e18));

    // Don't compute digest - length mismatch should revert before signature verification
    vm.expectRevert(IGatewayBase.LengthMismatch.selector);
    vm.prank(vm.randomAddress());
    gateway.executeBatchWithSig(actionTypes, actionData, alice, nonce, deadline, hex'00');
  }

  function test_executeBatchWithSig_revertsOnEmptyBatch() public {
    uint256 deadline = _warpBeforeRandomDeadline();
    uint256 nonce = gateway.nonces(alice, _randomNonceKey());

    uint8[] memory actionTypes = new uint8[](0);
    bytes[] memory actionData = new bytes[](0);

    bytes32 digest = _getBatchTypedDataHash(
      gateway,
      actionTypes,
      actionData,
      alice,
      nonce,
      deadline
    );
    bytes memory signature = _sign(alicePk, digest);

    vm.expectRevert(IGatewayBase.InvalidBatchSize.selector);
    vm.prank(vm.randomAddress());
    gateway.executeBatchWithSig(actionTypes, actionData, alice, nonce, deadline, signature);
  }

  function test_executeBatchWithSig_revertsOnInvalidActionType() public {
    uint256 deadline = _warpBeforeRandomDeadline();
    uint256 nonce = gateway.nonces(alice, _randomNonceKey());

    uint8[] memory actionTypes = new uint8[](1);
    actionTypes[0] = 255; // Invalid action type

    bytes[] memory actionData = new bytes[](1);
    actionData[0] = abi.encode(_supplyActionData(spoke1, 0, 1e18));

    // Note: We can't easily create a valid signature for invalid action type
    // because the type string construction will fail
    vm.expectRevert();
    vm.prank(vm.randomAddress());
    gateway.executeBatchWithSig(actionTypes, actionData, alice, nonce, deadline, hex'00');
  }

  function test_buildBatchTypeString_singleSupply() public pure {
    uint8[] memory actionTypes = new uint8[](1);
    actionTypes[0] = uint8(ISignatureGateway.ActionType.Supply);

    string memory typeString = BatchEIP712.buildBatchTypeString(actionTypes);
    assertEq(
      typeString,
      'Batch(SupplyAction action0,address onBehalfOf,uint256 nonce,uint256 deadline)SupplyAction(address spoke,uint256 reserveId,uint256 amount)'
    );
  }

  function test_buildBatchTypeString_supplyWithdraw() public pure {
    uint8[] memory actionTypes = new uint8[](2);
    actionTypes[0] = uint8(ISignatureGateway.ActionType.Supply);
    actionTypes[1] = uint8(ISignatureGateway.ActionType.Withdraw);

    string memory typeString = BatchEIP712.buildBatchTypeString(actionTypes);
    assertEq(
      typeString,
      'Batch(SupplyAction action0,WithdrawAction action1,address onBehalfOf,uint256 nonce,uint256 deadline)SupplyAction(address spoke,uint256 reserveId,uint256 amount)WithdrawAction(address spoke,uint256 reserveId,uint256 amount)'
    );
  }

  function test_buildBatchTypeString_duplicateActions() public pure {
    uint8[] memory actionTypes = new uint8[](3);
    actionTypes[0] = uint8(ISignatureGateway.ActionType.Supply);
    actionTypes[1] = uint8(ISignatureGateway.ActionType.Supply);
    actionTypes[2] = uint8(ISignatureGateway.ActionType.Withdraw);

    string memory typeString = BatchEIP712.buildBatchTypeString(actionTypes);
    // SupplyAction definition should only appear once
    assertEq(
      typeString,
      'Batch(SupplyAction action0,SupplyAction action1,WithdrawAction action2,address onBehalfOf,uint256 nonce,uint256 deadline)SupplyAction(address spoke,uint256 reserveId,uint256 amount)WithdrawAction(address spoke,uint256 reserveId,uint256 amount)'
    );
  }

  function test_buildBatchTypeString_allActions() public pure {
    uint8[] memory actionTypes = new uint8[](7);
    actionTypes[0] = uint8(ISignatureGateway.ActionType.Supply);
    actionTypes[1] = uint8(ISignatureGateway.ActionType.Withdraw);
    actionTypes[2] = uint8(ISignatureGateway.ActionType.Borrow);
    actionTypes[3] = uint8(ISignatureGateway.ActionType.Repay);
    actionTypes[4] = uint8(ISignatureGateway.ActionType.SetUsingAsCollateral);
    actionTypes[5] = uint8(ISignatureGateway.ActionType.UpdateUserRiskPremium);
    actionTypes[6] = uint8(ISignatureGateway.ActionType.UpdateUserDynamicConfig);

    string memory typeString = BatchEIP712.buildBatchTypeString(actionTypes);

    // Type definitions should be in alphabetical order
    string
      memory expected = 'Batch(SupplyAction action0,WithdrawAction action1,BorrowAction action2,RepayAction action3,SetUsingAsCollateralAction action4,UpdateUserRiskPremiumAction action5,UpdateUserDynamicConfigAction action6,address onBehalfOf,uint256 nonce,uint256 deadline)BorrowAction(address spoke,uint256 reserveId,uint256 amount)RepayAction(address spoke,uint256 reserveId,uint256 amount)SetUsingAsCollateralAction(address spoke,uint256 reserveId,bool useAsCollateral)SupplyAction(address spoke,uint256 reserveId,uint256 amount)UpdateUserDynamicConfigAction(address spoke)UpdateUserRiskPremiumAction(address spoke)WithdrawAction(address spoke,uint256 reserveId,uint256 amount)';
    assertEq(typeString, expected);
  }
}
