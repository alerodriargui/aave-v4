// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {EnumerableSet} from 'src/dependencies/openzeppelin/EnumerableSet.sol';

// Interfaces
import {ISpokeBase} from 'src/spoke/interfaces/ISpokeBase.sol';
import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';
import {IHub} from 'src/hub/interfaces/IHub.sol';

// Contracts
import {HandlerAggregator} from '../HandlerAggregator.t.sol';

/// @title SpokeInvariants
/// @notice Implements Spoke Invariants for the protocol
/// @dev Inherits HandlerAggregator to check actions in assertion testing mode
abstract contract SpokeInvariants is HandlerAggregator {
  using EnumerableSet for EnumerableSet.AddressSet;

  ///////////////////////////////////////////////////////////////////////////////////////////////
  //                                          SPOKE                                             //
  ///////////////////////////////////////////////////////////////////////////////////////////////

  function assert_INV_SP_A(address spoke, uint256 reserveId) internal {
    // Get the assetId related to the reserveId of the spoke
    uint256 assetId = _getAssetId(spoke, reserveId);

    IHub hub = IHub(_getHubAddress(spoke, reserveId));

    // supply
    assertEq(
      ISpokeBase(spoke).getReserveSuppliedShares(reserveId),
      hub.getSpokeAddedShares(assetId, spoke),
      INV_SP_A
    );
    assertEq(
      ISpokeBase(spoke).getReserveSuppliedAssets(reserveId),
      hub.getSpokeAddedAssets(assetId, spoke),
      INV_SP_A
    );

    // debt
    (uint256 d1, uint256 p1) = hub.getSpokeOwed(assetId, spoke);
    (uint256 d2, uint256 p2) = ISpokeBase(spoke).getReserveDebt(reserveId);
    assertEq(d2, d1, INV_SP_A);
    assertEq(p2, p1, INV_SP_A);
  }

  function assert_INV_SP_B(address spoke, uint256 reserveId, address user) internal {
    // reserve supply
    if (ISpokeBase(spoke).getReserveSuppliedAssets(reserveId) > 0) {
      assertGt(ISpokeBase(spoke).getReserveSuppliedShares(reserveId), 0, INV_SP_B);
    }
    // reserve debt
    if (ISpokeBase(spoke).getReserveTotalDebt(reserveId) > 0) {
      assertGt(
        IHub(_getHubAddress(spoke, reserveId)).getSpokeDrawnShares(
          _getAssetId(spoke, reserveId),
          spoke
        ),
        0,
        INV_SP_B
      );
    }
    // user supply
    if (ISpokeBase(spoke).getUserSuppliedAssets(reserveId, user) > 0) {
      assertGt(ISpokeBase(spoke).getUserSuppliedShares(reserveId, user), 0, INV_SP_B);
    }
    // user debt
    if (ISpokeBase(spoke).getUserTotalDebt(reserveId, user) > 0) {
      ISpoke.UserPosition memory up = ISpoke(spoke).getUserPosition(reserveId, user);
      assertTrue(up.drawnShares > 0 || up.premiumShares > 0, INV_SP_B);
    }
  }

  function assert_INV_SP_C(address spoke, uint256 reserveId) internal {
    uint256 sumSpokeDebts;
    for (uint256 i; i < actors.length(); i++) {
      sumSpokeDebts += ISpokeBase(spoke).getUserTotalDebt(reserveId, actors.at(i));
    }
    assertGe(sumSpokeDebts, ISpokeBase(spoke).getReserveTotalDebt(reserveId), INV_SP_C);
  }

  function assert_INV_SP_D(address spoke, address user) internal {
    ISpoke.UserAccountData memory d = ISpoke(spoke).getUserAccountData(user);
    if (d.totalDebtValueRay == 0) {
      assertEq(d.healthFactor, type(uint256).max, INV_SP_D);
    } else if (d.totalCollateralValue == 0) {
      assertEq(d.healthFactor, 0, INV_SP_D);
    }
  }

  function assert_INV_SP_E(address spoke, uint256 reserveId) internal {
    uint256 sumUserShares;
    for (uint256 i; i < actors.length(); i++) {
      sumUserShares += ISpokeBase(spoke).getUserSuppliedShares(reserveId, actors.at(i));
    }
    assertEq(sumUserShares, ISpokeBase(spoke).getReserveSuppliedShares(reserveId), INV_SP_E);
  }

  function assert_INV_SP_F(address spoke, uint256 reserveId) internal {
    uint256 sumUserAssets;
    for (uint256 i; i < actors.length(); i++) {
      sumUserAssets += ISpokeBase(spoke).getUserSuppliedAssets(reserveId, actors.at(i));
    }
    uint256 reserveSuppliedAssets = ISpokeBase(spoke).getReserveSuppliedAssets(reserveId);
    assertLe(sumUserAssets, reserveSuppliedAssets, INV_SP_F);
    assertApproxEqAbs(sumUserAssets, reserveSuppliedAssets, NUMBER_OF_ACTORS, INV_SP_F);
  }

  function assert_INV_SP_H(address spoke, uint256 reserveId, address user) internal {
    uint32 userKey = ISpoke(spoke).getUserPosition(reserveId, user).dynamicConfigKey;
    uint32 reserveKey = ISpoke(spoke).getReserve(reserveId).dynamicConfigKey;
    if (userKey > 0) {
      assertLe(uint256(userKey), uint256(reserveKey), INV_SP_H);
    }
  }
}
