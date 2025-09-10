// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/Hub/HubBase.t.sol';

contract HubMaxGettersTest is HubBase {
  using SharesMath for uint256;

  function test_maxAdd_returns_zero_spoke_inactive() public {
    uint256 assetId = _randomAssetId(hub1);
    vm.prank(HUB_ADMIN);
    hub1.updateSpokeConfig(assetId, address(spoke1), DataTypes.SpokeConfig(false, 0, 0));

    assertEq(hub1.maxAdd(assetId, address(spoke1)), 0);
  }

  function test_maxAdd_returns_zero_nonexistent_spoke() public {
    uint256 assetId = _randomAssetId(hub1);
    assertEq(hub1.maxAdd(assetId, address(0)), 0);
  }

  function test_maxAdd_returns_max_uint256_max_cap() public {
    uint256 assetId = _randomAssetId(hub1);
    vm.prank(HUB_ADMIN);
    hub1.updateSpokeConfig(
      assetId,
      address(spoke1),
      DataTypes.SpokeConfig(true, Constants.MAX_CAP, 0)
    );

    assertEq(hub1.maxAdd(assetId, address(spoke1)), UINT256_MAX);
  }

  /// @dev When max cap, maxAdd always returns max uint256
  function test_maxAdd_fuzz_no_cap(uint256 addAmount) public {
    addAmount = bound(addAmount, 1, MAX_SUPPLY_AMOUNT);
    uint256 assetId = _randomAssetId(hub1);
    vm.prank(HUB_ADMIN);
    hub1.updateSpokeConfig(
      assetId,
      address(spoke1),
      DataTypes.SpokeConfig(true, Constants.MAX_CAP, 0)
    );

    Utils.add(hub1, assetId, address(spoke1), addAmount, bob);

    assertEq(hub1.maxAdd(assetId, address(spoke1)), UINT256_MAX);
  }

  /// @dev Returns the difference between a non-max cap and added assets
  function test_maxAdd_fuzz(uint256 addAmount) public {
    uint256 assetId = _randomAssetId(hub1);
    uint256 cap = Constants.MAX_CAP - 1;
    uint8 decimals = hub1.getAsset(assetId).decimals;
    addAmount = bound(addAmount, 1, cap * 10 ** decimals);
    vm.prank(HUB_ADMIN);
    hub1.updateSpokeConfig(assetId, address(spoke1), DataTypes.SpokeConfig(true, uint56(cap), 0));

    Utils.add(hub1, assetId, address(spoke1), addAmount, bob);

    assertEq(hub1.maxAdd(assetId, address(spoke1)), cap * 10 ** decimals - addAmount);
  }
}
