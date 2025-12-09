// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/SpokeBase.t.sol';

contract CreditDelegationPositionManagerTest is SpokeBase {
  ISpoke public spoke;
  CreditDelegationPositionManager public positionManager;
  TestReturnValues public returnValues;
  uint256 public alicePk;

  function setUp() public virtual override {
    deployFixtures();
    initEnvironment();

    spoke = spoke1;
    (alice, alicePk) = makeAddrAndKey('alice');
    positionManager = new CreditDelegationPositionManager(address(spoke));

    vm.prank(SPOKE_ADMIN);
    spoke.updatePositionManager(address(positionManager), true);

    vm.prank(alice);
    spoke.setUserPositionManager(address(positionManager), true);
  }

  function test_eip712Domain() public {
    CreditDelegationPositionManager instance = new CreditDelegationPositionManager{
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
    assertEq(name, 'CreditDelegationPositionManager');
    assertEq(version, '1');
    assertEq(chainId, block.chainid);
    assertEq(verifyingContract, address(instance));
    assertEq(salt, bytes32(0));
    assertEq(extensions.length, 0);
  }

  function test_DOMAIN_SEPARATOR() public {
    CreditDelegationPositionManager instance = new CreditDelegationPositionManager{
      salt: bytes32(vm.randomUint())
    }(vm.randomAddress());
    bytes32 expectedDomainSeparator = keccak256(
      abi.encode(
        keccak256(
          'EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)'
        ),
        keccak256('CreditDelegationPositionManager'),
        keccak256('1'),
        block.chainid,
        address(instance)
      )
    );
    assertEq(instance.DOMAIN_SEPARATOR(), expectedDomainSeparator);
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

  function test_approveCreditDelegation_fuzz(
    address spender,
    uint256 reserveId,
    uint256 amount
  ) public {
    vm.assume(spender != address(0));
    reserveId = bound(reserveId, 0, spoke.getReserveCount() - 1);
    amount = bound(amount, 1, mintAmount_DAI);

    vm.expectEmit(address(positionManager));
    emit ICreditDelegationPositionManager.CreditDelegation(alice, spender, reserveId, amount);
    vm.prank(alice);
    positionManager.approveCreditDelegation(spender, reserveId, amount);

    assertEq(positionManager.creditDelegationAllowance(alice, spender, reserveId), amount);
  }

  function test_approveCreditDelegationWithSig_fuzz(
    address spender,
    uint256 reserveId,
    uint256 amount
  ) public {
    vm.assume(spender != address(0));
    reserveId = bound(reserveId, 0, spoke.getReserveCount() - 1);
    amount = bound(amount, 1, mintAmount_DAI);

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
    emit ICreditDelegationPositionManager.CreditDelegation(alice, spender, reserveId, amount);
    vm.prank(vm.randomAddress());
    positionManager.approveCreditDelegationWithSig(p, signature);

    assertEq(positionManager.creditDelegationAllowance(alice, spender, reserveId), amount);
  }

  function test_approveCreditDelegationWithSig_revertsWith_InvalidSignature_dueTo_ExpiredDeadline()
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
    positionManager.approveCreditDelegationWithSig(p, signature);
  }

  function test_approveCreditDelegationWithSig_revertsWith_InvalidSignature_dueTo_InvalidSigner()
    public
  {
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
    positionManager.approveCreditDelegationWithSig(p, signature);
  }

  function test_approveCreditDelegationWithSig_revertsWith_InvalidAccountNonce(bytes32) public {
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
    positionManager.approveCreditDelegationWithSig(p, signature);
  }

  function test_borrowOnBehalfOf() public {
    test_borrowOnBehalfOf_fuzz(5e18, 5e18);
  }

  function test_borrowOnBehalfOf_fuzz(uint256 borrowAmount, uint256 creditDelegationAmount) public {
    uint256 aliceSupplyAmount = 5000e18;
    uint256 bobSupplyAmount = 1000e18;
    borrowAmount = bound(borrowAmount, 1, bobSupplyAmount);
    creditDelegationAmount = bound(creditDelegationAmount, borrowAmount, borrowAmount * 10);

    Utils.supplyCollateral(spoke, _daiReserveId(spoke), alice, aliceSupplyAmount, alice);
    Utils.supplyCollateral(spoke, _daiReserveId(spoke), bob, bobSupplyAmount, bob);

    vm.prank(alice);
    positionManager.approveCreditDelegation(
      address(bob),
      _daiReserveId(spoke),
      creditDelegationAmount
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
      positionManager.creditDelegationAllowance(alice, bob, _daiReserveId(spoke)),
      creditDelegationAmount - borrowAmount
    );
  }

  function test_borrowOnBehalfOf_revertsWith_InsufficientCreditDelegation(
    uint256 creditDelegationAmount
  ) public {
    uint256 borrowAmount = 100e18;
    creditDelegationAmount = bound(creditDelegationAmount, 1, borrowAmount - 1);
    Utils.supplyCollateral(spoke, _daiReserveId(spoke), alice, borrowAmount, alice);
    Utils.supplyCollateral(spoke, _daiReserveId(spoke), bob, borrowAmount, bob);

    vm.prank(alice);
    positionManager.approveCreditDelegation(
      address(bob),
      _daiReserveId(spoke),
      creditDelegationAmount
    );

    vm.expectRevert(
      abi.encodeWithSelector(
        ICreditDelegationPositionManager.InsufficientCreditDelegation.selector,
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
    positionManager.approveCreditDelegation(bob, reserveId, 100e18);

    vm.expectRevert(ISpoke.ReserveNotListed.selector);
    vm.prank(bob);
    positionManager.borrowOnBehalfOf(reserveId, 100e18, alice);
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
    ICreditDelegationPositionManager _positionManager,
    EIP712Types.CreditDelegation memory _params
  ) internal view returns (bytes32) {
    return
      _typedDataHash(
        _positionManager,
        vm.eip712HashStruct('CreditDelegation', abi.encode(_params))
      );
  }

  function _typedDataHash(
    ICreditDelegationPositionManager _positionManager,
    bytes32 typeHash
  ) internal view returns (bytes32) {
    return keccak256(abi.encodePacked('\x19\x01', _positionManager.DOMAIN_SEPARATOR(), typeHash));
  }
}
