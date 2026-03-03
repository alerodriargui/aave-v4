// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Interfaces
import {IHub} from 'src/hub/interfaces/IHub.sol';

// Invariant Contracts
import {HubInvariants} from './invariants/HubInvariants.t.sol';
import {SpokeInvariants} from './invariants/SpokeInvariants.t.sol';

/// @title Invariants
/// @notice Wrappers for the protocol invariants implemented in each invariants contract
/// @dev recognised by Echidna when property mode is activated
/// @dev Inherits HubInvariants, SpokeInvariants
abstract contract Invariants is HubInvariants, SpokeInvariants {
  ///////////////////////////////////////////////////////////////////////////////////////////////
  //                                     BASE INVARIANTS                                       //
  ///////////////////////////////////////////////////////////////////////////////////////////////

  function invariant_INV_HUB() public returns (bool) {
    // Applied per hub
    for (uint256 i; i < hubAddresses.length; i++) {
      address hubAddress = hubAddresses[i];

      // Applied per asset of the hub
      uint256 assetCount = IHub(hubAddress).getAssetCount();
      for (uint256 j; j < assetCount; j++) {
        assert_INV_HUB_A(hubAddress, j);
        assert_INV_HUB_B(hubAddress, j);
        assert_INV_HUB_C(hubAddress, j);
        assert_INV_HUB_E(hubAddress, j);
        assert_INV_HUB_F(hubAddress, j);
        assert_INV_HUB_GH(hubAddress, j);
        assert_INV_HUB_I(hubAddress, j);
        assert_INV_HUB_K(hubAddress, j);
        assert_INV_HUB_O(hubAddress, j);
        assert_INV_HUB_P(hubAddress, j);
        assert_INV_HUB_Q(hubAddress, j);
        assert_INV_HUB_R(hubAddress, j);
      }
    }

    return true;
  }

  function invariant_INV_SP() public returns (bool) {
    // Applied per spoke
    for (uint256 i; i < spokesAddresses.length; i++) {
      address spoke = spokesAddresses[i];

      // Applied per actor on the spoke
      for (uint256 j; j < actorAddresses.length; j++) {
        assert_INV_SP_D(spoke, actorAddresses[j]);
      }

      // Applied per reserve of the spoke
      for (uint256 j; j < spokeReserveIds[spoke].length; j++) {
        uint256 reserveId = spokeReserveIds[spoke][j];
        assert_INV_SP_A(spoke, reserveId);
        assert_INV_SP_C(spoke, reserveId);
        assert_INV_SP_E(spoke, reserveId);
        assert_INV_SP_F(spoke, reserveId);

        // Applied per actor per reserve of the spoke
        for (uint256 k; k < actorAddresses.length; k++) {
          assert_INV_SP_B(spoke, reserveId, actorAddresses[k]);
          assert_INV_SP_H(spoke, reserveId, actorAddresses[k]);
        }
      }
    }

    // Applied per treasury spoke (only hub-sync invariant applies;
    // user-level invariants don't apply since TreasurySpoke has no per-user positions)
    for (uint256 i; i < treasurySpokesAddresses.length; i++) {
      address spoke = treasurySpokesAddresses[i];
      for (uint256 j; j < spokeReserveIds[spoke].length; j++) {
        uint256 reserveId = spokeReserveIds[spoke][j];
        assert_INV_SP_A(spoke, reserveId);
      }
    }

    return true;
  }
}
