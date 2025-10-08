// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Contracts
import {TestnetERC20} from "tests/mocks/TestnetERC20.sol";
import {IHub} from "src/hub/Hub.sol";
import {ITreasurySpoke} from "src/spoke/TreasurySpoke.sol";
import {ISpoke} from "src/spoke/Spoke.sol";
import {IAaveOracle} from "src/spoke/interfaces/IAaveOracle.sol";
import {AssetInterestRateStrategy} from "src/hub/AssetInterestRateStrategy.sol";
import {AccessManager} from "src/dependencies/openzeppelin/AccessManager.sol";

// Mock Contracts

// Test Contracts

// Utils
import {Actor} from "../utils/Actor.sol";

/// @notice BaseStorage contract for all test contracts, works in tandem with BaseTest
abstract contract BaseStorage {
    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                       CONSTANTS                                           //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    uint256 constant MAX_TOKEN_AMOUNT = 1e29;

    uint256 constant ONE_DAY = 1 days;
    uint256 constant ONE_MONTH = ONE_YEAR / 12;
    uint256 constant ONE_YEAR = 365 days;

    uint256 internal constant NUMBER_OF_ACTORS = 3;
    uint256 internal constant INITIAL_ETH_BALANCE = 1e26;
    uint256 internal constant INITIAL_COLL_BALANCE = 1e21;

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                          ACTORS                                           //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /// @notice The address of the admin, the tester itself
    address internal admin = address(this);

    /// @notice Stores the actor during a handler call
    Actor internal actor;

    /// @notice Mapping of fuzzer user addresses to actors
    mapping(address => Actor) internal actors;

    /// @notice Array of all actor addresses
    address[] internal actorAddresses;

    /// @notice The address that is targeted when executing an action (OPTIONAL)
    address internal targetActor;

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                       ASSETS STORAGE                                      //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /// @notice The USDC token
    TestnetERC20 internal usdc;
    /// @notice The WETH token
    TestnetERC20 internal weth;

    /// @notice The asset IDs of the USDC and WETH tokens
    uint256 internal usdcAssetId;
    uint256 internal wethAssetId;

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                       SUITE STORAGE                                       //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    // PROTOCOL CONTRACTS
    IHub internal hub;

    ITreasurySpoke internal treasurySpoke;
    ISpoke internal spoke1;
    ISpoke internal spoke2;

    // ORACLES
    IAaveOracle internal oracle1;
    IAaveOracle internal oracle2;

    // CONFIGURATION
    AssetInterestRateStrategy internal irStrategy;
    AccessManager internal accessManager;

    // MOCKS

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                       EXTRA VARIABLES                                     //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    // ASSETS
    /// @notice Array of base assets for the suite
    AssetInfo[] internal baseAssets;

    // SPOKES
    /// @notice Array of spokes addresses for the suite
    address[] internal spokesAddresses;
    /// @notice Spoke configurations
    mapping(ISpoke => SpokeInfo) internal spokeInfo;
    /// @notice Spoke reserveIds
    mapping(address => uint256[]) internal spokeReserveIds;
    /// @notice Spoke reserveIds to global assetIds
    mapping(address => mapping(uint256 => uint256)) internal reserveIdToAssetId;
    /// @notice Spoke assetIds to reserveIds info
    mapping(address => mapping(uint256 => uint256)) internal assetIdToReserveId;

    // PRICE FEEDS
    address[] internal priceFeeds;

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                          STRUCTS                                          //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    struct SpokeInfo {
        ReserveInfo weth;
        ReserveInfo usdc;
        uint256 MAX_ALLOWED_ASSET_ID;
    }

    struct ReserveInfo {
        uint256 reserveId;
        ISpoke.ReserveConfig reserveConfig;
        ISpoke.DynamicReserveConfig dynReserveConfig;
    }

    struct AssetInfo {
        uint256 assetId;
        address underlying;
        uint8 decimals;
    }
}
