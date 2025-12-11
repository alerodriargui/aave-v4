// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/Spoke.MaxReserves.t.sol';

/// @dev Tests gas cost of liquidation with increasing number of reserves
/// forge-config: default.isolate = true
contract SpokeMaxReservesStepLiquidationTest is SpokeMaxReservesTest {
  /// @dev Analyzes the gast cost of liquidating a user with 1 additional reserve in steps
  function test_liquidation_cost_additional_collaterals() public {
    uint256 gasUsed = _liquidationTestHelper(10);
    vm.revertTo(setupSnapshot);
    console.log(
      'Gas diff from liquidating 11 vs 10 collaterals: ',
      _liquidationTestHelper(11) - gasUsed
    );
    vm.revertTo(setupSnapshot);

    gasUsed = _liquidationTestHelper(50);
    vm.revertTo(setupSnapshot);
    console.log(
      'Gas diff from liquidating 51 vs 50 collaterals: ',
      _liquidationTestHelper(51) - gasUsed
    );
    vm.revertTo(setupSnapshot);

    gasUsed = _liquidationTestHelper(100);
    vm.revertTo(setupSnapshot);
    console.log(
      'Gas diff from liquidating 101 vs 100 collaterals: ',
      _liquidationTestHelper(101) - gasUsed
    );
  }

  function _liquidationTestHelper(uint256 numReserves) internal returns (uint256) {
    uint256 i;
    uint256 gasUsed;
    // Supply numReserves collaterals
    for (i = 0; i < numReserves; i++) {
      Utils.supplyCollateral(spoke1, i, alice, 1000e18, alice);

      skip(1 days); // Ensure interest accrual

      vm.prank(alice);
      spoke1.borrow(i, 500e18, alice);
      gasUsed = vm.snapshotGasLastCall('Spoke.Investigation', 'borrow');

      if (gasUsed > MAX_TX_GAS) {
        console.log('OOG at', i + 1, 'collaterals');
        break;
      }
    }

    skip(10000 days);
    // Alice can be liquidated
    assertLe(
      spoke1.getUserAccountData(alice).healthFactor,
      LiquidationLogic.HEALTH_FACTOR_LIQUIDATION_THRESHOLD
    );

    vm.prank(bob);
    spoke1.liquidationCall(0, 1, alice, 1, false);
    gasUsed = vm.snapshotGasLastCall('Spoke.Investigation', 'liquidationCall');
    if (gasUsed > MAX_TX_GAS) {
      console.log('Liquidation OOG at ', i, ' collaterals');
      return 0;
    }
    return gasUsed;
  }
}
