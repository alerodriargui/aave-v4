// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Libraries
import {CREATE3} from "../shared/utils/CREATE3.sol";
import {ActorsUtils} from "../shared/utils/ActorsUtils.sol";
import {Constants} from "tests/Constants.sol";
import {Roles} from "src/libraries/types/Roles.sol";
import "forge-std/console.sol";

// Interfaces
import {IAaveOracle} from "src/spoke/interfaces/IAaveOracle.sol";
import {ISpoke} from "src/spoke/Spoke.sol";
import {ITreasurySpoke} from "src/spoke/TreasurySpoke.sol";
import {IHub} from "src/hub/Hub.sol";

// Test Contracts
import {Actor} from "../shared/utils/Actor.sol";
import {TestnetERC20} from "tests/mocks/TestnetERC20.sol";
import {MockPriceFeedSimulator} from "../shared/mocks/MockPriceFeedSimulator.sol";

// Contracts
import {BaseTest} from "./base/BaseTest.t.sol";
import {AssetInterestRateStrategy} from "src/hub/AssetInterestRateStrategy.sol";
import {IAssetInterestRateStrategy} from "src/hub/interfaces/IAssetInterestRateStrategy.sol";
import {AccessManager} from "src/dependencies/openzeppelin/AccessManager.sol";
import {Hub} from "src/hub/Hub.sol";
import {TreasurySpoke} from "src/spoke/TreasurySpoke.sol";
import {SpokeInstance} from "src/spoke/instances/SpokeInstance.sol";
import {Spoke} from "src/spoke/Spoke.sol";
import {TransparentUpgradeableProxy} from "src/dependencies/openzeppelin/TransparentUpgradeableProxy.sol";
import {AaveOracle} from "src/spoke/AaveOracle.sol";
import {HubConfigurator} from "src/hub/HubConfigurator.sol";
import {SpokeConfigurator} from "src/spoke/SpokeConfigurator.sol";

