// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Interfaces
import {IHub} from "src/hub/interfaces/IHub.sol";

// Invariant Contracts
import {HubInvariants} from "./invariants/HubInvariants.t.sol";
import {SpokeInvariants} from "./invariants/SpokeInvariants.t.sol";

/// @title Invariants
/// @notice Wrappers for the protocol invariants implemented in each invariants contract
/// @dev recognised by Echidna when property mode is activated
/// @dev Inherits HubInvariants, SpokeInvariants
abstract contract Invariants is HubInvariants, SpokeInvariants {
    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                     BASE INVARIANTS                                       //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function invariant_INV_HUB() public returns (bool) {
        for (uint256 i; i < hubAddresses.length; i++) {
            address hubAddress = hubAddresses[i];

            uint256 assetCount = IHub(hubAddress).getAssetCount();
            for (uint256 j; j < assetCount; j++) {
                assert_INV_HUB_A(hubAddress, j);
                assert_INV_HUB_B(hubAddress, j);
                assert_INV_HUB_C(hubAddress, j);
                assert_INV_HUB_EF(hubAddress, j);
                assert_INV_HUB_GH(hubAddress, j);
                assert_INV_HUB_I(hubAddress, j, baseAssets[i].underlying);
                assert_INV_HUB_K(hubAddress, j);
                assert_INV_HUB_L(hubAddress, j);
            }
        }

        return true;
    }

    function invariant_INV_SP() public returns (bool) {
        // Applied per spoke
        for (uint256 i; i < spokesAddresses.length; i++) {
            address spoke = spokesAddresses[i];

            // Applied per actor per spoke
            for (uint256 j; j < actorAddresses.length; j++) {
                assert_INV_SP_D(spoke, actorAddresses[j]);
            }

            // Applied per reserve of the spoke
            for (uint256 j; j < spokeReserveIds[spoke].length; j++) {
                uint256 reserveId = _getReserveId(spoke, j);
                assert_INV_SP_A(spoke, reserveId);
                assert_INV_SP_C(spoke, reserveId);

                // Applied per actor per reserve of the spoke
                for (uint256 k; k < actorAddresses.length; k++) {
                    assert_INV_SP_B(spoke, reserveId, actorAddresses[k]);
                }
            }
        }
        return true;
    }
}
