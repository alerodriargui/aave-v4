// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {HubInvariants} from './invariants/HubInvariants.t.sol';

/// @title Invariants
/// @notice Aggregator for hub invariants
abstract contract Invariants is HubInvariants {
  function invariant_INV_HUB() public returns (bool) {
    uint256 assetCount = hub.getAssetCount();

    for (uint256 i; i < assetCount; i++) {
      // HUB
      assert_INV_HUB_A(i);
      assert_INV_HUB_B(i);
      assert_INV_HUB_C(i);
      assert_INV_HUB_EF(i);
      assert_INV_HUB_GH(i);
      assert_INV_HUB_I(i);
      assert_INV_HUB_K(i);
      assert_INV_HUB_O(i);
      assert_INV_HUB_P(i);
      assert_INV_HUB_N(i);
      for (uint256 j; j < NUMBER_OF_ACTORS; j++) {
        assert_INV_HUB_ERC4626_A(i, actorAddresses[j]);
        assert_INV_HUB_ERC4626_B(i, actorAddresses[j]);
      }
      assert_INV_HUB_ERC4626_C(i);
      assert_INV_HUB_ERC4626_D(i);
    }

    return true;
  }

  function invariant_INV_HUB_AVAILABILITY() public returns (bool) {
    uint256 assetCount = hub.getAssetCount();
    for (uint256 i; i < assetCount; i++) {
      assert_INV_HUB_AVAILABILITY_A(i);
      assert_INV_HUB_AVAILABILITY_B(i);
      assert_INV_HUB_AVAILABILITY_C(i);
      assert_INV_HUB_AVAILABILITY_D(i);
      assert_INV_HUB_AVAILABILITY_E(i);
      for (uint256 j; j < NUMBER_OF_ACTORS; j++) {
        assert_INV_HUB_AVAILABILITY_F(i, actorAddresses[j]);
        assert_INV_HUB_AVAILABILITY_G(i, actorAddresses[j]);
        assert_INV_HUB_AVAILABILITY_H(i, actorAddresses[j]);
        assert_INV_HUB_AVAILABILITY_I(i, actorAddresses[j]);
      }
    }

    return true;
  }
}