/// @notice Setup contract for the invariant test Suite, inherited by Tester
contract Setup is BaseTest {
    /// @notice Number of actors to deploy
    function _setUp() internal {
        // Deploy the suite assets
        _deployAssets();

        // Deploy protocol contracts and protocol actors
        _deployProtocolCore();

        // Configure the token list on the protocol
        _configureTokenList();

        // Deploy actors
        _setUpActors();
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                          ASSETS                                           //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /// @notice Deploy the suite assets
    function _deployAssets() internal {
        usdc = new TestnetERC20("USDC", "USDC", 6);
        weth = new TestnetERC20("WETH", "WETH", 18);

        baseAssets.push(AssetInfo({underlying: address(usdc), decimals: 6}));
        baseAssets.push(AssetInfo({underlying: address(weth), decimals: 18}));

        vm.label(address(usdc), "usdc");
        vm.label(address(weth), "weth");
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                          CORE                                             //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /// @notice Deploy protocol core contracts
    function _deployProtocolCore() internal {
        // Access manager
        accessManager = new AccessManager(admin);

        // Hub 1
        hub1 = new Hub(address(accessManager));
        irStrategy1 = new AssetInterestRateStrategy(address(hub1));
        hubInfo[address(hub1)] = HubInfo({treasurySpoke: address(treasurySpoke1), irStrategy: address(irStrategy1)});
        hubAddresses.push(address(hub1));

        // Hub 2
        hub2 = new Hub(address(accessManager));
        irStrategy2 = new AssetInterestRateStrategy(address(hub2));
        hubInfo[address(hub2)] = HubInfo({treasurySpoke: address(treasurySpoke2), irStrategy: address(irStrategy2)});
        hubAddresses.push(address(hub2));

        // Spokes
        (spoke1, oracle1) = _deploySpokeWithOracle(admin, address(accessManager), "Spoke 1 (USD)");
        (spoke2, oracle2) = _deploySpokeWithOracle(admin, address(accessManager), "Spoke 2 (USD)");
        treasurySpoke1 = ITreasurySpoke(new TreasurySpoke(admin, address(hub1)));
        treasurySpoke2 = ITreasurySpoke(new TreasurySpoke(admin, address(hub2)));
        allSpokes.push(address(treasurySpoke1));
        allSpokes.push(address(treasurySpoke2));

        // Configurators
        hubConfigurator = new HubConfigurator(admin);
        spokeConfigurator = new SpokeConfigurator(admin);
        _setUpConfiguratorRoles();

        vm.label(address(accessManager), "accessManager");
        vm.label(address(hub1), "hub1");
        vm.label(address(hub2), "hub2");
        vm.label(address(hubConfigurator), "hubConfigurator");
        vm.label(address(spokeConfigurator), "spokeConfigurator");
        vm.label(address(irStrategy1), "irStrategy1");
        vm.label(address(irStrategy2), "irStrategy2");
        vm.label(address(spoke1), "spoke1");
        vm.label(address(spoke2), "spoke2");
        vm.label(address(treasurySpoke1), "treasurySpoke1");
        vm.label(address(treasurySpoke2), "treasurySpoke2");
        vm.label(address(oracle1), "oracle1");
        vm.label(address(oracle2), "oracle2");
    }

    /// @notice Deploy a spoke with an oracle using CREATE3
    function _deploySpokeWithOracle(address proxyAdminOwner, address _accessManager, string memory _oracleDesc)
        internal
        returns (ISpoke, IAaveOracle)
    {
        bytes32 salt = keccak256(abi.encodePacked(_oracleDesc));
        address predictedSpoke = CREATE3.predictDeterministicAddress(salt, admin);

        // Deploy oracle with predicted spoke address
        IAaveOracle oracle = new AaveOracle(predictedSpoke, uint8(8), _oracleDesc);

        // Deploy spoke implementation with oracle address
        address spokeImpl = address(new SpokeInstance(address(oracle)));

        // Deploy spoke proxy using CREATE3
        bytes memory proxyCreationCode = abi.encodePacked(
            type(TransparentUpgradeableProxy).creationCode,
            abi.encode(spokeImpl, proxyAdminOwner, abi.encodeCall(Spoke.initialize, (_accessManager)))
        );
        address spokeProxy = CREATE3.deployDeterministic(proxyCreationCode, salt);
        ISpoke spoke = ISpoke(spokeProxy);

        assertEq(address(spoke), predictedSpoke, "predictedSpoke mismatch");
        assertEq(spoke.ORACLE(), address(oracle), "spoke.ORACLE() mismatch");
        assertEq(oracle.SPOKE(), address(spoke), "oracle.SPOKE() mismatch");

        spokesAddresses.push(address(spoke));
        allSpokes.push(address(spoke));

        return (spoke, oracle);
    }

    /// @notice Proxify an implementation contract using TransparentUpgradeableProxy
    function _proxify(address impl, address proxyAdminOwner, bytes memory initData) internal returns (address) {
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(impl, proxyAdminOwner, initData);
        return address(proxy);
    }

    function _deployMockPriceFeed(ISpoke spoke, uint256 price) internal returns (address) {
        AaveOracle oracle = AaveOracle(spoke.ORACLE());
        return address(new MockPriceFeedSimulator(oracle.DECIMALS(), oracle.DESCRIPTION(), price));
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                          CONFIGS                                          //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function _configureTokenList() internal {
        // Configure hubs
        _configureHubs();

        // Configure spokes
        _configureSpokes();
    }

    /// @notice Configure the hubs
    function _configureHubs() internal {
        // HUB 1
        bytes memory encodedIrData1 = abi.encode(
            IAssetInterestRateStrategy.InterestRateData({
                optimalUsageRatio: OPTIMAL_USAGE_RATIO_IR1,
                baseVariableBorrowRate: BASE_VARIABLE_BORROW_RATE_IR1,
                variableRateSlope1: VARIABLE_RATE_SLOPE_1_IR1,
                variableRateSlope2: VARIABLE_RATE_SLOPE_2_IR1
            })
        );

        // Add USDC
        hub1UsdcAssetId = hub1.addAsset(
            address(usdc), usdc.decimals(), address(treasurySpoke1), address(irStrategy1), encodedIrData1
        );
        hub1.updateAssetConfig(
            hub1UsdcAssetId,
            IHub.AssetConfig({
                liquidityFee: 5_00,
                feeReceiver: address(treasurySpoke1),
                irStrategy: address(irStrategy1),
                reinvestmentController: address(0)
            }),
            new bytes(0)
        );
        hubAssetIds[address(hub1)].push(hub1UsdcAssetId);

        // Add WETH
        hub1WethAssetId = hub1.addAsset(
            address(weth), weth.decimals(), address(treasurySpoke1), address(irStrategy1), encodedIrData1
        );
        hub1.updateAssetConfig(
            hub1WethAssetId,
            IHub.AssetConfig({
                liquidityFee: 10_00,
                feeReceiver: address(treasurySpoke1),
                irStrategy: address(irStrategy1),
                reinvestmentController: address(0)
            }),
            new bytes(0)
        );
        hubAssetIds[address(hub1)].push(hub1WethAssetId);

        // HUB 2
        bytes memory encodedIrData2 = abi.encode(
            IAssetInterestRateStrategy.InterestRateData({
                optimalUsageRatio: OPTIMAL_USAGE_RATIO_IR2,
                baseVariableBorrowRate: BASE_VARIABLE_BORROW_RATE_IR2,
                variableRateSlope1: VARIABLE_RATE_SLOPE_1_IR2,
                variableRateSlope2: VARIABLE_RATE_SLOPE_2_IR2
            })
        );

        // Add WETH
        hub2WethAssetId = hub2.addAsset(
            address(weth), weth.decimals(), address(treasurySpoke2), address(irStrategy2), encodedIrData2
        );
        hub2.updateAssetConfig(
            hub2WethAssetId,
            IHub.AssetConfig({
                liquidityFee: 10_00,
                feeReceiver: address(treasurySpoke2),
                irStrategy: address(irStrategy2),
                reinvestmentController: address(0)
            }),
            new bytes(0)
        );
        hubAssetIds[address(hub2)].push(hub2WethAssetId);

        // Add USDC
        hub2UsdcAssetId = hub2.addAsset(
            address(usdc), usdc.decimals(), address(treasurySpoke2), address(irStrategy2), encodedIrData2
        );
        hub2.updateAssetConfig(
            hub2UsdcAssetId,
            IHub.AssetConfig({
                liquidityFee: 5_00,
                feeReceiver: address(treasurySpoke2),
                irStrategy: address(irStrategy2),
                reinvestmentController: address(0)
            }),
            new bytes(0)
        );
        hubAssetIds[address(hub2)].push(hub2UsdcAssetId);
    }

    function _configureSpokes() internal {
        // Configure spoke liquidation configs
        spokeConfigurator.updateLiquidationTargetHealthFactor(address(spoke1), TARGET_HEALTH_FACTOR_SPOKE1);
        spokeConfigurator.updateLiquidationTargetHealthFactor(address(spoke2), TARGET_HEALTH_FACTOR_SPOKE2);

        // Spoke 1 reserve configs
        spokeInfo[spoke1].usdc.reserveConfig = ISpoke.ReserveConfig({
            paused: false,
            frozen: false,
            borrowable: true,
            liquidatable: true,
            receiveSharesEnabled: true,
            collateralRisk: 30_00
        });
        spokeInfo[spoke1].usdc.dynReserveConfig =
            ISpoke.DynamicReserveConfig({collateralFactor: 90_00, maxLiquidationBonus: 100_00, liquidationFee: 0});

        spokeInfo[spoke1].weth.reserveConfig = ISpoke.ReserveConfig({
            paused: false,
            frozen: false,
            borrowable: true,
            liquidatable: true,
            receiveSharesEnabled: true,
            collateralRisk: 20_00
        });
        spokeInfo[spoke1].weth.dynReserveConfig =
            ISpoke.DynamicReserveConfig({collateralFactor: 80_00, maxLiquidationBonus: 105_00, liquidationFee: 0});

        // Spoke 2 reserve configs
        spokeInfo[spoke2].weth.reserveConfig = ISpoke.ReserveConfig({
            paused: false,
            frozen: false,
            borrowable: true,
            liquidatable: true,
            receiveSharesEnabled: true,
            collateralRisk: 10_00
        });
        spokeInfo[spoke2].weth.dynReserveConfig =
            ISpoke.DynamicReserveConfig({collateralFactor: 70_00, maxLiquidationBonus: 105_00, liquidationFee: 0});

        spokeInfo[spoke2].usdc.reserveConfig = ISpoke.ReserveConfig({
            paused: false,
            frozen: false,
            borrowable: true,
            liquidatable: true,
            receiveSharesEnabled: true,
            collateralRisk: 15_00
        });
        spokeInfo[spoke2].usdc.dynReserveConfig =
            ISpoke.DynamicReserveConfig({collateralFactor: 80_00, maxLiquidationBonus: 100_00, liquidationFee: 0});

        // Deploy price feeds
        priceFeeds.push(_deployMockPriceFeed(spoke1, 1e8));
        priceFeeds.push(_deployMockPriceFeed(spoke1, 2000e8));

        // Add reserves to spoke 1
        spokeInfo[spoke1].usdc.reserveId = spoke1.addReserve(
            address(hub1),
            hub1UsdcAssetId,
            priceFeeds[0],
            spokeInfo[spoke1].usdc.reserveConfig,
            spokeInfo[spoke1].usdc.dynReserveConfig
        );
        spokeInfo[spoke1].usdc2.reserveId = spoke1.addReserve(
            address(hub2),
            hub2UsdcAssetId,
            priceFeeds[0],
            spokeInfo[spoke1].usdc.reserveConfig,
            spokeInfo[spoke1].usdc.dynReserveConfig
        );
        spokeInfo[spoke1].weth.reserveId = spoke1.addReserve(
            address(hub1),
            hub1WethAssetId,
            priceFeeds[1],
            spokeInfo[spoke1].weth.reserveConfig,
            spokeInfo[spoke1].weth.dynReserveConfig
        );
        spokeInfo[spoke1].weth2.reserveId = spoke1.addReserve(
            address(hub2),
            hub2WethAssetId,
            priceFeeds[1],
            spokeInfo[spoke1].weth.reserveConfig,
            spokeInfo[spoke1].weth.dynReserveConfig
        );

        // Add reserves to spoke 2
        spokeInfo[spoke2].weth.reserveId = spoke2.addReserve(
            address(hub1),
            hub1WethAssetId,
            priceFeeds[1],
            spokeInfo[spoke2].weth.reserveConfig,
            spokeInfo[spoke2].weth.dynReserveConfig
        );
        spokeInfo[spoke2].weth2.reserveId = spoke2.addReserve(
            address(hub2),
            hub2WethAssetId,
            priceFeeds[1],
            spokeInfo[spoke2].weth.reserveConfig,
            spokeInfo[spoke2].weth.dynReserveConfig
        );
        spokeInfo[spoke2].usdc.reserveId = spoke2.addReserve(
            address(hub1),
            hub1UsdcAssetId,
            priceFeeds[0],
            spokeInfo[spoke2].usdc.reserveConfig,
            spokeInfo[spoke2].usdc.dynReserveConfig
        );
        spokeInfo[spoke2].usdc2.reserveId = spoke2.addReserve(
            address(hub2),
            hub2UsdcAssetId,
            priceFeeds[0],
            spokeInfo[spoke2].usdc.reserveConfig,
            spokeInfo[spoke2].usdc.dynReserveConfig
        );

        // Map ids for spoke 1
        assetIdToReserveId[address(spoke1)][hub1UsdcAssetId] = spokeInfo[spoke1].usdc.reserveId;
        assetIdToReserveId[address(spoke1)][hub2UsdcAssetId] = spokeInfo[spoke1].usdc2.reserveId;
        assetIdToReserveId[address(spoke1)][hub1WethAssetId] = spokeInfo[spoke1].weth.reserveId;
        assetIdToReserveId[address(spoke1)][hub2WethAssetId] = spokeInfo[spoke1].weth2.reserveId;
        reserveIdToAssetId[address(spoke1)][spokeInfo[spoke1].usdc.reserveId] = hub1UsdcAssetId;
        reserveIdToAssetId[address(spoke1)][spokeInfo[spoke1].usdc2.reserveId] = hub2UsdcAssetId;
        reserveIdToAssetId[address(spoke1)][spokeInfo[spoke1].weth.reserveId] = hub1WethAssetId;
        reserveIdToAssetId[address(spoke1)][spokeInfo[spoke1].weth2.reserveId] = hub2WethAssetId;
        reserveIdToHubAddress[address(spoke1)][spokeInfo[spoke1].usdc.reserveId] = address(hub1);
        reserveIdToHubAddress[address(spoke1)][spokeInfo[spoke1].usdc2.reserveId] = address(hub2);
        reserveIdToHubAddress[address(spoke1)][spokeInfo[spoke1].weth.reserveId] = address(hub1);
        reserveIdToHubAddress[address(spoke1)][spokeInfo[spoke1].weth2.reserveId] = address(hub2);

        // Map ids for spoke 2
        assetIdToReserveId[address(spoke2)][hub1UsdcAssetId] = spokeInfo[spoke2].usdc.reserveId;
        assetIdToReserveId[address(spoke2)][hub2UsdcAssetId] = spokeInfo[spoke2].usdc2.reserveId;
        assetIdToReserveId[address(spoke2)][hub1WethAssetId] = spokeInfo[spoke2].weth.reserveId;
        assetIdToReserveId[address(spoke2)][hub2WethAssetId] = spokeInfo[spoke2].weth2.reserveId;
        reserveIdToAssetId[address(spoke2)][spokeInfo[spoke2].usdc.reserveId] = hub1UsdcAssetId;
        reserveIdToAssetId[address(spoke2)][spokeInfo[spoke2].usdc2.reserveId] = hub2UsdcAssetId;
        reserveIdToAssetId[address(spoke2)][spokeInfo[spoke2].weth.reserveId] = hub1WethAssetId;
        reserveIdToAssetId[address(spoke2)][spokeInfo[spoke2].weth2.reserveId] = hub2WethAssetId;
        reserveIdToHubAddress[address(spoke2)][spokeInfo[spoke2].usdc.reserveId] = address(hub1);
        reserveIdToHubAddress[address(spoke2)][spokeInfo[spoke2].usdc2.reserveId] = address(hub2);
        reserveIdToHubAddress[address(spoke2)][spokeInfo[spoke2].weth.reserveId] = address(hub1);
        reserveIdToHubAddress[address(spoke2)][spokeInfo[spoke2].weth2.reserveId] = address(hub2);

        // Store spoke reserve ids on array
        spokeReserveIds[address(spoke1)].push(spokeInfo[spoke1].usdc.reserveId);
        spokeReserveIds[address(spoke1)].push(spokeInfo[spoke1].usdc2.reserveId);
        spokeReserveIds[address(spoke1)].push(spokeInfo[spoke1].weth.reserveId);
        spokeReserveIds[address(spoke1)].push(spokeInfo[spoke1].weth2.reserveId);
        spokeReserveIds[address(spoke2)].push(spokeInfo[spoke2].usdc.reserveId);
        spokeReserveIds[address(spoke2)].push(spokeInfo[spoke2].usdc2.reserveId);
        spokeReserveIds[address(spoke2)].push(spokeInfo[spoke2].weth.reserveId);
        spokeReserveIds[address(spoke2)].push(spokeInfo[spoke2].weth2.reserveId);

        // TreasurySpoke uses assetIds directly as reserveIds
        spokeReserveIds[address(treasurySpoke1)].push(hub1UsdcAssetId);
        spokeReserveIds[address(treasurySpoke1)].push(hub1WethAssetId);
        spokeReserveIds[address(treasurySpoke2)].push(hub2UsdcAssetId);
        spokeReserveIds[address(treasurySpoke2)].push(hub2WethAssetId);

        // Add SPOKE 1 assets to hubs
        hub1.addSpoke(
            hub1UsdcAssetId,
            address(spoke1),
            IHub.SpokeConfig({
                addCap: Constants.MAX_ALLOWED_SPOKE_CAP,
                drawCap: Constants.MAX_ALLOWED_SPOKE_CAP,
                riskPremiumThreshold: Constants.MAX_RISK_PREMIUM_THRESHOLD,
                active: true,
                paused: false
            })
        );
        hub2.addSpoke(
            hub2UsdcAssetId,
            address(spoke1),
            IHub.SpokeConfig({
                addCap: Constants.MAX_ALLOWED_SPOKE_CAP / 10 * 3,
                drawCap: Constants.MAX_ALLOWED_SPOKE_CAP / 10 * 3,
                riskPremiumThreshold: Constants.MAX_RISK_PREMIUM_THRESHOLD,
                active: true,
                paused: false
            })
        );
        hub1.addSpoke(
            hub1WethAssetId,
            address(spoke1),
            IHub.SpokeConfig({
                addCap: Constants.MAX_ALLOWED_SPOKE_CAP,
                drawCap: Constants.MAX_ALLOWED_SPOKE_CAP,
                riskPremiumThreshold: Constants.MAX_RISK_PREMIUM_THRESHOLD,
                active: true,
                paused: false
            })
        );
        hub2.addSpoke(
            hub2WethAssetId,
            address(spoke1),
            IHub.SpokeConfig({
                addCap: Constants.MAX_ALLOWED_SPOKE_CAP / 10 * 2,
                drawCap: Constants.MAX_ALLOWED_SPOKE_CAP / 10 * 2,
                riskPremiumThreshold: Constants.MAX_RISK_PREMIUM_THRESHOLD,
                active: true,
                paused: false
            })
        );

        // Add SPOKE 2 assets to hubs
        hub2.addSpoke(
            hub2WethAssetId,
            address(spoke2),
            IHub.SpokeConfig({
                addCap: Constants.MAX_ALLOWED_SPOKE_CAP,
                drawCap: Constants.MAX_ALLOWED_SPOKE_CAP,
                riskPremiumThreshold: Constants.MAX_RISK_PREMIUM_THRESHOLD,
                active: true,
                paused: false
            })
        );
        hub1.addSpoke(
            hub1WethAssetId,
            address(spoke2),
            IHub.SpokeConfig({
                addCap: Constants.MAX_ALLOWED_SPOKE_CAP / 10 * 2,
                drawCap: Constants.MAX_ALLOWED_SPOKE_CAP / 10 * 2,
                riskPremiumThreshold: Constants.MAX_RISK_PREMIUM_THRESHOLD,
                active: true,
                paused: false
            })
        );
        hub2.addSpoke(
            hub2UsdcAssetId,
            address(spoke2),
            IHub.SpokeConfig({
                addCap: Constants.MAX_ALLOWED_SPOKE_CAP,
                drawCap: Constants.MAX_ALLOWED_SPOKE_CAP,
                riskPremiumThreshold: Constants.MAX_RISK_PREMIUM_THRESHOLD,
                active: true,
                paused: false
            })
        );
        hub1.addSpoke(
            hub1UsdcAssetId,
            address(spoke2),
            IHub.SpokeConfig({
                addCap: Constants.MAX_ALLOWED_SPOKE_CAP / 10 * 3,
                drawCap: Constants.MAX_ALLOWED_SPOKE_CAP / 10 * 3,
                riskPremiumThreshold: Constants.MAX_RISK_PREMIUM_THRESHOLD,
                active: true,
                paused: false
            })
        );
    }

    /// @notice Set up roles for the configurators
    function _setUpConfiguratorRoles() internal virtual {
        // Grant roles to configurators
        accessManager.grantRole(Roles.HUB_ADMIN_ROLE, address(hubConfigurator), 0);
        accessManager.grantRole(Roles.SPOKE_ADMIN_ROLE, address(spokeConfigurator), 0);

        // Grant responsibilities to spokes
        {
            bytes4[] memory selectors = new bytes4[](6);
            selectors[0] = ISpoke.updateLiquidationConfig.selector;
            selectors[1] = ISpoke.updateReserveConfig.selector;
            selectors[2] = ISpoke.updateDynamicReserveConfig.selector;
            selectors[3] = ISpoke.addDynamicReserveConfig.selector;
            selectors[4] = ISpoke.updatePositionManager.selector;
            selectors[5] = ISpoke.updateReservePriceSource.selector;
            accessManager.setTargetFunctionRole(address(spoke1), selectors, Roles.SPOKE_ADMIN_ROLE);
            accessManager.setTargetFunctionRole(address(spoke2), selectors, Roles.SPOKE_ADMIN_ROLE);
        }

        // Grant responsibilities to hubs
        {
            bytes4[] memory selectors = new bytes4[](2);
            selectors[0] = IHub.updateSpokeConfig.selector;
            selectors[1] = IHub.setInterestRateData.selector;
            accessManager.setTargetFunctionRole(address(hub1), selectors, Roles.HUB_ADMIN_ROLE);
            accessManager.setTargetFunctionRole(address(hub2), selectors, Roles.HUB_ADMIN_ROLE);
        }
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                           ACTORS                                          //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /// @notice Deploy protocol actors and initialize their balances
    function _setUpActors() internal {
        // Initialize the three actors of the fuzzers
        address[] memory addresses = new address[](3);
        addresses[0] = USER1;
        addresses[1] = USER2;
        addresses[2] = USER3;

        // Initialize the tokens array
        address[] memory tokens = new address[](2);
        tokens[0] = address(usdc);
        tokens[1] = address(weth);

        address[] memory contracts = new address[](4);
        contracts[0] = address(hub1);
        contracts[1] = address(hub2);
        contracts[2] = address(spoke1);
        contracts[3] = address(spoke2);

        actorAddresses = ActorsUtils.setUpActors(addresses, tokens, contracts);
        actors[USER1] = Actor(payable(actorAddresses[0]));
        actors[USER2] = Actor(payable(actorAddresses[1]));
        actors[USER3] = Actor(payable(actorAddresses[2]));
    }
}
