// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/unit/Spoke/SpokeBase.t.sol';

contract SpokeDynamicConfigTest is SpokeBase {
  using SafeCast for uint256;

  function test_updateDynamicReserveConfig_fuzz_revertsWith_InvalidCollateralFactor() public {
    uint16 collateralFactor = bound(
      vm.randomUint(),
      PercentageMath.PERCENTAGE_FACTOR + 1,
      type(uint16).max
    ).toUint16();

    uint256 daiReserveId = _daiReserveId(spoke1);
    DataTypes.DynamicReserveConfig memory config = spoke1.getDynamicReserveConfig(daiReserveId);
    config.collateralFactor = collateralFactor;

    vm.expectRevert(ISpoke.InvalidCollateralFactor.selector);
    vm.prank(SPOKE_ADMIN);
    spoke1.updateDynamicReserveConfig(daiReserveId, config);
  }

  function test_updateDynamicReserveConfig_once() public {
    DynamicConfig[] memory configs = _getSpokeDynConfigKeys(spoke1);

    for (uint256 reserveId; reserveId < spoke1.reserveCount(); ++reserveId) {
      uint16 dynamicConfigKey = _nextConfigKey(spoke1, reserveId);

      DataTypes.DynamicReserveConfig memory dynConf = spoke1.getDynamicReserveConfig(reserveId);
      dynConf.collateralFactor = _randomBps();
      vm.expectEmit(address(spoke1));
      emit ISpoke.DynamicReserveConfigUpdated(reserveId, dynamicConfigKey, dynConf);
      vm.prank(SPOKE_ADMIN);
      spoke1.updateDynamicReserveConfig(reserveId, dynConf);

      configs[reserveId].key = dynamicConfigKey;
      assertEq(_getSpokeDynConfigKeys(spoke1), configs);
    }
  }

  function test_fuzz_updateDynamicReserveConfig_trailing_order(bytes32) public {
    DynamicConfig[] memory configs = _getSpokeDynConfigKeys(spoke1);
    uint256 runs = (vm.randomUint() % 100) + 1; // [1,100] iterations each fuzz run

    while (--runs != 0) {
      uint256 reserveId = vm.randomUint() % spoke1.reserveCount();
      uint16 dynamicConfigKey = _nextConfigKey(spoke1, reserveId);

      DataTypes.DynamicReserveConfig memory dynConf = spoke1.getDynamicReserveConfig(reserveId);
      dynConf.collateralFactor = _randomBps();

      vm.expectEmit(address(spoke1));
      emit ISpoke.DynamicReserveConfigUpdated(reserveId, dynamicConfigKey, dynConf);
      vm.prank(SPOKE_ADMIN);
      spoke1.updateDynamicReserveConfig(reserveId, dynConf);

      configs[reserveId].key = dynamicConfigKey;
      assertEq(_getSpokeDynConfigKeys(spoke1), configs);
    }
  }

  // todo test key overwrites stale slot, dynamically determine struct size & overwrite dynamicConfigKey or use mock spoke
  // todo test spaced dup coll factor updates
}
