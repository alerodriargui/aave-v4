// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {EnumerableSet} from 'src/dependencies/openzeppelin/EnumerableSet.sol';

// Interfaces
import {ITreasurySpoke} from 'src/spoke/interfaces/ITreasurySpoke.sol';
import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';
import {IHub} from 'src/hub/interfaces/IHub.sol';

// Invariant Contracts
import {HubInvariants} from './invariants/HubInvariants.t.sol';
import {SpokeInvariants} from './invariants/SpokeInvariants.t.sol';

/// @title Invariants
/// @notice Wrappers for the protocol invariants implemented in each invariants contract
/// @dev recognized by Echidna when property mode is activated
/// @dev Inherits HubInvariants, SpokeInvariants
abstract contract Invariants is HubInvariants, SpokeInvariants {
  using EnumerableSet for EnumerableSet.AddressSet;

  ///////////////////////////////////////////////////////////////////////////////////////////////
  //                                     BASE INVARIANTS                                       //
  ///////////////////////////////////////////////////////////////////////////////////////////////

  function invariant_INV_HUB() public returns (bool) {
    // Applied per hub
    for (uint256 i; i < hubs.length(); i++) {
      address hub = hubs.at(i);

      // Applied per asset of the hub
      uint256 assetCount = IHub(hub).getAssetCount();
      for (uint256 j; j < assetCount; j++) {
        assert_INV_HUB_A(hub, j);
        assert_INV_HUB_B(hub, j);
        assert_INV_HUB_C(hub, j);
        assert_INV_HUB_E(hub, j);
        assert_INV_HUB_F(hub, j);
        assert_INV_HUB_GH(hub, j);
        assert_INV_HUB_I(hub, j);
        assert_INV_HUB_K(hub, j);
        assert_INV_HUB_O(hub, j);
        assert_INV_HUB_P(hub, j);
        assert_INV_HUB_Q(hub, j);
        assert_INV_HUB_R(hub, j);
      }
    }

    return true;
  }

  function invariant_INV_SP() public returns (bool) {
    // Applied per spoke
    for (uint256 i; i < spokes.length(); i++) {
      address spoke = spokes.at(i);

      // Applied per actor on the spoke
      for (uint256 j; j < actors.length(); j++) {
        assert_INV_SP_D(spoke, actors.at(j));
      }

      // Applied per reserve of the spoke
      uint256 reserveCount = ISpoke(spoke).getReserveCount();
      for (uint256 j; j < reserveCount; j++) {
        assert_INV_SP_A(spoke, j);
        assert_INV_SP_C(spoke, j);
        assert_INV_SP_E(spoke, j);
        assert_INV_SP_F(spoke, j);

        // Applied per actor per reserve of the spoke
        for (uint256 k; k < actors.length(); k++) {
          assert_INV_SP_B(spoke, j, actors.at(k));
          assert_INV_SP_H(spoke, j, actors.at(k));
        }
      }
    }

    // Applied per treasury spoke (only hub-sync invariant applies;
    // user-level invariants don't apply since TreasurySpoke has no per-user positions)
    for (uint256 i; i < treasurySpokes.length(); i++) {
      address spoke = treasurySpokes.at(i);
      // reserveId == assetId for treasury spoke
      uint256 reserveCount = IHub(address(ITreasurySpoke(spoke).HUB())).getAssetCount();
      for (uint256 j; j < reserveCount; j++) {
        assert_INV_SP_A(spoke, j);
      }
    }

    return true;
  }
}
