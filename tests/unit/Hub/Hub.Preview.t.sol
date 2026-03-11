// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/Hub/HubBase.t.sol';

/// @dev Tests that Hub preview functions silently return 1:1 for unlisted assetIds and zero amounts.
contract HubPreviewTest is HubBase {
  uint256 constant INVALID_ASSET_ID = type(uint256).max;
  uint256 constant AMOUNT = 100e18;

  function test_previewAddByAssets() public view {
    assertEq(hub1.previewAddByAssets(INVALID_ASSET_ID, AMOUNT), AMOUNT);
    assertEq(hub1.previewAddByAssets(INVALID_ASSET_ID, 0), 0);
    assertEq(hub1.previewAddByAssets(daiAssetId, 0), 0);
  }

  function test_previewAddByShares() public view {
    assertEq(hub1.previewAddByShares(INVALID_ASSET_ID, AMOUNT), AMOUNT);
    assertEq(hub1.previewAddByShares(INVALID_ASSET_ID, 0), 0);
    assertEq(hub1.previewAddByShares(daiAssetId, 0), 0);
  }

  function test_previewRemoveByAssets() public view {
    assertEq(hub1.previewRemoveByAssets(INVALID_ASSET_ID, AMOUNT), AMOUNT);
    assertEq(hub1.previewRemoveByAssets(INVALID_ASSET_ID, 0), 0);
    assertEq(hub1.previewRemoveByAssets(daiAssetId, 0), 0);
  }

  function test_previewRemoveByShares() public view {
    assertEq(hub1.previewRemoveByShares(INVALID_ASSET_ID, AMOUNT), AMOUNT);
    assertEq(hub1.previewRemoveByShares(INVALID_ASSET_ID, 0), 0);
    assertEq(hub1.previewRemoveByShares(daiAssetId, 0), 0);
  }

  function test_previewDrawByAssets() public view {
    assertEq(hub1.previewDrawByAssets(INVALID_ASSET_ID, AMOUNT), AMOUNT);
    assertEq(hub1.previewDrawByAssets(INVALID_ASSET_ID, 0), 0);
    assertEq(hub1.previewDrawByAssets(daiAssetId, 0), 0);
  }

  function test_previewDrawByShares() public view {
    assertEq(hub1.previewDrawByShares(INVALID_ASSET_ID, AMOUNT), AMOUNT);
    assertEq(hub1.previewDrawByShares(INVALID_ASSET_ID, 0), 0);
    assertEq(hub1.previewDrawByShares(daiAssetId, 0), 0);
  }

  function test_previewRestoreByAssets() public view {
    assertEq(hub1.previewRestoreByAssets(INVALID_ASSET_ID, AMOUNT), AMOUNT);
    assertEq(hub1.previewRestoreByAssets(INVALID_ASSET_ID, 0), 0);
    assertEq(hub1.previewRestoreByAssets(daiAssetId, 0), 0);
  }

  function test_previewRestoreByShares() public view {
    assertEq(hub1.previewRestoreByShares(INVALID_ASSET_ID, AMOUNT), AMOUNT);
    assertEq(hub1.previewRestoreByShares(INVALID_ASSET_ID, 0), 0);
    assertEq(hub1.previewRestoreByShares(daiAssetId, 0), 0);
  }
}
