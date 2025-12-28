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

    function add(uint256 amount, uint8 i) public setup returns (uint256 addedShares) {
        bool success;
        bytes memory returnData;
        uint256 cachedTargetAssetId = targetAssetId = _getRandomBaseAssetId(i);
        address underlying = assetIdToUnderlying[cachedTargetAssetId];

        uint256 previewAddedShares = hub.previewAddByAssets(cachedTargetAssetId, amount);

        uint256 assetsBefore = hub.getSpokeAddedAssets(cachedTargetAssetId, address(actor));
        uint256 sharesBefore = hub.getSpokeAddedShares(cachedTargetAssetId, address(actor));

        _before();
        vm.prank(address(actor));
        IERC20(underlying).transfer(address(hub), amount);
        (success, returnData) = actor.proxy(address(hub), abi.encodeCall(IHubBase.add, (targetAssetId, amount)));

        if (success) {
            _after();

            addedShares = uint256(abi.decode(returnData, (uint256)));

            assertGe(
                assetsBefore + amount,
                hub.getSpokeAddedAssets(cachedTargetAssetId, address(actor)),
                HSPOST_HUB_ERC4626_ADD_A
            );
            assertEq(
                sharesBefore + addedShares,
                hub.getSpokeAddedShares(cachedTargetAssetId, address(actor)),
                HSPOST_HUB_ERC4626_ADD_B
            );

            assertLe(previewAddedShares, addedShares, HSPOST_HUB_ERC4626_ADD_C);
        } else {
            revert("HubHandler: add failed");
        }
    }

    function remove(uint256 amount, uint8 i) public setup returns (uint256 removedShares) {
        bool success;
        bytes memory returnData;
        uint256 cachedTargetAssetId = targetAssetId = _getRandomBaseAssetId(i);

        uint256 previewRemovedShares = hub.previewRemoveByAssets(cachedTargetAssetId, amount);

        uint256 assetsBefore = hub.getSpokeAddedAssets(cachedTargetAssetId, address(actor));
        uint256 sharesBefore = hub.getSpokeAddedShares(cachedTargetAssetId, address(actor));

        _before();
        (success, returnData) =
            actor.proxy(address(hub), abi.encodeCall(IHubBase.remove, (cachedTargetAssetId, amount, address(actor))));

        if (success) {
            _after();

            removedShares = uint256(abi.decode(returnData, (uint256)));

            assertGe(
                assetsBefore,
                hub.getSpokeAddedAssets(cachedTargetAssetId, address(actor)) + amount,
                HSPOST_HUB_ERC4626_REMOVE_A
            );
            assertEq(
                sharesBefore,
                hub.getSpokeAddedShares(cachedTargetAssetId, address(actor)) + removedShares,
                HSPOST_HUB_ERC4626_REMOVE_B
            );

            assertGe(previewRemovedShares, removedShares, HSPOST_HUB_ERC4626_REMOVE_C);
        } else {
            revert("HubHandler: remove failed");
        }
    }

    function draw(uint256 amount, uint8 i) public setup returns (uint256 drawnShares) {
        bool success;
        bytes memory returnData;
        uint256 cachedTargetAssetId = targetAssetId = _getRandomBaseAssetId(i);

        uint256 previewDrawnShares = hub.previewDrawByAssets(cachedTargetAssetId, amount);

        (uint256 drawnBefore,) = hub.getSpokeOwed(cachedTargetAssetId, address(actor));
        uint256 sharesBefore = hub.getSpokeDrawnShares(cachedTargetAssetId, address(actor));

        _before();
        (success, returnData) =
            actor.proxy(address(hub), abi.encodeCall(IHubBase.draw, (cachedTargetAssetId, amount, address(actor))));

        if (success) {
            _after();

            drawnShares = uint256(abi.decode(returnData, (uint256)));

            (uint256 drawnAfter,) = hub.getSpokeOwed(cachedTargetAssetId, address(actor));

            assertGe(drawnBefore + amount, drawnAfter, HSPOST_HUB_ERC4626_DRAW_A);
            assertEq(
                sharesBefore + drawnShares,
                hub.getSpokeDrawnShares(cachedTargetAssetId, address(actor)),
                HSPOST_HUB_ERC4626_DRAW_B
            );

            assertGe(previewDrawnShares, drawnShares, HSPOST_HUB_ERC4626_DRAW_C);
        } else {
            revert("HubHandler: draw failed");
        }
    }

    function restore(uint256 drawnAmount, uint256 premiumAmount, int256 sharesDelta, uint8 i)
        public
        setup
        returns (uint256 restoredDrawnShares)
    {
        bool success;
        bytes memory returnData;
        uint256 cachedTargetAssetId = targetAssetId = _getRandomBaseAssetId(i);

        uint256 previewRestoredShares = hub.previewRestoreByAssets(cachedTargetAssetId, drawnAmount);

        (uint256 drawnBefore,) = hub.getSpokeOwed(cachedTargetAssetId, address(actor));
        uint256 drawnSharesBefore = hub.getSpokeDrawnShares(cachedTargetAssetId, address(actor));

        IHubBase.PremiumDelta memory premiumDelta = _calculatePremiumDelta(sharesDelta, premiumAmount, targetAssetId);

        _before();
        vm.prank(address(actor));
        IERC20(assetIdToUnderlying[cachedTargetAssetId]).transfer(address(hub), drawnAmount + premiumAmount);
        (success, returnData) = actor.proxy(
            address(hub), abi.encodeCall(IHubBase.restore, (cachedTargetAssetId, drawnAmount, premiumDelta))
        );

        if (success) {
            _after();

            restoredDrawnShares = uint256(abi.decode(returnData, (uint256)));

            (uint256 drawnAfter,) = hub.getSpokeOwed(cachedTargetAssetId, address(actor));

            assertEq(drawnBefore, drawnAfter + drawnAmount, HSPOST_HUB_ERC4626_RESTORE_A);
            assertEq(
                drawnSharesBefore,
                hub.getSpokeDrawnShares(cachedTargetAssetId, address(actor)) + restoredDrawnShares,
                HSPOST_HUB_ERC4626_RESTORE_B
            );

            assertLe(previewRestoredShares, restoredDrawnShares, HSPOST_HUB_ERC4626_RESTORE_C);
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

    function sweep(uint256 amount, uint8 i) external {
        targetAssetId = _getRandomBaseAssetId(i);

        _before();
        try hub.sweep(targetAssetId, amount) {
            _after();
        } catch {
            revert("HubHandler: sweep failed");
        }
    }

    function reclaim(uint256 amount, uint8 i) external {
        targetAssetId = _getRandomBaseAssetId(i);

        _before();
        try hub.reclaim(targetAssetId, amount) {
            _after();
        } catch {
            revert("HubHandler: reclaim failed");
        }
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                           ROUNDTRIP                                       //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function roundtrip_ERC4626_RT_A(uint256 amount, uint8 i) external {
        uint256 assetId = _getRandomBaseAssetId(i);

        uint256 previewSharesToAdd = hub.previewAddByAssets(assetId, amount);
        uint256 previewAssetsToRemove = hub.previewRemoveByShares(assetId, previewSharesToAdd);

        assertLe(previewAssetsToRemove, amount, HSPOST_HUB_ERC4626_RT_A);
    }

    function roundtrip_ERC4626_RT_B(uint256 amount, uint8 i) external {
        uint256 sharesAdded = add(amount, i);
        uint256 previewAssetsToRemove = hub.previewRemoveByShares(_getRandomBaseAssetId(i), sharesAdded);
        uint256 sharesRemoved = remove(previewAssetsToRemove, i);

        assertGe(sharesRemoved, sharesAdded, HSPOST_HUB_ERC4626_RT_B);
    }

    function roundtrip_ERC4626_RT_C(uint256 shares, uint8 i) external {
        uint256 assetId = _getRandomBaseAssetId(i);

        uint256 previewAssetsToRemove = hub.previewRemoveByShares(assetId, shares);
        uint256 previewShares = hub.previewAddByAssets(assetId, previewAssetsToRemove);

        assertLe(previewShares, shares, HSPOST_HUB_ERC4626_RT_C);
    }

    function roundtrip_ERC4626_RT_D(uint256 amount, uint8 i) external {
        uint256 sharesRemoved = remove(amount, i);
        uint256 previewAssetsToAdd = hub.previewAddByShares(_getRandomBaseAssetId(i), sharesRemoved);
        uint256 sharesAdded = add(previewAssetsToAdd, i);

        assertLe(sharesAdded, sharesRemoved, HSPOST_HUB_ERC4626_RT_D);
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
