// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {HubInvariants} from "./invariants/HubInvariants.t.sol";

/// @title Invariants
/// @notice Aggregator for hub invariants
abstract contract Invariants is HubInvariants {
    function invariant_INV_HUB() public returns (bool) {
        uint256 assetCount = hub.getAssetCount();

        for (uint256 i; i < assetCount; i++) {
            assert_INV_HUB_A(i);
            assert_INV_HUB_B(i);
            assert_INV_HUB_C(i);
            assert_INV_HUB_EF(i);
            assert_INV_HUB_GH(i);
            assert_INV_HUB_I(i);
            assert_INV_HUB_K(i);
            assert_INV_HUB_L(i);
        }

        return true;
    }
}
