// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/Hub/HubBase.t.sol';

contract MathUtilsMin {
  function min(uint256 a, uint256 b) external pure returns (uint256) {
    return MathUtils.min(a, b);
  }
}

contract MathMin {
  function min(uint256 a, uint256 b) external pure returns (uint256) {
    return Math.min(a, b);
  }
}

contract Exp {
  function expUnchecked(uint256 x) external pure returns (uint256) {
    return MathUtils.uncheckedExp(10, x);
  }

  function exp(uint256 x) external pure returns (uint256) {
    return 10 ** x;
  }

  function uncheckedAssemblyExp(uint256 x) external pure returns (uint256 result) {
    assembly {
      result := exp(10, x)
    }
  }
}

/// forge-config: default.isolate = true
contract PoCBug is HubBase {
  function test_min() public {
    uint a = vm.randomUint();
    uint b = vm.randomUint();

    MathUtilsMin mathUtilsMin = new MathUtilsMin();
    MathMin mathMin = new MathMin();

    mathUtilsMin.min(a, b);
    vm.snapshotGasLastCall('math', 'MathUtils.min');

    mathMin.min(a, b);
    vm.snapshotGasLastCall('math', 'Math.min');

    uint x = 18;

    Exp expContract = new Exp();
    expContract.expUnchecked(x);
    vm.snapshotGasLastCall('math', 'MathUtils.uncheckedExp');

    expContract.exp(x);
    vm.snapshotGasLastCall('math', '10 ** x');

    expContract.uncheckedAssemblyExp(x);
    vm.snapshotGasLastCall('math', 'assembly exp');
  }
}
