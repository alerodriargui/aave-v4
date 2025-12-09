// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/SpokeBase.t.sol';

contract WithdrawPermitPositionManagerTest is SpokeBase {
  ISpoke public spoke;
  WithdrawPermitPositionManager public positionManager;
  TestReturnValues public returnValues;
  uint256 public alicePk;

  function setUp() public virtual override {
    deployFixtures();
    initEnvironment();

    spoke = spoke1;
    (alice, alicePk) = makeAddrAndKey('alice');
    positionManager = new WithdrawPermitPositionManager(address(spoke));

    vm.prank(SPOKE_ADMIN);
    spoke.updatePositionManager(address(positionManager), true);

    vm.prank(alice);
    spoke.setUserPositionManager(address(positionManager), true);
  }

  function test_eip712Domain() public {
    WithdrawPermitPositionManager instance = new WithdrawPermitPositionManager{
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
    assertEq(name, 'WithdrawPermitPositionManager');
    assertEq(version, '1');
    assertEq(chainId, block.chainid);
    assertEq(verifyingContract, address(instance));
    assertEq(salt, bytes32(0));
    assertEq(extensions.length, 0);
  }

  function test_DOMAIN_SEPARATOR() public {
    WithdrawPermitPositionManager instance = new WithdrawPermitPositionManager{
      salt: bytes32(vm.randomUint())
    }(vm.randomAddress());
    bytes32 expectedDomainSeparator = keccak256(
      abi.encode(
        keccak256(
          'EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)'
        ),
        keccak256('WithdrawPermitPositionManager'),
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
    amount = bound(amount, 1, mintAmount_DAI);

    vm.expectEmit(address(positionManager));
    emit IWithdrawPermitPositionManager.WithdrawApproval(alice, spender, reserveId, amount);
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
    amount = bound(amount, 1, mintAmount_DAI);

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
    emit IWithdrawPermitPositionManager.WithdrawApproval(alice, spender, reserveId, amount);
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

  function test_approveWithdrawWithSig_revertsWith_InvalidAccountNonce(bytes32) public {
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

  function test_withdrawOnBehalfOf() public {
    test_withdrawOnBehalfOf_fuzz(100e18);
  }

  function test_withdrawOnBehalfOf_fuzz(uint256 amount) public {
    amount = bound(amount, 1, mintAmount_DAI);

    Utils.supply({
      spoke: spoke,
      reserveId: _daiReserveId(spoke),
      caller: alice,
      amount: mintAmount_DAI,
      onBehalfOf: alice
    });
    uint256 expectedSupplyShares = hub1.previewAddByAssets(daiAssetId, mintAmount_DAI);

    vm.prank(alice);
    positionManager.approveWithdraw(bob, _daiReserveId(spoke), amount);

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
    assertEq(positionManager.withdrawAllowance(alice, bob, _daiReserveId(spoke)), 0);
  }

  function test_withdrawOnBehalfOf_fuzz_allBalance(uint256 supplyAmount) public {
    supplyAmount = bound(supplyAmount, 1, mintAmount_DAI);

    Utils.supply({
      spoke: spoke,
      reserveId: _daiReserveId(spoke),
      caller: alice,
      amount: supplyAmount,
      onBehalfOf: alice
    });
    uint256 expectedSupplyShares = hub1.previewAddByAssets(daiAssetId, supplyAmount);

    vm.prank(alice);
    positionManager.approveWithdraw(bob, _daiReserveId(spoke), supplyAmount * 10);

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
      prevAllowance - (supplyAmount * 2)
    );
  }

  function test_withdrawOnBehalfOf_fuzz_allBalanceWithInterest(
    uint256 supplyAmount,
    uint256 borrowAmount
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

    vm.prank(alice);
    positionManager.approveWithdraw(bob, _daiReserveId(spoke), supplyAmount * 10);

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

  function test_withdrawOnBehalfOf_revertsWith_InsufficientWithdrawAllowance(
    uint256 approvalAmount
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

    vm.prank(alice);
    positionManager.approveWithdraw(bob, _daiReserveId(spoke), approvalAmount);

    vm.expectRevert(
      abi.encodeWithSelector(
        IWithdrawPermitPositionManager.InsufficientWithdrawAllowance.selector,
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

  function _getTypedDataHash(
    IWithdrawPermitPositionManager _positionManager,
    EIP712Types.WithdrawPermit memory _params
  ) internal view returns (bytes32) {
    return
      _typedDataHash(_positionManager, vm.eip712HashStruct('WithdrawPermit', abi.encode(_params)));
  }

  function _typedDataHash(
    IWithdrawPermitPositionManager _positionManager,
    bytes32 typeHash
  ) internal view returns (bytes32) {
    return keccak256(abi.encodePacked('\x19\x01', _positionManager.DOMAIN_SEPARATOR(), typeHash));
  }
}
