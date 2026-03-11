// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/Hub/HubBase.t.sol';

/// @dev Tests that Hub preview functions silently return 1:1 for unlisted assetIds and zero amounts.
contract HubPreviewTest is HubBase {
  uint256 constant INVALID_ASSET_ID = type(uint256).max;
  uint256 constant AMOUNT = 100e18;

  function test_previewAddByAssets_invalidAssetId() public view {
    assertEq(hub1.previewAddByAssets(INVALID_ASSET_ID, AMOUNT), AMOUNT);
  }

  function test_previewAddByAssets_zeroAmount() public view {
    assertEq(hub1.previewAddByAssets(daiAssetId, 0), 0);
  }

  function test_previewAddByShares_invalidAssetId() public view {
    assertEq(hub1.previewAddByShares(INVALID_ASSET_ID, AMOUNT), AMOUNT);
  }

  function test_previewAddByShares_zeroAmount() public view {
    assertEq(hub1.previewAddByShares(daiAssetId, 0), 0);
  }

  function test_previewRemoveByAssets_invalidAssetId() public view {
    assertEq(hub1.previewRemoveByAssets(INVALID_ASSET_ID, AMOUNT), AMOUNT);
  }

  function test_previewRemoveByAssets_zeroAmount() public view {
    assertEq(hub1.previewRemoveByAssets(daiAssetId, 0), 0);
  }

  function test_previewRemoveByShares_invalidAssetId() public view {
    assertEq(hub1.previewRemoveByShares(INVALID_ASSET_ID, AMOUNT), AMOUNT);
  }

  function test_previewRemoveByShares_zeroAmount() public view {
    assertEq(hub1.previewRemoveByShares(daiAssetId, 0), 0);
  }

  function test_previewDrawByAssets_invalidAssetId() public view {
    assertEq(hub1.previewDrawByAssets(INVALID_ASSET_ID, AMOUNT), AMOUNT);
  }

  function test_previewDrawByAssets_zeroAmount() public view {
    assertEq(hub1.previewDrawByAssets(daiAssetId, 0), 0);
  }

  function test_previewDrawByShares_invalidAssetId() public view {
    assertEq(hub1.previewDrawByShares(INVALID_ASSET_ID, AMOUNT), AMOUNT);
  }

  function test_previewDrawByShares_zeroAmount() public view {
    assertEq(hub1.previewDrawByShares(daiAssetId, 0), 0);
  }

  function test_previewRestoreByAssets_invalidAssetId() public view {
    assertEq(hub1.previewRestoreByAssets(INVALID_ASSET_ID, AMOUNT), AMOUNT);
  }

  function test_previewRestoreByAssets_zeroAmount() public view {
    assertEq(hub1.previewRestoreByAssets(daiAssetId, 0), 0);
  }

  function test_previewRestoreByShares_invalidAssetId() public view {
    assertEq(hub1.previewRestoreByShares(INVALID_ASSET_ID, AMOUNT), AMOUNT);
  }

  function test_previewRestoreByShares_zeroAmount() public view {
    assertEq(hub1.previewRestoreByShares(daiAssetId, 0), 0);
  }
}
