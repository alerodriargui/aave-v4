// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/SpokeBase.t.sol';

/// forge-config: default.isolate = true
contract PositionManager_Gas_Tests is SpokeBase {
  string internal NAMESPACE = 'PositionManager.Operations';

  PositionManagerBaseWrapper public positionManager;
  uint192 internal nonceKey = 0;
  uint256 public alicePk;

  function setUp() public virtual override {
    deployFixtures();
    initEnvironment();

    (alice, alicePk) = makeAddrAndKey('alice');
    positionManager = new PositionManagerBaseWrapper(address(spoke1));

    vm.prank(SPOKE_ADMIN);
    spoke1.updatePositionManager(address(positionManager), true);
  }

  function test_setSelfAsUserPositionManagerWithSig() public {
    vm.prank(alice);
    spoke1.useNonce(nonceKey);
    EIP712Types.SetUserPositionManager memory p = EIP712Types.SetUserPositionManager({
      positionManager: address(positionManager),
      user: alice,
      approve: true,
      nonce: spoke1.nonces(alice, nonceKey),
      deadline: _warpBeforeRandomDeadline()
    });
    bytes memory signature = _sign(alicePk, _getTypedDataHash(spoke1, p));

    vm.prank(alice);
    spoke1.setUserPositionManager(address(positionManager), false);

    positionManager.setSelfAsUserPositionManagerWithSig(p, signature);
    vm.snapshotGasLastCall(NAMESPACE, 'Common - setSelfAsUserPositionManagerWithSig');
  }
}

/// forge-config: default.isolate = true
contract SupplyRepayPositionManager_Gas_Tests is SpokeBase {
  string internal NAMESPACE = 'PositionManager.Operations';

  SupplyRepayPositionManager public positionManager;

  function setUp() public virtual override {
    deployFixtures();
    initEnvironment();

    positionManager = new SupplyRepayPositionManager(address(spoke1));
    vm.prank(SPOKE_ADMIN);
    spoke1.updatePositionManager(address(positionManager), true);
    vm.prank(alice);
    spoke1.setUserPositionManager(address(positionManager), true);
    vm.prank(bob);
    tokenList.dai.approve(address(positionManager), UINT256_MAX);
  }

  function test_supplyOnBehalfOf() public {
    uint256 amount = 100e18;
    Utils.supply(spoke1, _daiReserveId(spoke1), alice, amount, alice);

    vm.prank(bob);
    positionManager.supplyOnBehalfOf(_daiReserveId(spoke1), amount, alice);
    vm.snapshotGasLastCall(NAMESPACE, 'SupplyRepayPositionManager - supplyOnBehalfOf');
  }

  function test_repayOnBehalfOf() public {
    uint256 aliceSupplyAmount = 1000e18;
    uint256 bobSupplyAmount = 150e18;
    uint256 borrowAmount = 100e18;
    uint256 repayAmount = 50e18;

    Utils.supplyCollateral(spoke1, _daiReserveId(spoke1), alice, aliceSupplyAmount, alice);
    Utils.supply(spoke1, _daiReserveId(spoke1), bob, bobSupplyAmount, bob);
    Utils.borrow(spoke1, _daiReserveId(spoke1), alice, borrowAmount, alice);
    Utils.repay(spoke1, _daiReserveId(spoke1), alice, 1e18, alice);

    vm.prank(bob);
    positionManager.repayOnBehalfOf(_daiReserveId(spoke1), repayAmount, alice);
    vm.snapshotGasLastCall(NAMESPACE, 'SupplyRepayPositionManager - repayOnBehalfOf');
  }
}

/// forge-config: default.isolate = true
contract WithdrawPermitPositionManager_Gas_Tests is SpokeBase {
  string internal NAMESPACE = 'PositionManager.Operations';

  WithdrawPermitPositionManager public positionManager;

  function setUp() public virtual override {
    deployFixtures();
    initEnvironment();

    positionManager = new WithdrawPermitPositionManager(address(spoke1));
    vm.prank(SPOKE_ADMIN);
    spoke1.updatePositionManager(address(positionManager), true);
    vm.prank(alice);
    spoke1.setUserPositionManager(address(positionManager), true);
  }

  function test_withdrawOnBehalfOf() public {
    uint256 amount = 100e18;

    vm.prank(alice);
    positionManager.approveWithdraw(bob, _daiReserveId(spoke1), UINT256_MAX);

    Utils.supply(spoke1, _daiReserveId(spoke1), alice, mintAmount_DAI, alice);
    Utils.withdraw(spoke1, _daiReserveId(spoke1), alice, amount, alice);

    vm.prank(bob);
    positionManager.withdrawOnBehalfOf(_daiReserveId(spoke1), amount, alice);
    vm.snapshotGasLastCall(
      NAMESPACE,
      'WithdrawPermitPositionManager - withdrawOnBehalfOf: partial'
    );

    vm.prank(alice);
    positionManager.approveWithdraw(bob, _daiReserveId(spoke1), UINT256_MAX);

    vm.prank(bob);
    positionManager.withdrawOnBehalfOf(_daiReserveId(spoke1), UINT256_MAX, alice);
    vm.snapshotGasLastCall(NAMESPACE, 'WithdrawPermitPositionManager - withdrawOnBehalfOf: full');
  }
}

/// forge-config: default.isolate = true
contract CreditDelegationPositionManager_Gas_Tests is SpokeBase {
  string internal NAMESPACE = 'PositionManager.Operations';

  CreditDelegationPositionManager public positionManager;

  function setUp() public virtual override {
    deployFixtures();
    initEnvironment();

    positionManager = new CreditDelegationPositionManager(address(spoke1));
    vm.prank(SPOKE_ADMIN);
    spoke1.updatePositionManager(address(positionManager), true);
    vm.prank(alice);
    spoke1.setUserPositionManager(address(positionManager), true);
  }

  function test_borrowOnBehalfOf() public {
    uint256 aliceSupplyAmount = 5000e18;
    uint256 bobSupplyAmount = 1000e18;
    uint256 borrowAmount = 750e18;

    vm.prank(alice);
    positionManager.approveCreditDelegation(bob, _daiReserveId(spoke1), borrowAmount);

    Utils.supplyCollateral(spoke1, _daiReserveId(spoke1), alice, aliceSupplyAmount, alice);
    Utils.supplyCollateral(spoke1, _daiReserveId(spoke1), bob, bobSupplyAmount, bob);

    vm.prank(bob);
    positionManager.borrowOnBehalfOf(_daiReserveId(spoke1), borrowAmount, alice);
    vm.snapshotGasLastCall(NAMESPACE, 'CreditDelegationPositionManager - borrowOnBehalfOf');
  }
}
