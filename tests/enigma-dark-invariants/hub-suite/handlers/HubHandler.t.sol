// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Interfaces
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {IHub, IHubBase} from "src/hub/Hub.sol";
import {IHubHandler} from "./interfaces/IHubHandler.sol";

// Libraries
import {WadRayMath} from "src/libraries/math/WadRayMath.sol";
import "forge-std/console.sol";

// Test Contracts
import {Actor} from "../../shared/utils/Actor.sol";
import {BaseHandler} from "../base/BaseHandler.t.sol";

/// @title HubHandler
/// @notice Handler for hub-level operations through actor-spokes
contract HubHandler is BaseHandler, IHubHandler {
    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                      ACTIONS                                              //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function add(uint256 amount, uint8 i) external setup {
        bool success;
        bytes memory returnData;
        targetAssetId = _getRandomBaseAssetId(i);
        address underlying = assetIdToUnderlying[targetAssetId];

        _before();
        vm.prank(address(actor));
        IERC20(underlying).transfer(address(hub), amount);
        (success, returnData) = actor.proxy(address(hub), abi.encodeCall(IHubBase.add, (targetAssetId, amount)));

        if (success) {
            _after();
        } else {
            revert("HubHandler: add failed");
        }
    }

    function remove(uint256 amount, uint8 i) external setup {
        bool success;
        bytes memory returnData;
        targetAssetId = _getRandomBaseAssetId(i);

        _before();
        (success, returnData) =
            actor.proxy(address(hub), abi.encodeCall(IHubBase.remove, (targetAssetId, amount, address(actor))));

        if (success) {
            _after();
        } else {
            revert("HubHandler: remove failed");
        }
    }

    function draw(uint256 amount, uint8 i) external setup {
        bool success;
        bytes memory returnData;
        targetAssetId = _getRandomBaseAssetId(i);

        _before();
        (success, returnData) =
            actor.proxy(address(hub), abi.encodeCall(IHubBase.draw, (targetAssetId, amount, address(actor))));

        if (success) {
            _after();
        } else {
            revert("HubHandler: draw failed");
        }
    }

    function restore(uint256 drawnAmount, uint256 premiumAmount, int256 sharesDelta, uint8 i) external setup {
        bool success;
        bytes memory returnData;
        targetAssetId = _getRandomBaseAssetId(i);
        address underlying = assetIdToUnderlying[targetAssetId];

        IHubBase.PremiumDelta memory premiumDelta = _calculatePremiumDelta(sharesDelta, premiumAmount, targetAssetId);

        _before();
        vm.prank(address(actor));
        IERC20(underlying).transfer(address(hub), drawnAmount + premiumAmount);
        (success, returnData) =
            actor.proxy(address(hub), abi.encodeCall(IHubBase.restore, (targetAssetId, drawnAmount, premiumDelta)));

        if (success) {
            _after();
        } else {
            revert("HubHandler: restore failed");
        }
    }

    function reportDeficit(uint256 drawnAmount, uint256 premiumAmount, int256 sharesDelta, uint8 i) external setup {
        bool success;
        bytes memory returnData;
        targetAssetId = _getRandomBaseAssetId(i);

        IHubBase.PremiumDelta memory premiumDelta = _calculatePremiumDelta(sharesDelta, premiumAmount, targetAssetId);

        _before();
        (success, returnData) = actor.proxy(
            address(hub), abi.encodeCall(IHubBase.reportDeficit, (targetAssetId, drawnAmount, premiumDelta))
        );

        if (success) {
            _after();
        } else {
            revert("HubHandler: reportDeficit failed");
        }
    }

    function eliminateDeficit(uint256 amount, uint8 i, uint8 j) external setup {
        bool success;
        bytes memory returnData;
        targetAssetId = _getRandomBaseAssetId(i);
        address spoke = _getRandomActor(j);

        _before();
        (success, returnData) =
            actor.proxy(address(hub), abi.encodeCall(IHub.eliminateDeficit, (targetAssetId, amount, spoke)));

        if (success) {
            _after();
        } else {
            revert("HubHandler: eliminateDeficit failed");
        }
    }

    function refreshPremium(int256 sharesDelta, uint8 i) external setup {
        bool success;
        bytes memory returnData;
        targetAssetId = _getRandomBaseAssetId(i);

        int256 offsetRayDelta = sharesDelta * int256(hub.getAssetDrawnIndex(targetAssetId));
        IHubBase.PremiumDelta memory premiumDelta =
            IHubBase.PremiumDelta({sharesDelta: sharesDelta, offsetRayDelta: offsetRayDelta, restoredPremiumRay: 0});

        _before();
        (success, returnData) =
            actor.proxy(address(hub), abi.encodeCall(IHubBase.refreshPremium, (targetAssetId, premiumDelta)));

        if (success) {
            _after();
        } else {
            revert("HubHandler: refreshPremium failed");
        }
    }

    function payFeeShares(uint256 shares, uint8 i) external setup {
        bool success;
        bytes memory returnData;
        targetAssetId = _getRandomBaseAssetId(i);

        _before();
        (success, returnData) =
            actor.proxy(address(hub), abi.encodeCall(IHubBase.payFeeShares, (targetAssetId, shares)));
        if (success) {
            _after();
        } else {
            revert("HubHandler: payFeeShares failed");
        }
    }

    function transferShares(uint256 shares, uint8 i, uint8 j) external setup {
        bool success;
        bytes memory returnData;
        targetAssetId = _getRandomBaseAssetId(i);
        address toSpoke = _getRandomActor(j);

        _before();
        (success, returnData) =
            actor.proxy(address(hub), abi.encodeCall(IHub.transferShares, (targetAssetId, shares, toSpoke)));

        if (success) {
            _after();
        } else {
            revert("HubHandler: transferShares failed");
        }
    }

    function sweep(uint256 amount, uint8 i) external setup {
        // TODO enable executor
        bool success;
        bytes memory returnData;
        targetAssetId = _getRandomBaseAssetId(i);

        _before();
        (success, returnData) = actor.proxy(address(hub), abi.encodeCall(IHub.sweep, (targetAssetId, amount)));

        if (success) {
            _after();
        } else {
            revert("HubHandler: sweep failed");
        }
    }

    function reclaim(uint256 amount, uint8 i) external setup {
        bool success;
        bytes memory returnData;
        targetAssetId = _getRandomBaseAssetId(i);

        _before();
        (success, returnData) = actor.proxy(address(hub), abi.encodeCall(IHub.reclaim, (targetAssetId, amount)));

        if (success) {
            _after();
        } else {
            revert("HubHandler: reclaim failed");
        }
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                           HELPERS                                         //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function _calculatePremiumDelta(int256 sharesDelta, uint256 premiumAmount, uint256 assetId)
        internal
        view
        returns (IHubBase.PremiumDelta memory)
    {
        uint256 drawnIndex = hub.getAssetDrawnIndex(assetId);

        // Calculate restoredPremiumRay from premiumAmount
        uint256 restoredPremiumRay = premiumAmount * WadRayMath.RAY;

        // Calculate offsetRayDelta to satisfy: (sharesDelta * drawnIndex) - offsetRayDelta + restoredPremiumRay == 0
        // Therefore: offsetRayDelta = (sharesDelta * drawnIndex) + restoredPremiumRay
        int256 offsetRayDelta = (sharesDelta * int256(drawnIndex)) + int256(restoredPremiumRay);

        return IHubBase.PremiumDelta({
            sharesDelta: sharesDelta, offsetRayDelta: offsetRayDelta, restoredPremiumRay: restoredPremiumRay
        });
    }
}
