// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {AllowancePositionManagerWrapper} from 'tests/mocks/AllowancePositionManagerWrapper.sol';
import 'tests/unit/Spoke/SpokeBase.t.sol';

contract AllowancePositionManagerTest is SpokeBase {
  ISpoke public spoke;
  AllowancePositionManagerWrapper public positionManager;
  TestReturnValues public returnValues;
  uint256 public alicePk;

  bytes32 private constant _TEMPORARY_WITHDRAW_ALLOWANCES_SLOT =
    0x1c6a61279a13a86a789311ddf30aee38e2f4a9f6c4aad1ff4a2e75a4018e68c3;
  bytes32 private constant _TEMPORARY_CREDIT_DELEGATIONS_SLOT =
    0xcd470af8670f5baa744a0341af8a2e3f5d7ca086178908432a5cfaf39cb9299d;

  function setUp() public virtual override {
    deployFixtures();
    initEnvironment();

    spoke = spoke1;
    (alice, alicePk) = makeAddrAndKey('alice');
    positionManager = new AllowancePositionManagerWrapper(address(spoke));

    vm.prank(SPOKE_ADMIN);
    spoke.updatePositionManager(address(positionManager), true);

    vm.prank(alice);
    spoke.setUserPositionManager(address(positionManager), true);
  }

  function test_eip712Domain() public {
    AllowancePositionManager instance = new AllowancePositionManager{
      salt: bytes32(vm.randomUint())
    }(vm.randomAddress());
    (
      bytes1 fields,
      string memory name,
      string memory version,
      uint256 chainId,
      address verifyingContract,
      bytes32 salt,
      uint256[] memory extensions
    ) = IERC5267(address(instance)).eip712Domain();

    assertEq(fields, bytes1(0x0f));
    assertEq(name, 'AllowancePositionManager');
    assertEq(version, '1');
    assertEq(chainId, block.chainid);
    assertEq(verifyingContract, address(instance));
    assertEq(salt, bytes32(0));
    assertEq(extensions.length, 0);
  }

  function test_DOMAIN_SEPARATOR() public {
    AllowancePositionManager instance = new AllowancePositionManager{
      salt: bytes32(vm.randomUint())
    }(vm.randomAddress());
    bytes32 expectedDomainSeparator = keccak256(
      abi.encode(
        keccak256(
          'EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)'
        ),
        keccak256('AllowancePositionManager'),
        keccak256('1'),
        block.chainid,
        address(instance)
      )
    );
    assertEq(instance.DOMAIN_SEPARATOR(), expectedDomainSeparator);
  }

  function test_withdrawPermit_typeHash() public view {
    assertEq(positionManager.WITHDRAW_PERMIT_TYPEHASH(), vm.eip712HashType('WithdrawPermit'));
    assertEq(
      positionManager.WITHDRAW_PERMIT_TYPEHASH(),
      keccak256(
        'WithdrawPermit(address owner,address spender,uint256 reserveId,uint256 amount,uint256 nonce,uint256 deadline)'
      )
    );
  }

  function test_approveWithdraw_fuzz(address spender, uint256 reserveId, uint256 amount) public {
    vm.assume(spender != address(0));
    reserveId = bound(reserveId, 0, spoke.getReserveCount() - 1);
    amount = bound(amount, 1, MAX_SUPPLY_AMOUNT);

    vm.expectEmit(address(positionManager));
    emit IAllowancePositionManager.WithdrawApproval(alice, spender, reserveId, amount);
    vm.prank(alice);
    positionManager.approveWithdraw(spender, reserveId, amount);

    assertEq(positionManager.withdrawAllowance(alice, spender, reserveId), amount);
  }

  function test_approveWithdrawWithSig_fuzz(
    address spender,
    uint256 reserveId,
    uint256 amount
  ) public {
    vm.assume(spender != address(0));
    reserveId = bound(reserveId, 0, spoke.getReserveCount() - 1);
    amount = bound(amount, 1, MAX_SUPPLY_AMOUNT);

    EIP712Types.WithdrawPermit memory p = _withdrawPermitData(
      spender,
      alice,
      _warpBeforeRandomDeadline()
    );
    p.amount = amount;
    p.reserveId = reserveId;
    p.nonce = _burnRandomNoncesAtKey(positionManager, alice);
    bytes memory signature = _sign(alicePk, _getTypedDataHash(positionManager, p));

    vm.expectEmit(address(positionManager));
    emit IAllowancePositionManager.WithdrawApproval(alice, spender, reserveId, amount);
    vm.prank(vm.randomAddress());
    positionManager.approveWithdrawWithSig(p, signature);

    assertEq(positionManager.withdrawAllowance(alice, spender, reserveId), amount);
  }

  function test_approveWithdrawWithSig_revertsWith_InvalidSignature_dueTo_ExpiredDeadline() public {
    EIP712Types.WithdrawPermit memory p = _withdrawPermitData(
      vm.randomAddress(),
      alice,
      _warpAfterRandomDeadline()
    );
    bytes memory signature = _sign(alicePk, _getTypedDataHash(positionManager, p));

    vm.expectRevert(ISpoke.InvalidSignature.selector);
    vm.prank(vm.randomAddress());
    positionManager.approveWithdrawWithSig(p, signature);
  }

  function test_approveWithdrawWithSig_revertsWith_InvalidSignature_dueTo_InvalidSigner() public {
    (address randomUser, uint256 randomUserPk) = makeAddrAndKey(string(vm.randomBytes(32)));
    address onBehalfOf = vm.randomAddress();
    while (onBehalfOf == randomUser) onBehalfOf = vm.randomAddress();

    EIP712Types.WithdrawPermit memory p = _withdrawPermitData(
      randomUser,
      onBehalfOf,
      _warpAfterRandomDeadline()
    );
    bytes memory signature = _sign(randomUserPk, _getTypedDataHash(positionManager, p));

    vm.expectRevert(ISpoke.InvalidSignature.selector);
    vm.prank(vm.randomAddress());
    positionManager.approveWithdrawWithSig(p, signature);
  }

  function test_approveWithdrawWithSig_fuzz_revertsWith_InvalidAccountNonce(bytes32) public {
    EIP712Types.WithdrawPermit memory p = _withdrawPermitData(
      vm.randomAddress(),
      alice,
      _warpBeforeRandomDeadline()
    );
    uint192 nonceKey = _randomNonceKey();
    uint256 currentNonce = _burnRandomNoncesAtKey(positionManager, p.owner, nonceKey);
    p.nonce = _getRandomInvalidNonceAtKey(positionManager, p.owner, nonceKey);

    bytes memory signature = _sign(alicePk, _getTypedDataHash(positionManager, p));

    vm.expectRevert(
      abi.encodeWithSelector(INoncesKeyed.InvalidAccountNonce.selector, p.owner, currentNonce)
    );
    vm.prank(vm.randomAddress());
    positionManager.approveWithdrawWithSig(p, signature);
  }

  function test_temporaryApproveWithdraw_fuzz(
    address spender,
    uint256 reserveId,
    uint256 amount
  ) public {
    vm.assume(spender != address(0));
    reserveId = bound(reserveId, 0, spoke.getReserveCount() - 1);
    amount = bound(amount, 1, MAX_SUPPLY_AMOUNT);

    vm.expectEmit(address(positionManager), 0);
    vm.prank(alice);
    positionManager.temporaryApproveWithdraw(spender, reserveId, amount);

    assertEq(positionManager.temporaryWithdrawAllowance(alice, spender, reserveId), amount);
  }

  /// forge-config: default.isolate = true
  function test_temporaryApproveWithdraw_TransientStorage() public {
    // make sure transient storage is used for temporary withdraw allowances
    vm.prank(alice);
    positionManager.temporaryApproveWithdraw(bob, _daiReserveId(spoke), 100e18);
    assertEq(positionManager.temporaryWithdrawAllowance(alice, bob, _daiReserveId(spoke)), 0);
  }

  function test_renounceWithdrawAllowance_fuzz(uint256 initialAllowance) public {
    uint256 reserveId = _randomReserveId(spoke);
    initialAllowance = bound(initialAllowance, 1, MAX_SUPPLY_AMOUNT);

    vm.prank(alice);
    positionManager.approveWithdraw(bob, reserveId, initialAllowance);

    vm.expectEmit(address(positionManager));
    emit IAllowancePositionManager.WithdrawApproval(alice, bob, reserveId, 0);
    vm.prank(bob);
    positionManager.renounceWithdrawAllowance(alice, reserveId);

    assertEq(positionManager.withdrawAllowance(alice, bob, reserveId), 0);
  }

  function test_renounceWithdrawAllowance_noop_alreadyRenounced() public {
    uint256 reserveId = _randomReserveId(spoke);

    vm.prank(alice);
    positionManager.approveWithdraw(bob, reserveId, 100e18);
    vm.prank(bob);
    positionManager.renounceWithdrawAllowance(alice, reserveId);

    vm.recordLogs();
    vm.prank(bob);
    positionManager.renounceWithdrawAllowance(alice, reserveId);
    assertEq(vm.getRecordedLogs().length, 0);
  }

  function test_withdrawOnBehalfOf() public {
    test_withdrawOnBehalfOf_fuzz(100e18, 0);
  }

  function test_withdrawOnBehalfOf_TemporaryAllowanceTakesPrecedence() public {
    uint256 storedAllowance = 300e18;
    _fuzzyApproveWithdraw(alice, alicePk, bob, _daiReserveId(spoke), storedAllowance, 0);
    test_withdrawOnBehalfOf_fuzz(100e18, 2);
    // this check is also performed in test_withdrawOnBehalfOf_fuzz, duplicating in case of future changes
    assertEq(positionManager.withdrawAllowance(alice, bob, _daiReserveId(spoke)), storedAllowance);
  }

  function test_withdrawOnBehalfOf_fuzz(uint256 amount, uint256 approvalType) public {
    amount = bound(amount, 1, mintAmount_DAI);

    Utils.supply({
      spoke: spoke,
      reserveId: _daiReserveId(spoke),
      caller: alice,
      amount: mintAmount_DAI,
      onBehalfOf: alice
    });
    uint256 expectedSupplyShares = hub1.previewAddByAssets(daiAssetId, mintAmount_DAI);

    uint256 withdrawAllowanceBefore = positionManager.withdrawAllowance(
      alice,
      bob,
      _daiReserveId(spoke)
    );
    _fuzzyApproveWithdraw(alice, alicePk, bob, _daiReserveId(spoke), amount, approvalType);

    uint256 prevUserBalance = tokenList.dai.balanceOf(alice);
    uint256 prevCallerBalance = tokenList.dai.balanceOf(bob);
    uint256 prevHubBalance = tokenList.dai.balanceOf(address(hub1));
    uint256 prevUserSuppliedAmount = spoke.getUserSuppliedAssets(_daiReserveId(spoke), alice);

    assertEq(spoke.getUserSuppliedShares(_daiReserveId(spoke), alice), expectedSupplyShares);

    vm.expectEmit(address(spoke));
    emit ISpokeBase.Withdraw(
      _daiReserveId(spoke),
      address(positionManager),
      alice,
      hub1.previewRemoveByAssets(daiAssetId, amount),
      amount
    );
    vm.prank(bob);
    (returnValues.shares, returnValues.amount) = positionManager.withdrawOnBehalfOf(
      _daiReserveId(spoke),
      amount,
      alice
    );

    assertEq(returnValues.amount, amount);
    assertEq(returnValues.shares, hub1.previewRemoveByAssets(daiAssetId, amount));

    assertEq(tokenList.dai.balanceOf(alice), prevUserBalance);
    assertEq(tokenList.dai.balanceOf(bob), prevCallerBalance + amount);
    assertEq(
      spoke.getUserSuppliedAssets(_daiReserveId(spoke), alice),
      prevUserSuppliedAmount - amount
    );
    assertEq(tokenList.dai.balanceOf(address(hub1)), prevHubBalance - amount);
    assertEq(tokenList.dai.balanceOf(address(positionManager)), 0);
    assertEq(tokenList.dai.allowance(address(positionManager), address(hub1)), 0);
    assertEq(
      positionManager.withdrawAllowance(alice, bob, _daiReserveId(spoke)),
      (approvalType < 2) ? 0 : withdrawAllowanceBefore
    );
  }

  function test_withdrawOnBehalfOf_fuzz_allBalance(
    uint256 supplyAmount,
    uint256 approvalType
  ) public {
    supplyAmount = bound(supplyAmount, 1, mintAmount_DAI);

    Utils.supply({
      spoke: spoke,
      reserveId: _daiReserveId(spoke),
      caller: alice,
      amount: supplyAmount,
      onBehalfOf: alice
    });
    uint256 expectedSupplyShares = hub1.previewAddByAssets(daiAssetId, supplyAmount);

    approvalType = _fuzzyApproveWithdraw(
      alice,
      alicePk,
      bob,
      _daiReserveId(spoke),
      supplyAmount * 10,
      approvalType
    );

    uint256 prevUserBalance = tokenList.dai.balanceOf(alice);
    uint256 prevCallerBalance = tokenList.dai.balanceOf(bob);
    uint256 prevHubBalance = tokenList.dai.balanceOf(address(hub1));
    uint256 prevAllowance = positionManager.withdrawAllowance(alice, bob, _daiReserveId(spoke));

    assertEq(spoke.getUserSuppliedShares(_daiReserveId(spoke), alice), expectedSupplyShares);

    vm.expectEmit(address(spoke));
    emit ISpokeBase.Withdraw(
      _daiReserveId(spoke),
      address(positionManager),
      alice,
      expectedSupplyShares,
      supplyAmount
    );
    vm.prank(bob);
    (returnValues.shares, returnValues.amount) = positionManager.withdrawOnBehalfOf(
      _daiReserveId(spoke),
      supplyAmount * 2,
      alice
    );

    assertEq(returnValues.amount, supplyAmount);
    assertEq(returnValues.shares, expectedSupplyShares);

    assertEq(tokenList.dai.balanceOf(alice), prevUserBalance);
    assertEq(tokenList.dai.balanceOf(bob), prevCallerBalance + supplyAmount);
    assertEq(spoke.getUserSuppliedAssets(_daiReserveId(spoke), alice), 0);
    assertEq(tokenList.dai.balanceOf(address(hub1)), prevHubBalance - supplyAmount);
    assertEq(tokenList.dai.balanceOf(address(positionManager)), 0);
    assertEq(tokenList.dai.allowance(address(positionManager), address(hub1)), 0);
    assertEq(
      positionManager.withdrawAllowance(alice, bob, _daiReserveId(spoke)),
      (approvalType < 2) ? prevAllowance - (supplyAmount * 2) : 0
    );
  }

  function test_withdrawOnBehalfOf_fuzz_allBalanceWithInterest(
    uint256 supplyAmount,
    uint256 borrowAmount,
    uint256 approvalType
  ) public {
    supplyAmount = bound(supplyAmount, 2, mintAmount_DAI / 2);
    borrowAmount = bound(borrowAmount, 1, supplyAmount / 2);

    Utils.supplyCollateral({
      spoke: spoke,
      reserveId: _daiReserveId(spoke),
      caller: alice,
      amount: supplyAmount,
      onBehalfOf: alice
    });
    Utils.supplyCollateral({
      spoke: spoke,
      reserveId: _daiReserveId(spoke),
      caller: bob,
      amount: supplyAmount,
      onBehalfOf: bob
    });
    uint256 expectedSupplyShares = hub1.previewAddByAssets(daiAssetId, supplyAmount);

    Utils.borrow({
      spoke: spoke,
      reserveId: _daiReserveId(spoke),
      caller: bob,
      amount: borrowAmount,
      onBehalfOf: bob
    });

    skip(322 days);
    vm.assume(hub1.getAddedAssets(daiAssetId) > supplyAmount);
    uint256 repayAmount = spoke.getReserveTotalDebt(_daiReserveId(spoke));
    deal(address(tokenList.dai), bob, repayAmount);

    Utils.repay({
      spoke: spoke,
      reserveId: _daiReserveId(spoke),
      caller: bob,
      amount: UINT256_MAX,
      onBehalfOf: bob
    });

    uint256 expectedWithdrawAmount = spoke.getUserSuppliedAssets(_daiReserveId(spoke), alice);

    _fuzzyApproveWithdraw(
      alice,
      alicePk,
      bob,
      _daiReserveId(spoke),
      supplyAmount * 10,
      approvalType
    );

    uint256 prevUserBalance = tokenList.dai.balanceOf(alice);
    uint256 prevCallerBalance = tokenList.dai.balanceOf(bob);
    uint256 prevHubBalance = tokenList.dai.balanceOf(address(hub1));

    assertEq(spoke.getUserSuppliedShares(_daiReserveId(spoke), alice), expectedSupplyShares);

    vm.expectEmit(address(spoke));
    emit ISpokeBase.Withdraw(
      _daiReserveId(spoke),
      address(positionManager),
      alice,
      expectedSupplyShares,
      expectedWithdrawAmount
    );
    vm.prank(bob);
    (returnValues.shares, returnValues.amount) = positionManager.withdrawOnBehalfOf(
      _daiReserveId(spoke),
      supplyAmount * 10,
      alice
    );

    assertEq(returnValues.amount, expectedWithdrawAmount);
    assertEq(returnValues.shares, expectedSupplyShares);

    assertEq(tokenList.dai.balanceOf(alice), prevUserBalance);
    assertEq(tokenList.dai.balanceOf(bob), prevCallerBalance + expectedWithdrawAmount);
    assertEq(spoke.getUserSuppliedAssets(_daiReserveId(spoke), alice), 0);
    assertEq(tokenList.dai.balanceOf(address(hub1)), prevHubBalance - expectedWithdrawAmount);
    assertEq(tokenList.dai.balanceOf(address(positionManager)), 0);
    assertEq(tokenList.dai.allowance(address(positionManager), address(hub1)), 0);
    assertEq(positionManager.withdrawAllowance(alice, bob, _daiReserveId(spoke)), 0);
  }

  // temporary withdraw allowance takes precedence over stored withdraw allowance, and does not cumulate
  function test_withdrawOnBehalfOf_revertsWith_InsufficientWithdrawAllowance_TemporaryAllowanceTakesPrecedence()
    public
  {
    uint256 storedAllowance = 300e18;
    _fuzzyApproveWithdraw(alice, alicePk, bob, _daiReserveId(spoke), storedAllowance, 0);

    uint256 amount = 20e18;
    uint256 temporaryAllowance = amount - 1;
    _fuzzyApproveWithdraw(alice, alicePk, bob, _daiReserveId(spoke), temporaryAllowance, 2);

    vm.expectRevert(
      abi.encodeWithSelector(
        IAllowancePositionManager.InsufficientWithdrawAllowance.selector,
        temporaryAllowance,
        amount
      )
    );
    vm.prank(bob);
    positionManager.withdrawOnBehalfOf(_daiReserveId(spoke), amount, alice);

    assertEq(positionManager.withdrawAllowance(alice, bob, _daiReserveId(spoke)), storedAllowance);
  }

  function test_withdrawOnBehalfOf_fuzz_revertsWith_InsufficientWithdrawAllowance(
    uint256 approvalAmount,
    uint256 approvalType
  ) public {
    uint256 amount = 100e18;
    approvalAmount = bound(approvalAmount, 1, amount - 1);

    Utils.supply({
      spoke: spoke,
      reserveId: _daiReserveId(spoke),
      caller: alice,
      amount: mintAmount_DAI,
      onBehalfOf: alice
    });

    _fuzzyApproveWithdraw(alice, alicePk, bob, _daiReserveId(spoke), approvalAmount, approvalType);

    vm.expectRevert(
      abi.encodeWithSelector(
        IAllowancePositionManager.InsufficientWithdrawAllowance.selector,
        approvalAmount,
        amount
      )
    );
    vm.prank(bob);
    positionManager.withdrawOnBehalfOf(_daiReserveId(spoke), amount, alice);
  }

  function test_withdrawOnBehalfOf_revertsWith_InvalidAmount() public {
    vm.expectRevert(IPositionManagerBase.InvalidAmount.selector);
    vm.prank(bob);
    positionManager.withdrawOnBehalfOf(_daiReserveId(spoke), 0, alice);
  }

  function test_withdrawOnBehalfOf_revertsWith_ReserveNotListed() public {
    uint256 reserveId = _randomInvalidReserveId(spoke);

    vm.prank(alice);
    positionManager.approveWithdraw(bob, reserveId, 100e18);

    vm.expectRevert(ISpoke.ReserveNotListed.selector);
    vm.prank(bob);
    positionManager.withdrawOnBehalfOf(reserveId, 100e18, alice);
  }

  function test_creditDelegation_typeHash() public view {
    assertEq(positionManager.CREDIT_DELEGATION_TYPEHASH(), vm.eip712HashType('CreditDelegation'));
    assertEq(
      positionManager.CREDIT_DELEGATION_TYPEHASH(),
      keccak256(
        'CreditDelegation(address owner,address spender,uint256 reserveId,uint256 amount,uint256 nonce,uint256 deadline)'
      )
    );
  }

  function test_creditDelegation_fuzz(address spender, uint256 reserveId, uint256 amount) public {
    vm.assume(spender != address(0));
    reserveId = bound(reserveId, 0, spoke.getReserveCount() - 1);
    amount = bound(amount, 1, MAX_SUPPLY_AMOUNT);

    vm.expectEmit(address(positionManager));
    emit IAllowancePositionManager.CreditDelegation(alice, spender, reserveId, amount);
    vm.prank(alice);
    positionManager.creditDelegation(spender, reserveId, amount);

    assertEq(positionManager.creditDelegation(alice, spender, reserveId), amount);
  }

  function test_creditDelegationWithSig_fuzz(
    address spender,
    uint256 reserveId,
    uint256 amount
  ) public {
    vm.assume(spender != address(0));
    reserveId = bound(reserveId, 0, spoke.getReserveCount() - 1);
    amount = bound(amount, 1, MAX_SUPPLY_AMOUNT);

    EIP712Types.CreditDelegation memory p = _creditDelegationData(
      spender,
      alice,
      _warpBeforeRandomDeadline()
    );
    p.amount = amount;
    p.reserveId = reserveId;
    p.nonce = _burnRandomNoncesAtKey(positionManager, alice);
    bytes memory signature = _sign(alicePk, _getTypedDataHash(positionManager, p));

    vm.expectEmit(address(positionManager));
    emit IAllowancePositionManager.CreditDelegation(alice, spender, reserveId, amount);
    vm.prank(vm.randomAddress());
    positionManager.creditDelegationWithSig(p, signature);

    assertEq(positionManager.creditDelegation(alice, spender, reserveId), amount);
  }

  function test_creditDelegationWithSig_revertsWith_InvalidSignature_dueTo_ExpiredDeadline()
    public
  {
    EIP712Types.CreditDelegation memory p = _creditDelegationData(
      vm.randomAddress(),
      alice,
      _warpAfterRandomDeadline()
    );
    bytes memory signature = _sign(alicePk, _getTypedDataHash(positionManager, p));

    vm.expectRevert(ISpoke.InvalidSignature.selector);
    vm.prank(vm.randomAddress());
    positionManager.creditDelegationWithSig(p, signature);
  }

  function test_creditDelegationWithSig_revertsWith_InvalidSignature_dueTo_InvalidSigner() public {
    (address randomUser, uint256 randomUserPk) = makeAddrAndKey(string(vm.randomBytes(32)));
    address onBehalfOf = vm.randomAddress();
    while (onBehalfOf == randomUser) onBehalfOf = vm.randomAddress();

    EIP712Types.CreditDelegation memory p = _creditDelegationData(
      randomUser,
      onBehalfOf,
      _warpAfterRandomDeadline()
    );
    bytes memory signature = _sign(randomUserPk, _getTypedDataHash(positionManager, p));

    vm.expectRevert(ISpoke.InvalidSignature.selector);
    vm.prank(vm.randomAddress());
    positionManager.creditDelegationWithSig(p, signature);
  }

  function test_creditDelegationWithSig_revertsWith_InvalidAccountNonce(bytes32) public {
    EIP712Types.CreditDelegation memory p = _creditDelegationData(
      vm.randomAddress(),
      alice,
      _warpBeforeRandomDeadline()
    );
    uint192 nonceKey = _randomNonceKey();
    uint256 currentNonce = _burnRandomNoncesAtKey(positionManager, p.owner, nonceKey);
    p.nonce = _getRandomInvalidNonceAtKey(positionManager, p.owner, nonceKey);

    bytes memory signature = _sign(alicePk, _getTypedDataHash(positionManager, p));

    vm.expectRevert(
      abi.encodeWithSelector(INoncesKeyed.InvalidAccountNonce.selector, p.owner, currentNonce)
    );
    vm.prank(vm.randomAddress());
    positionManager.creditDelegationWithSig(p, signature);
  }

  function test_temporaryCreditDelegation_fuzz(
    address spender,
    uint256 reserveId,
    uint256 amount
  ) public {
    vm.assume(spender != address(0));
    reserveId = bound(reserveId, 0, spoke.getReserveCount() - 1);
    amount = bound(amount, 1, MAX_SUPPLY_AMOUNT);

    vm.expectEmit(address(positionManager), 0);
    vm.prank(alice);
    positionManager.temporaryCreditDelegation(spender, reserveId, amount);

    assertEq(positionManager.temporaryCreditDelegation(alice, spender, reserveId), amount);
  }

  /// forge-config: default.isolate = true
  function test_temporaryCreditDelegation_TransientStorage() public {
    // make sure transient storage is used for temporary credit delegations
    vm.prank(alice);
    positionManager.temporaryCreditDelegation(bob, _daiReserveId(spoke), 100e18);
    assertEq(positionManager.temporaryCreditDelegation(alice, bob, _daiReserveId(spoke)), 0);
  }

  function test_renounceCreditDelegation_fuzz(uint256 initialAllowance) public {
    uint256 reserveId = _randomReserveId(spoke);
    initialAllowance = bound(initialAllowance, 1, MAX_SUPPLY_AMOUNT);

    vm.prank(alice);
    positionManager.creditDelegation(bob, reserveId, initialAllowance);

    vm.expectEmit(address(positionManager));
    emit IAllowancePositionManager.CreditDelegation(alice, bob, reserveId, 0);
    vm.prank(bob);
    positionManager.renounceCreditDelegation(alice, reserveId);

    assertEq(positionManager.creditDelegation(alice, bob, reserveId), 0);
  }

  function test_renounceCreditDelegation_noop_alreadyRenounced() public {
    uint256 reserveId = _randomReserveId(spoke);

    vm.prank(alice);
    positionManager.creditDelegation(bob, reserveId, 100e18);
    vm.prank(bob);
    positionManager.renounceCreditDelegation(alice, reserveId);

    vm.recordLogs();
    vm.prank(bob);
    positionManager.renounceCreditDelegation(alice, reserveId);
    assertEq(vm.getRecordedLogs().length, 0);
  }

  function test_borrowOnBehalfOf() public {
    test_borrowOnBehalfOf_fuzz(5e18, 5e18, 0);
  }

  function test_borrowOnBehalfOf_TemporaryCreditDelegationTakesPrecedence() public {
    uint256 storedAllowance = 300e18;
    _fuzzyCreditDelegation(alice, alicePk, bob, _daiReserveId(spoke), storedAllowance, 0);
    test_borrowOnBehalfOf_fuzz(5e18, 5e18, 2);
    // this check is also performed in test_borrowOnBehalfOf_fuzz, duplicating in case of future changes
    assertEq(positionManager.creditDelegation(alice, bob, _daiReserveId(spoke)), storedAllowance);
  }

  function test_borrowOnBehalfOf_fuzz(
    uint256 borrowAmount,
    uint256 creditDelegationAmount,
    uint256 approvalType
  ) public {
    uint256 aliceSupplyAmount = 5000e18;
    uint256 bobSupplyAmount = 1000e18;
    borrowAmount = bound(borrowAmount, 1, bobSupplyAmount);
    creditDelegationAmount = bound(creditDelegationAmount, borrowAmount, borrowAmount * 10);

    Utils.supplyCollateral(spoke, _daiReserveId(spoke), alice, aliceSupplyAmount, alice);
    Utils.supplyCollateral(spoke, _daiReserveId(spoke), bob, bobSupplyAmount, bob);

    uint256 creditDelegationAllowanceBefore = positionManager.creditDelegation(
      alice,
      bob,
      _daiReserveId(spoke)
    );
    approvalType = _fuzzyCreditDelegation(
      alice,
      alicePk,
      bob,
      _daiReserveId(spoke),
      creditDelegationAmount,
      approvalType
    );

    uint256 prevUserBalance = tokenList.dai.balanceOf(alice);
    uint256 prevCallerBalance = tokenList.dai.balanceOf(bob);
    uint256 prevHubBalance = tokenList.dai.balanceOf(address(hub1));

    vm.expectEmit(address(spoke));
    emit ISpokeBase.Borrow(
      _daiReserveId(spoke),
      address(positionManager),
      alice,
      hub1.previewRestoreByAssets(daiAssetId, borrowAmount),
      borrowAmount
    );
    vm.prank(bob);
    (returnValues.shares, returnValues.amount) = positionManager.borrowOnBehalfOf(
      _daiReserveId(spoke),
      borrowAmount,
      alice
    );

    (uint256 userDrawnDebt, uint256 userPremiumDebt) = spoke.getUserDebt(
      _daiReserveId(spoke),
      alice
    );

    assertEq(returnValues.amount, borrowAmount);
    assertEq(returnValues.shares, hub1.previewDrawByAssets(daiAssetId, borrowAmount));

    assertEq(userDrawnDebt + userPremiumDebt, borrowAmount);
    assertEq(tokenList.dai.balanceOf(address(hub1)), prevHubBalance - borrowAmount);
    assertEq(tokenList.dai.balanceOf(address(alice)), prevUserBalance);
    assertEq(tokenList.dai.balanceOf(address(bob)), prevCallerBalance + borrowAmount);
    assertEq(tokenList.dai.allowance(address(positionManager), address(hub1)), 0);
    assertEq(
      positionManager.creditDelegation(alice, bob, _daiReserveId(spoke)),
      (approvalType < 2) ? creditDelegationAmount - borrowAmount : creditDelegationAllowanceBefore
    );
  }

  // temporary credit delegation takes precedence over stored credit delegation, and does not cumulate
  function test_borrowOnBehalfOf_revertsWith_InsufficientCreditDelegation_TemporaryCreditDelegationTakesPrecedence()
    public
  {
    uint256 storedAllowance = 300e18;
    _fuzzyCreditDelegation(alice, alicePk, bob, _daiReserveId(spoke), storedAllowance, 0);

    uint256 amount = 100e18;
    uint256 temporaryAllowance = amount - 1;
    _fuzzyCreditDelegation(alice, alicePk, bob, _daiReserveId(spoke), temporaryAllowance, 2);

    vm.expectRevert(
      abi.encodeWithSelector(
        IAllowancePositionManager.InsufficientCreditDelegation.selector,
        temporaryAllowance,
        amount
      )
    );
    vm.prank(bob);
    positionManager.borrowOnBehalfOf(_daiReserveId(spoke), amount, alice);

    assertEq(positionManager.creditDelegation(alice, bob, _daiReserveId(spoke)), storedAllowance);
  }

  function test_borrowOnBehalfOf_fuzz_revertsWith_InsufficientCreditDelegation(
    uint256 creditDelegationAmount,
    uint256 approvalType
  ) public {
    uint256 borrowAmount = 100e18;
    creditDelegationAmount = bound(creditDelegationAmount, 1, borrowAmount - 1);
    Utils.supplyCollateral(spoke, _daiReserveId(spoke), alice, borrowAmount, alice);
    Utils.supplyCollateral(spoke, _daiReserveId(spoke), bob, borrowAmount, bob);

    _fuzzyCreditDelegation(
      alice,
      alicePk,
      bob,
      _daiReserveId(spoke),
      creditDelegationAmount,
      approvalType
    );

    vm.expectRevert(
      abi.encodeWithSelector(
        IAllowancePositionManager.InsufficientCreditDelegation.selector,
        creditDelegationAmount,
        borrowAmount
      )
    );
    vm.prank(bob);
    positionManager.borrowOnBehalfOf(_daiReserveId(spoke), borrowAmount, alice);
  }

  function test_borrowOnBehalfOf_revertsWith_InvalidAmount() public {
    vm.expectRevert(IPositionManagerBase.InvalidAmount.selector);
    vm.prank(bob);
    positionManager.borrowOnBehalfOf(_daiReserveId(spoke), 0, alice);
  }

  function test_borrowOnBehalfOf_revertsWith_ReserveNotListed() public {
    uint256 reserveId = _randomInvalidReserveId(spoke);

    vm.prank(alice);
    positionManager.creditDelegation(bob, reserveId, 100e18);

    vm.expectRevert(ISpoke.ReserveNotListed.selector);
    vm.prank(bob);
    positionManager.borrowOnBehalfOf(reserveId, 100e18, alice);
  }

  function _fuzzyApproveWithdraw(
    address onBehalfOf,
    uint256 onBehalfOfPk,
    address spender,
    uint256 reserveId,
    uint256 amount,
    uint256 approvalType
  ) internal returns (uint256) {
    approvalType = bound(approvalType, 0, 2);
    if (approvalType == 0) {
      vm.prank(onBehalfOf);
      positionManager.approveWithdraw(spender, reserveId, amount);
    } else if (approvalType == 1) {
      EIP712Types.WithdrawPermit memory p = _withdrawPermitData(
        spender,
        onBehalfOf,
        type(uint256).max
      );
      p.amount = amount;
      p.reserveId = reserveId;
      p.nonce = _burnRandomNoncesAtKey(positionManager, onBehalfOf);
      bytes memory signature = _sign(onBehalfOfPk, _getTypedDataHash(positionManager, p));

      vm.prank(vm.randomAddress());
      positionManager.approveWithdrawWithSig(p, signature);
    } else {
      vm.prank(onBehalfOf);
      positionManager.temporaryApproveWithdraw(spender, reserveId, amount);
    }
    return approvalType;
  }

  function _fuzzyCreditDelegation(
    address onBehalfOf,
    uint256 onBehalfOfPk,
    address spender,
    uint256 reserveId,
    uint256 amount,
    uint256 approvalType
  ) internal returns (uint256) {
    approvalType = bound(approvalType, 0, 2);
    if (approvalType == 0) {
      vm.prank(onBehalfOf);
      positionManager.creditDelegation(spender, reserveId, amount);
    } else if (approvalType == 1) {
      EIP712Types.CreditDelegation memory p = _creditDelegationData(
        spender,
        onBehalfOf,
        type(uint256).max
      );
      p.amount = amount;
      p.reserveId = reserveId;
      p.nonce = _burnRandomNoncesAtKey(positionManager, onBehalfOf);
      bytes memory signature = _sign(onBehalfOfPk, _getTypedDataHash(positionManager, p));

      vm.prank(vm.randomAddress());
      positionManager.creditDelegationWithSig(p, signature);
    } else {
      vm.prank(onBehalfOf);
      positionManager.temporaryCreditDelegation(spender, reserveId, amount);
    }
    return approvalType;
  }

  function _withdrawPermitData(
    address spender,
    address onBehalfOf,
    uint256 deadline
  ) internal returns (EIP712Types.WithdrawPermit memory) {
    return
      EIP712Types.WithdrawPermit({
        owner: onBehalfOf,
        spender: spender,
        reserveId: _randomReserveId(spoke),
        amount: vm.randomUint(1, MAX_SUPPLY_AMOUNT),
        nonce: positionManager.nonces(onBehalfOf, _randomNonceKey()),
        deadline: deadline
      });
  }

  function _creditDelegationData(
    address spender,
    address onBehalfOf,
    uint256 deadline
  ) internal returns (EIP712Types.CreditDelegation memory) {
    return
      EIP712Types.CreditDelegation({
        owner: onBehalfOf,
        spender: spender,
        reserveId: _randomReserveId(spoke),
        amount: vm.randomUint(1, MAX_SUPPLY_AMOUNT),
        nonce: positionManager.nonces(onBehalfOf, _randomNonceKey()),
        deadline: deadline
      });
  }

  function _getTypedDataHash(
    IAllowancePositionManager _positionManager,
    EIP712Types.WithdrawPermit memory _params
  ) internal view returns (bytes32) {
    return
      _typedDataHash(_positionManager, vm.eip712HashStruct('WithdrawPermit', abi.encode(_params)));
  }

  function _getTypedDataHash(
    IAllowancePositionManager _positionManager,
    EIP712Types.CreditDelegation memory _params
  ) internal view returns (bytes32) {
    return
      _typedDataHash(
        _positionManager,
        vm.eip712HashStruct('CreditDelegation', abi.encode(_params))
      );
  }

  function _typedDataHash(
    IAllowancePositionManager _positionManager,
    bytes32 typeHash
  ) internal view returns (bytes32) {
    return keccak256(abi.encodePacked('\x19\x01', _positionManager.DOMAIN_SEPARATOR(), typeHash));
  }
}
