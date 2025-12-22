// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Interfaces
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {IHub, IHubBase} from "src/hub/Hub.sol";
import {IHubHandler} from "./interfaces/IHubHandler.sol";

// Libraries
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
        uint256 assetId = _getRandomBaseAssetId(i);
        address underlying = assetIdToUnderlying[assetId];

        _before();
        vm.prank(address(actor));
        IERC20(underlying).transfer(address(hub), amount);
        (success, returnData) = actor.proxy(address(hub), abi.encodeCall(IHubBase.add, (assetId, amount)));

        if (success) {
            _after();
        } else {
            revert("HubHandler: add failed");
        }
    }

    function remove(uint256 amount, uint8 i) external setup {
        bool success;
        bytes memory returnData;
        uint256 assetId = _getRandomBaseAssetId(i);

        _before();
        (success, returnData) =
            actor.proxy(address(hub), abi.encodeCall(IHubBase.remove, (assetId, amount, address(actor))));

        if (success) {
            _after();
        } else {
            revert("HubHandler: remove failed");
        }
    }

    function draw(uint256 amount, uint8 i) external setup {
        bool success;
        bytes memory returnData;
        uint256 assetId = _getRandomBaseAssetId(i);

        _before();
        (success, returnData) =
            actor.proxy(address(hub), abi.encodeCall(IHubBase.draw, (assetId, amount, address(actor))));

        if (success) {
            _after();
        } else {
            revert("HubHandler: draw failed");
        }
    }

    function restore(uint256 drawnAmount, uint256 premiumAmount, IHubBase.PremiumDelta calldata premiumDelta, uint8 i)
        external
        setup
    {
        bool success;
        bytes memory returnData;
        uint256 assetId = _getRandomBaseAssetId(i);
        address underlying = assetIdToUnderlying[assetId];

        _before();
        vm.prank(address(actor));
        IERC20(underlying).transfer(address(hub), drawnAmount + premiumAmount);
        (success, returnData) =
            actor.proxy(address(hub), abi.encodeCall(IHubBase.restore, (assetId, drawnAmount, premiumDelta)));

        if (success) {
            _after();
        } else {
            revert("HubHandler: restore failed");
        }
    }

    function reportDeficit(uint256 drawnAmount, IHubBase.PremiumDelta calldata premiumDelta, uint8 i) external setup {
        bool success;
        bytes memory returnData;
        uint256 assetId = _getRandomBaseAssetId(i);

        _before();
        (success, returnData) =
            actor.proxy(address(hub), abi.encodeCall(IHubBase.reportDeficit, (assetId, drawnAmount, premiumDelta)));

        if (success) {
            _after();
        } else {
            revert("HubHandler: reportDeficit failed");
        }
    }

    function eliminateDeficit(uint256 amount, uint8 i, uint8 j) external setup {
        bool success;
        bytes memory returnData;
        uint256 assetId = _getRandomBaseAssetId(i);
        address spoke = _getRandomActor(j);

        _before();
        (success, returnData) =
            actor.proxy(address(hub), abi.encodeCall(IHub.eliminateDeficit, (assetId, amount, spoke)));

        if (success) {
            _after();
        } else {
            revert("HubHandler: eliminateDeficit failed");
        }
    }

    function refreshPremium(IHubBase.PremiumDelta calldata premiumDelta, uint8 i) external setup {
        bool success;
        bytes memory returnData;
        uint256 assetId = _getRandomBaseAssetId(i);

        _before();
        (success, returnData) =
            actor.proxy(address(hub), abi.encodeCall(IHubBase.refreshPremium, (assetId, premiumDelta)));

        if (success) {
            _after();
        } else {
            revert("HubHandler: refreshPremium failed");
        }
    }

    function payFeeShares(uint256 shares, uint8 i) external setup {
        bool success;
        bytes memory returnData;
        uint256 assetId = _getRandomBaseAssetId(i);

        _before();
        (success, returnData) = actor.proxy(address(hub), abi.encodeCall(IHubBase.payFeeShares, (assetId, shares)));
        if (success) {
            _after();
        } else {
            revert("HubHandler: payFeeShares failed");
        }
    }

    function transferShares(uint256 shares, uint8 i, uint8 j) external setup {
        bool success;
        bytes memory returnData;
        uint256 assetId = _getRandomBaseAssetId(i);
        address toSpoke = _getRandomActor(j);

        _before();
        (success, returnData) =
            actor.proxy(address(hub), abi.encodeCall(IHub.transferShares, (assetId, shares, toSpoke)));

        if (success) {
            _after();
        } else {
            revert("HubHandler: transferShares failed");
        }
    }

    function sweep(uint256 amount, uint8 i) external setup {
        bool success;
        bytes memory returnData;
        uint256 assetId = _getRandomBaseAssetId(i);

        _before();
        (success, returnData) = actor.proxy(address(hub), abi.encodeCall(IHub.sweep, (assetId, amount)));
        if (success) {
            _after();
        } else {
            revert("HubHandler: sweep failed");
        }
    }

    function reclaim(uint256 amount, uint8 i) external setup {
        bool success;
        bytes memory returnData;
        uint256 assetId = _getRandomBaseAssetId(i);
        _before();
        (success, returnData) = actor.proxy(address(hub), abi.encodeCall(IHub.reclaim, (assetId, amount)));
        if (success) {
            _after();
        } else {
            revert("HubHandler: reclaim failed");
        }
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                           HELPERS                                         //
    ///////////////////////////////////////////////////////////////////////////////////////////////
}
