// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Libraries
import {CREATE3} from "./utils/CREATE3.sol";
import {Constants} from "tests/Constants.sol";

// Interfaces
import {IAaveOracle} from "src/spoke/interfaces/IAaveOracle.sol";
import {ISpoke} from "src/spoke/Spoke.sol";
import {ITreasurySpoke} from "src/spoke/TreasurySpoke.sol";
import {IHub} from "src/hub/Hub.sol";

// Test Contracts
import {Actor} from "./utils/Actor.sol";
import {TestnetERC20} from "tests/mocks/TestnetERC20.sol";
import {MockPriceFeedSimulator} from "tests/enigma-dark-invariants/utils/mocks/MockPriceFeedSimulator.sol";

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
        usdcAssetId = 0;
        wethAssetId = 1;

        baseAssets.push(AssetInfo({assetId: usdcAssetId, underlying: address(usdc), decimals: 6}));
        baseAssets.push(AssetInfo({assetId: wethAssetId, underlying: address(weth), decimals: 18}));

        vm.label(address(usdc), "usdc");
        vm.label(address(weth), "weth");
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                          CORE                                             //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /// @notice Deploy protocol core contracts
    function _deployProtocolCore() internal {
        accessManager = new AccessManager(admin);
        hub = new Hub(address(accessManager));

        irStrategy = new AssetInterestRateStrategy(address(hub));
        (spoke1, oracle1) = _deploySpokeWithOracle(admin, address(accessManager), "Spoke 1 (USD)");
        (spoke2, oracle2) = _deploySpokeWithOracle(admin, address(accessManager), "Spoke 2 (USD)");
        spokesAddresses.push(address(spoke1)); // TODO integrate spoke 2 and treasury spoke
        treasurySpoke = ITreasurySpoke(new TreasurySpoke(admin, address(hub)));

        vm.label(address(spoke1), "spoke1");
        vm.label(address(spoke2), "spoke2");
        vm.label(address(treasurySpoke), "treasurySpoke");
        vm.label(address(irStrategy), "irStrategy");
        vm.label(address(accessManager), "accessManager");
        vm.label(address(hub), "hub");
    }

    /// @notice Deploy a spoke with an oracle using CREATE3
    function _deploySpokeWithOracle(address proxyAdminOwner, address _accessManager, string memory _oracleDesc)
        internal
        returns (ISpoke, IAaveOracle)
    {
        bytes32 salt = keccak256(abi.encodePacked(_oracleDesc));
        address predictedOracle = CREATE3.predictDeterministicAddress(salt, admin);
        address spokeImpl = address(new SpokeInstance(predictedOracle));

        ISpoke spoke = ISpoke(_proxify(spokeImpl, proxyAdminOwner, abi.encodeCall(Spoke.initialize, (_accessManager))));
        IAaveOracle oracle = IAaveOracle(
            CREATE3.deployDeterministic(
                abi.encodePacked(type(AaveOracle).creationCode, abi.encode(address(spoke), uint8(8), _oracleDesc)), salt
            )
        );
        assertEq(address(oracle), predictedOracle, "predictedOracle mismatch");
        assertEq(spoke.ORACLE(), address(oracle), "spoke.ORACLE() mismatch");
        assertEq(oracle.SPOKE(), address(spoke), "oracle.SPOKE() mismatch");
        return (spoke, oracle);
    }

    /// @notice Proxify an implementation contract using TransparentUpgradeableProxy
    function _proxify(address impl, address proxyAdminOwner, bytes memory initData) internal returns (address) {
        TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(impl, proxyAdminOwner, initData);
        return address(proxy);
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                          CONFIGS                                          //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function _configureTokenList() internal {
        IHub.SpokeConfig memory spokeConfig = IHub.SpokeConfig({
            active: true,
            addCap: Constants.MAX_ALLOWED_SPOKE_CAP,
            drawCap: Constants.MAX_ALLOWED_SPOKE_CAP
        });

        bytes memory encodedIrData = abi.encode(
            IAssetInterestRateStrategy.InterestRateData({
                optimalUsageRatio: 90_00, // 90.00%
                baseVariableBorrowRate: 5_00, // 5.00%
                variableRateSlope1: 5_00, // 5.00%
                variableRateSlope2: 5_00 // 5.00%
            })
        );

        // Add USDC
        hub.addAsset(address(usdc), usdc.decimals(), address(treasurySpoke), address(irStrategy), encodedIrData);
        hub.updateAssetConfig(
            usdcAssetId,
            IHub.AssetConfig({
                liquidityFee: 5_00,
                feeReceiver: address(treasurySpoke),
                irStrategy: address(irStrategy),
                reinvestmentController: address(0) // TODO should this be integrated?
            }),
            new bytes(0)
        );

        // Add WETH
        hub.addAsset(address(weth), weth.decimals(), address(treasurySpoke), address(irStrategy), encodedIrData);
        hub.updateAssetConfig(
            wethAssetId,
            IHub.AssetConfig({
                liquidityFee: 10_00,
                feeReceiver: address(treasurySpoke),
                irStrategy: address(irStrategy),
                reinvestmentController: address(0)
            }),
            new bytes(0)
        );

        // Spoke 1 reserve configs
        spokeInfo[spoke1].weth.reserveConfig =
            ISpoke.ReserveConfig({paused: false, frozen: false, borrowable: true, collateralRisk: 15_00});
        spokeInfo[spoke1].weth.dynReserveConfig =
            ISpoke.DynamicReserveConfig({collateralFactor: 80_00, maxLiquidationBonus: 100_00, liquidationFee: 0});

        spokeInfo[spoke1].usdc.reserveConfig =
            ISpoke.ReserveConfig({paused: false, frozen: false, borrowable: true, collateralRisk: 50_00});
        spokeInfo[spoke1].usdc.dynReserveConfig =
            ISpoke.DynamicReserveConfig({collateralFactor: 78_00, maxLiquidationBonus: 100_00, liquidationFee: 0});

        priceFeeds.push(_deployMockPriceFeed(spoke1, 1e8));
        priceFeeds.push(_deployMockPriceFeed(spoke1, 2000e8));

        spokeInfo[spoke1].usdc.reserveId = spoke1.addReserve(
            address(hub),
            usdcAssetId,
            priceFeeds[0],
            spokeInfo[spoke1].usdc.reserveConfig,
            spokeInfo[spoke1].usdc.dynReserveConfig
        );

        spokeInfo[spoke1].weth.reserveId = spoke1.addReserve(
            address(hub),
            wethAssetId,
            priceFeeds[1],
            spokeInfo[spoke1].weth.reserveConfig,
            spokeInfo[spoke1].weth.dynReserveConfig
        );

        assetIdToReserveId[address(spoke1)][usdcAssetId] = spokeInfo[spoke1].usdc.reserveId;
        assetIdToReserveId[address(spoke1)][wethAssetId] = spokeInfo[spoke1].weth.reserveId;
        reserveIdToAssetId[address(spoke1)][spokeInfo[spoke1].usdc.reserveId] = usdcAssetId;
        reserveIdToAssetId[address(spoke1)][spokeInfo[spoke1].weth.reserveId] = wethAssetId;

        spokeReserveIds[address(spoke1)].push(spokeInfo[spoke1].usdc.reserveId);
        spokeReserveIds[address(spoke1)].push(spokeInfo[spoke1].weth.reserveId);

        hub.addSpoke(wethAssetId, address(spoke1), spokeConfig);
        hub.addSpoke(usdcAssetId, address(spoke1), spokeConfig);

        // TODO integrate spoke 2
    }

    function _deployMockPriceFeed(ISpoke spoke, uint256 price) internal returns (address) {
        AaveOracle oracle = AaveOracle(spoke.ORACLE());
        return address(new MockPriceFeedSimulator(oracle.DECIMALS(), oracle.DESCRIPTION(), price));
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

        address[] memory contracts = new address[](3);
        contracts[0] = address(spoke1);
        contracts[1] = address(spoke2);
        contracts[2] = address(hub);

        for (uint256 i; i < NUMBER_OF_ACTORS; i++) {
            // Deploy actor proxies and approve system contracts
            address _actor = _setUpActor(addresses[i], tokens, contracts);
            //vm.label(address(_actor), string.concat("actor", vm.toString(i + 1)));

            // Mint initial balances to actors
            for (uint256 j = 0; j < tokens.length; j++) {
                TestnetERC20 _token = TestnetERC20(tokens[j]);
                _token.mint(_actor, INITIAL_BALANCE);
            }
            actorAddresses.push(_actor);
        }
    }

    /// @notice Deploy an actor proxy contract for a user address
    /// @param userAddress Address of the user
    /// @param tokens Array of token addresses
    /// @param contracts Array of contract addresses to aprove tokens to
    /// @return actorAddress Address of the deployed actor
    function _setUpActor(address userAddress, address[] memory tokens, address[] memory contracts)
        internal
        returns (address actorAddress)
    {
        bool success;
        Actor _actor = new Actor(tokens, contracts);
        actors[userAddress] = _actor;
        (success,) = address(_actor).call{value: INITIAL_ETH_BALANCE}("");
        assert(success);
        actorAddress = address(_actor);
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                          LOGGING                                          //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function _logSetup() internal {
        // Log the setup
    }
}
