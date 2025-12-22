// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Interfaces
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {IHubConfiguratorHandler} from "./interfaces/IHubConfiguratorHandler.sol";

// Libraries
import "forge-std/console.sol";

// Test Contracts
import {Actor} from "../../shared/utils/Actor.sol";
import {BaseHandler} from "../base/BaseHandler.t.sol";

/// @title HubConfiguratorHandler
/// @notice Handler test contract for a set of actions
contract HubConfiguratorHandler is BaseHandler, IHubConfiguratorHandler {
    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                      STATE VARIABLES                                      //
    ///////////////////////////////////////////////////////////////////////////////////////////////
    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                          ACTIONS                                          //
    ///////////////////////////////////////////////////////////////////////////////////////////////
    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                         OWNER ACTIONS                                     //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function updateSpokeSupplyCap(uint256 addCap, uint8 i, uint8 j) external setup {
        uint256 assetId = _getRandomBaseAssetId(i);
        address spoke = _getRandomActor(j);
        hubConfigurator.updateSpokeSupplyCap(address(hub), assetId, spoke, addCap);
    }

    function updateSpokeDrawCap(uint256 drawCap, uint8 i, uint8 j) external setup {
        uint256 assetId = _getRandomBaseAssetId(i);
        address spoke = _getRandomActor(j);
        hubConfigurator.updateSpokeDrawCap(address(hub), assetId, spoke, drawCap);
    }

    function updateSpokeRiskPremiumCap(uint256 riskPremiumCap, uint8 i, uint8 j) external setup {
        uint256 assetId = _getRandomBaseAssetId(i);
        address spoke = _getRandomActor(j);
        hubConfigurator.updateSpokeRiskPremiumCap(address(hub), assetId, spoke, riskPremiumCap);
    }

    function updateSpokePaused(bool paused, uint8 i, uint8 j) external setup {
        uint256 assetId = _getRandomBaseAssetId(i);
        address spoke = _getRandomActor(j);
        hubConfigurator.updateSpokePaused(address(hub), assetId, spoke, paused);
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                           HELPERS                                         //
    ///////////////////////////////////////////////////////////////////////////////////////////////
}
