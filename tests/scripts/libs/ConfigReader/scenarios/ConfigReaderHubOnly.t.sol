// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/scripts/libs/ConfigReader/scenarios/ConfigReaderBase.t.sol';

/// @notice Scenario: Hub-only deployment — deploy a bare hub with no spokes, assets, or reserves.
///
///   Config: config/test-hub-only-no-assets.json
///   - 1 hub (BARE_HUB), 0 spokes, 0 assets, 0 spoke registrations, 0 reserves
///   - Token registry has WETH but it's not used in any asset/reserve
///   - All array sections (spokes, assets, spokeRegistrations, reserves) are empty []
///
///   Tests verify:
///   - Empty arrays parse correctly (count functions return 0)
///   - Hub key is readable even when nothing else is populated
///   - Infrastructure section parses independently of asset/spoke sections
///   - Token registry is still accessible even with no assets
///   - This represents initial hub deployment before assets are listed
contract ConfigReaderHubOnlyTest is ConfigReaderBaseTest {
  using ConfigReader for string;

  function setUp() public {
    json = vm.readFile('config/test/test-hub-only-no-assets.json');
  }

  function test_hubOnly_counts() public view {
    assertEq(_countHubs(), 1);
    assertEq(_countSpokes(), 0);
    assertEq(_countAssets(), 0);
    assertEq(_countSpokeRegistrations(), 0);
    assertEq(_countReserves(), 0);
  }

  function test_hubOnly_hubKey() public view {
    _assertStr(json.hubKey(0), 'BARE_HUB', 'hubKey[0]');
  }

  function test_hubOnly_infrastructure() public view {
    ConfigReader.InfrastructureConfig memory infra = json.readInfrastructure();
    assertEq(infra.accessManagerAdmin, address(1));
    _assertStr(infra.salt, 'hub-only-v1', 'salt');
    // Optional fields not set → address(0)
    assertEq(infra.gatewayOwner, address(0));
    assertEq(infra.nativeWrapper, address(0));
  }

  function test_hubOnly_tokenRegistryStillAccessible() public view {
    string[] memory keys = json.tokenKeys();
    assertEq(keys.length, 1);
    assertEq(json.tokenAddress('WETH'), 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
  }

  function test_hubOnly_noSecondHub() public view {
    assertFalse(json.hubExists(1));
  }
}
