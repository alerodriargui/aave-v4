// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/SpokeBase.t.sol';

contract PositionManagerBaseTest is SpokeBase {
  ISpoke public spoke;
  PositionManagerBaseWrapper public positionManager;
  uint256 public alicePk;

  function setUp() public virtual override {
    super.setUp();

    spoke = spoke1;
    (alice, alicePk) = makeAddrAndKey('alice');
    positionManager = new PositionManagerBaseWrapper(address(spoke));

    vm.prank(SPOKE_ADMIN);
    spoke.updatePositionManager(address(positionManager), true);
  }

  function test_constructor_fuzz(address randomSpoke) public {
    vm.assume(randomSpoke != address(0));
    PositionManagerBaseWrapper pm = new PositionManagerBaseWrapper(randomSpoke);

    assertEq(pm.SPOKE(), randomSpoke);
  }

  function test_constructor_revertsWith_InvalidAddress() public {
    vm.expectRevert(abi.encodeWithSelector(IPositionManagerBase.InvalidAddress.selector));
    new PositionManagerBaseWrapper(address(0));
  }

  function test_getReserveUnderlying_fuzz(uint256 reserveId) public view {
    reserveId = bound(reserveId, 0, spoke.getReserveCount() - 1);
    address expectedUnderlying = address(_underlying(spoke, reserveId));

    assertEq(positionManager.getReserveUnderlying(reserveId), expectedUnderlying);
  }

  function test_getReserveUnderlying_revertsWith_ReserveNotListed() public {
    uint256 reserveId = _randomInvalidReserveId(spoke);

    vm.expectRevert(abi.encodeWithSelector(ISpoke.ReserveNotListed.selector));
    positionManager.getReserveUnderlying(reserveId);
  }

  function test_setSelfAsUserPositionManagerWithSig() public {
    EIP712Types.SetUserPositionManager memory p = EIP712Types.SetUserPositionManager({
      positionManager: address(positionManager),
      user: alice,
      approve: true,
      nonce: spoke.nonces(address(alice), _randomNonceKey()), // note: this typed sig is forwarded to spoke
      deadline: _warpBeforeRandomDeadline()
    });
    bytes memory signature = _sign(alicePk, _getTypedDataHash(spoke, p));

    assertFalse(spoke.isPositionManager(alice, address(positionManager)));

    vm.expectEmit(address(spoke));
    emit ISpoke.SetUserPositionManager(alice, address(positionManager), p.approve);

    vm.prank(vm.randomAddress());
    positionManager.setSelfAsUserPositionManagerWithSig(
      p.user,
      p.approve,
      p.nonce,
      p.deadline,
      signature
    );

    _assertNonceIncrement(ISignatureGateway(address(spoke)), alice, p.nonce); // note: nonce consumed on spoke
    assertTrue(spoke.isPositionManager(alice, address(positionManager)));
  }

  function test_permitReserveUnderlying_revertsWith_ReserveNotListed() public {
    uint256 unlistedReserveId = vm.randomUint(spoke.getReserveCount() + 1, UINT256_MAX);
    vm.expectRevert(ISpoke.ReserveNotListed.selector);
    vm.prank(vm.randomAddress());
    positionManager.permitReserveUnderlying(
      unlistedReserveId,
      vm.randomAddress(),
      vm.randomUint(),
      vm.randomUint(),
      uint8(vm.randomUint()),
      bytes32(vm.randomUint()),
      bytes32(vm.randomUint())
    );
  }

  function test_permitReserveUnderlying_forwards_correct_call() public {
    uint256 reserveId = _randomReserveId(spoke);
    address owner = vm.randomAddress();
    address spender = address(positionManager);
    uint256 value = vm.randomUint();
    uint256 deadline = vm.randomUint();
    uint8 v = uint8(vm.randomUint());
    bytes32 r = bytes32(vm.randomUint());
    bytes32 s = bytes32(vm.randomUint());

    vm.expectCall(
      address(_underlying(spoke, reserveId)),
      abi.encodeCall(TestnetERC20.permit, (owner, spender, value, deadline, v, r, s)),
      1
    );
    vm.prank(vm.randomAddress());
    positionManager.permitReserveUnderlying(reserveId, owner, value, deadline, v, r, s);
  }

  function test_permitReserveUnderlying_ignores_permit_reverts() public {
    uint256 reserveId = _randomReserveId(spoke);
    address token = address(_underlying(spoke, reserveId));

    vm.mockCallRevert(token, TestnetERC20.permit.selector, vm.randomBytes(64));

    vm.prank(vm.randomAddress());
    positionManager.permitReserveUnderlying(
      reserveId,
      vm.randomAddress(),
      vm.randomUint(),
      vm.randomUint(),
      uint8(vm.randomUint()),
      bytes32(vm.randomUint()),
      bytes32(vm.randomUint())
    );
  }

  function test_permitReserveUnderlying() public {
    (address user, uint256 userPk) = makeAddrAndKey('user');
    uint256 reserveId = _randomReserveId(spoke);
    TestnetERC20 token = TestnetERC20(address(_underlying(spoke, reserveId)));

    assertEq(token.allowance(user, address(positionManager)), 0);

    EIP712Types.Permit memory params = EIP712Types.Permit({
      owner: user,
      spender: address(positionManager),
      value: 100e18,
      deadline: _warpBeforeRandomDeadline(),
      nonce: token.nonces(user)
    });

    (uint8 v, bytes32 r, bytes32 s) = vm.sign(userPk, _getTypedDataHash(token, params));

    vm.expectEmit(address(token));
    emit IERC20.Approval(user, address(positionManager), params.value);
    vm.prank(vm.randomAddress());
    positionManager.permitReserveUnderlying(
      reserveId,
      user,
      params.value,
      params.deadline,
      v,
      r,
      s
    );

    assertEq(token.allowance(user, address(positionManager)), params.value);
  }
}
