// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {Script, stdJson, console2 as console} from 'forge-std/Script.sol';
import {StdAssertions} from 'forge-std/StdAssertions.sol';
import {Hub, IHub} from 'src/hub/Hub.sol';
import {SpokeInstance} from 'src/spoke/instances/SpokeInstance.sol';
import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';
import {TransparentUpgradeableProxy, ITransparentUpgradeableProxy} from 'src/dependencies/openzeppelin/TransparentUpgradeableProxy.sol';
import {SignatureGateway} from 'src/position-manager/SignatureGateway.sol';
import {NativeTokenGateway} from 'src/position-manager/NativeTokenGateway.sol';
import {IGatewayBase} from 'src/position-manager/interfaces/IGatewayBase.sol';

import {TreasurySpoke} from 'src/spoke/TreasurySpoke.sol';
import {AccessManager} from 'src/dependencies/openzeppelin/AccessManager.sol';
import {TestnetERC20} from 'tests/mocks/TestnetERC20.sol';
import {MockPriceFeed} from 'tests/mocks/MockPriceFeed.sol';
import {AaveOracle, IAaveOracle} from 'src/spoke/AaveOracle.sol';
import {Ownable2Step} from 'src/dependencies/openzeppelin/Ownable2Step.sol';
import {Roles} from 'src/libraries/types/Roles.sol';
import {IAssetInterestRateStrategy} from 'src/hub/interfaces/IAssetInterestRateStrategy.sol';
import {AssetInterestRateStrategy} from 'src/hub/AssetInterestRateStrategy.sol';
import {WETH9} from 'src/dependencies/weth/WETH9.sol';
import {IERC20} from 'forge-std/interfaces/IERC20.sol';
import {SafeCast} from 'src/dependencies/openzeppelin/SafeCast.sol';

string constant WETH = 'WETH';
string constant WBTC = 'WBTC';
string constant cbBTC = 'cbBTC';
string constant wstETH = 'wstETH';
string constant USDC = 'USDC';
string constant GHO = 'GHO';
string constant USDS = 'USDS';
string constant AAVE = 'AAVE';
string constant MKR = 'MKR';
string constant UNI = 'UNI';
string constant sUSDe = 'sUSDe';

string constant PT_sUSDe = 'PT_sUSDe';
string constant LDO = 'LDO';
string constant ONE_INCH = '1INCH';
string constant USDT = 'USDT';

contract Deploy is Script, StdAssertions {
  using stdJson for string;
  using SafeCast for *;

  /// ---------- TOKEN -----------
  struct Token {
    address token;
    address priceFeed;
  }
  mapping(string key => Token token) internal tokens;
  bool tokenSetup;

  address signatureGateway;
  address nativeTokenGateway;

  function run() external {
    vm.startBroadcast();
    setUpTokens();
    setUpHubs();
    setUpReserves();
    periphery();
    logAddy();
    // seed();
  }

  function debug() public {
    vm.startBroadcast();
    setUpTokens(); // done for price feed on tokens, use only until it doesn't deploy mock tokens
    load();

    {
      Hub targetHub = _hub(CORE_HUB).hub;
      address spoke = address(_spoke(CORE_SPOKE));
      uint assetId = _assetId(targetHub, address(_token(AAVE).token));
      IHub.SpokeConfig memory config = targetHub.getSpokeConfig(assetId, spoke);
      config.active = true;
      targetHub.updateSpokeConfig(assetId, spoke, config);
    }

    _process(
      CORE_SPOKE,
      ReserveConfig({
        assetKey: AAVE,
        hubKey: CORE_HUB,
        collateral: true,
        borrowable: true,
        maxLiquidationBonus: 105_00,
        collateralRisk: 15_00,
        collateralFactor: 70_00,
        liquidationFee: 10_00
      })
    );

    // _process(
    //   FRONTIER_HUB,
    //   AssetConfig({
    //     key: MKR,
    //     liquidityFee: 10_00,
    //     irData: IAssetInterestRateStrategy.InterestRateData(45_00, 0, 7_00, 300_00)
    //   })
    // );
    // _process(
    //   FRONTIER_HUB,
    //   AssetConfig({
    //     key: AAVE,
    //     liquidityFee: 10_00,
    //     irData: IAssetInterestRateStrategy.InterestRateData(45_00, 0, 7_00, 300_00)
    //   })
    // );

    // _process(
    //   FRONTIER_SPOKE,
    //   ReserveConfig({
    //     assetKey: MKR,
    //     hubKey: FRONTIER_HUB,
    //     collateral: true,
    //     borrowable: false,
    //     maxLiquidationBonus: 105_00,
    //     collateralRisk: 7_00,
    //     collateralFactor: 78_00,
    //     liquidationFee: 10_00
    //   })
    // );
    // _process(
    //   FRONTIER_SPOKE,
    //   ReserveConfig({
    //     assetKey: AAVE,
    //     hubKey: FRONTIER_HUB,
    //     collateral: true,
    //     borrowable: false,
    //     maxLiquidationBonus: 105_00,
    //     collateralRisk: 5_00,
    //     collateralFactor: 83_00,
    //     liquidationFee: 10_00
    //   })
    // );
  }

  function setUpTokens() public {
    // move price per reserve listing
    // tokens[WETH] = Token(TestnetERC20(address(new WETH9())), 1922e8);
    // tokens[WBTC] = Token(new TestnetERC20('WBTC', 'WBTC', 8), 98_999e8);
    // tokens[cbBTC] = Token(new TestnetERC20('cbBTC', 'cbBTC', 8), 98_981e8);
    // tokens[wstETH] = Token(new TestnetERC20('wstETH', 'wstETH', 18), 2010e8);
    // tokens[USDC] = Token(new TestnetERC20('USDC', 'USDC', 6), 1.00112e8);
    // tokens[GHO] = Token(new TestnetERC20('GHO', 'GHO', 18), 1.00232e8);
    // tokens[USDS] = Token(new TestnetERC20('USDS', 'USDS', 18), 0.999923e8);
    // tokens[AAVE] = Token(new TestnetERC20('AAVE', 'AAVE', 18), 240.321e8);
    // tokens[MKR] = Token(new TestnetERC20('MKR', 'MKR', 18), 113.21e8);
    // tokens[UNI] = Token(new TestnetERC20('UNI', 'UNI', 8), 9.2323e8);
    // tokens[sUSDe] = Token(new TestnetERC20('sUSDe', 'sUSDe', 18), 1.023213e8);

    // tokens[PT_sUSDe] = Token(new TestnetERC20('PT-sUSDe', 'PT-sUSDe', 18), 1.023213e8);
    // tokens[LDO] = Token(new TestnetERC20('LDO', 'LDO', 18), 1.023213e8);
    // tokens[ONE_INCH] = Token(new TestnetERC20('ONE_INCH', 'ONE_INCH', 18), 1.023213e8);

    tokens[WETH] = Token(
      0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2,
      0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419
    );
    tokens[WBTC] = Token(
      0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599,
      0xF4030086522a5bEEa4988F8cA5B36dbC97BeE88c
    );
    tokens[cbBTC] = Token(
      0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf,
      0x2665701293fCbEB223D11A08D826563EDcCE423A
    );
    tokens[wstETH] = Token(
      0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0,
      // 0x8B6851156023f4f5A66F68BEA80851c3D905Ac93
      _deployMockPriceFeed(550429206740, 'wstETH')
    );
    tokens[USDC] = Token(
      0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48,
      0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6
    );
    tokens[GHO] = Token(
      0x40D16FC0246aD3160Ccc09B8D0D3A2cD28aE6C2f,
      0x3f12643D3f6f874d39C2a4c9f2Cd6f2DbAC877FC
    );
    tokens[USDS] = Token(
      0xdC035D45d973E3EC169d2276DDab16f1e407384F,
      0xfF30586cD0F29eD462364C7e81375FC0C71219b1
    );
    tokens[AAVE] = Token(
      0x7Fc66500c84A76Ad7e9c93437bFc5Ac33E2DDaE9,
      0xbd7F896e60B650C01caf2d7279a1148189A68884
    );
    tokens[MKR] = Token(
      0x9f8F72aA9304c8B593d555F12eF6589cC3A579A2,
      0xec1D1B3b0443256cc3860e24a46F108e699484Aa
    );
    tokens[UNI] = Token(
      0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984,
      0x553303d460EE0afB37EdFf9bE42922D8FF63220e
    );
    tokens[sUSDe] = Token(
      0x9D39A5DE30e57443BfF2A8307A4256c8797A3497,
      0xFF3BC18cCBd5999CE63E788A1c250a88626aD099
    );
    tokens[PT_sUSDe] = Token(
      0x62C6E813b9589C3631Ba0Cdb013acdB8544038B7,
      0x3E7d1eAB13ad0104d2750B8863b489D65364e32D // fix
    );
    tokens[LDO] = Token(
      0x5A98FcBEA516Cf06857215779Fd812CA3beF1B32,
      // 0xb01e6C9af83879B8e06a092f0DD94309c0D497E4
      _deployMockPriceFeed(85721424, 'LDO')
    );
    tokens[ONE_INCH] = Token(
      0x111111111117dC0aa78b770fA6A738034120C302,
      0xc929ad75B72593967DE83E7F7Cda0493458261D9
    );
    tokens[USDT] = Token(
      0xdAC17F958D2ee523a2206206994597C13D831ec7,
      0x3E7d1eAB13ad0104d2750B8863b489D65364e32D
    );

    tokenSetup = true;
  }

  function _mint(string memory key, uint256 amount) internal {
    Token memory t = tokens[key];
    require(address(t.token) != address(0), 'token unset');
    _mint(t.token, amount);
  }

  function _token(string memory key) internal view returns (Token storage) {
    Token storage t = tokens[key];
    require(address(t.token) != address(0), 'token unset');
    require(address(t.priceFeed) != address(0), 'price feed unset');
    return t;
  }

  // -------------------

  string internal constant PRIME_HUB = 'PRIME_HUB';
  string internal constant CORE_HUB = 'CORE_HUB';
  string internal constant ETHENA_HUB = 'ETHENA_HUB';
  string internal constant FRONTIER_HUB = 'FRONTIER_HUB';

  string internal constant PRIME_SPOKE = 'PRIME_SPOKE';
  string internal constant CORE_SPOKE = 'CORE_SPOKE';
  string internal constant LST_SPOKE = 'LST_SPOKE';
  string internal constant ETHENA_SPOKE = 'ETHENA_SPOKE';
  string internal constant FRONTIER_SPOKE = 'FRONTIER_SPOKE';

  struct SpokeGlobalConfig {
    ISpoke spoke;
  }
  mapping(string key => SpokeGlobalConfig spoke) internal spokes;

  struct SpokeListConfig {
    string assetKey;
    string spokeKey;
    uint40 addCap;
    uint40 drawCap;
  }
  struct AssetConfig {
    string key;
    uint16 liquidityFee;
    IAssetInterestRateStrategy.InterestRateData irData;
  }
  struct HubGlobalConfig {
    Hub hub;
    TreasurySpoke treasury;
    AssetInterestRateStrategy irStrategy;
  }
  mapping(string key => HubGlobalConfig conf) hubs;
  AccessManager internal ACCESS_MANAGER;
  address public ADMIN = 0x26D595DdDbAd81Bf976eF6f24686a12A800b141F;
  bool hubSetup;

  function setUpHubs() public {
    require(tokenSetup, 'token setup required');
    (, address caller, ) = vm.readCallers();
    ADMIN = caller;
    ACCESS_MANAGER = new AccessManager(ADMIN);
    deploySpokes();
    {
      console.log('-----PRIME_HUB-----');
      string memory hubKey = 'PRIME_HUB';
      Hub hub = new Hub(address(ACCESS_MANAGER));
      hubs[hubKey] = HubGlobalConfig(
        hub,
        new TreasurySpoke(ADMIN, address(hub)),
        new AssetInterestRateStrategy(address(hub))
      );
      setUpRoles(hubKey);

      AssetConfig[5] memory assetConfigs = [
        AssetConfig({
          key: WETH,
          liquidityFee: 10_00,
          irData: IAssetInterestRateStrategy.InterestRateData(90_00, 0, 2_70, 80_00)
        }),
        AssetConfig({
          key: wstETH,
          liquidityFee: 5_00,
          irData: IAssetInterestRateStrategy.InterestRateData(90_00, 0, 5_50, 85_00)
        }),
        AssetConfig({
          key: USDT,
          liquidityFee: 10_00,
          irData: IAssetInterestRateStrategy.InterestRateData(92_00, 0, 5_50, 35_00)
        }),
        AssetConfig({
          key: USDC,
          liquidityFee: 10_00,
          irData: IAssetInterestRateStrategy.InterestRateData(92_00, 0, 5_50, 35_00)
        }),
        AssetConfig({
          key: GHO,
          liquidityFee: 10_00,
          irData: IAssetInterestRateStrategy.InterestRateData(92_00, 0, 5_50, 35_00)
        })
      ];
      SpokeListConfig[5] memory spokeConfigs = [
        // ----PRIME_SPOKE-----
        SpokeListConfig({assetKey: WETH, spokeKey: PRIME_SPOKE, addCap: 225, drawCap: 200}),
        SpokeListConfig({assetKey: wstETH, spokeKey: PRIME_SPOKE, addCap: 200, drawCap: 75}),
        SpokeListConfig({
          assetKey: USDT,
          spokeKey: PRIME_SPOKE,
          addCap: 3_000_000,
          drawCap: 2_760_000
        }),
        SpokeListConfig({
          assetKey: USDC,
          spokeKey: PRIME_SPOKE,
          addCap: 3_000_000,
          drawCap: 2_760_000
        }),
        SpokeListConfig({
          assetKey: GHO,
          spokeKey: PRIME_SPOKE,
          addCap: 17_500_000,
          drawCap: 15_000_000
        })
      ];

      console.log('\nAssetListing');
      for (uint i; i < assetConfigs.length; ++i) _process(hubKey, assetConfigs[i]);
      console.log('\nSpokeListing');
      for (uint i; i < spokeConfigs.length; ++i) _process(hubKey, spokeConfigs[i]);
      console.log('---------');
    }

    {
      console.log('-----CORE_HUB-----');
      string memory hubKey = 'CORE_HUB';
      Hub hub = new Hub(address(ACCESS_MANAGER));
      hubs[hubKey] = HubGlobalConfig(
        hub,
        new TreasurySpoke(ADMIN, address(hub)),
        new AssetInterestRateStrategy(address(hub))
      );
      setUpRoles(hubKey);

      AssetConfig[8] memory assetConfigs = [
        AssetConfig({
          key: WETH,
          liquidityFee: 10_00,
          irData: IAssetInterestRateStrategy.InterestRateData(90_00, 0, 2_70, 80_00)
        }),
        AssetConfig({
          key: wstETH,
          liquidityFee: 10_00,
          irData: IAssetInterestRateStrategy.InterestRateData(90_00, 0, 5_50, 85_00)
        }),
        AssetConfig({
          key: WBTC,
          liquidityFee: 10_00,
          irData: IAssetInterestRateStrategy.InterestRateData(80_00, 0, 4_00, 60_00) // ! this was incorrect?
        }),
        AssetConfig({
          key: cbBTC,
          liquidityFee: 10_00,
          irData: IAssetInterestRateStrategy.InterestRateData(80_00, 0, 4_00, 60_00)
        }),
        AssetConfig({
          key: AAVE,
          liquidityFee: 10_00,
          irData: IAssetInterestRateStrategy.InterestRateData(45_00, 0, 5_50, 300_00)
        }),
        AssetConfig({
          key: USDC,
          liquidityFee: 10_00,
          irData: IAssetInterestRateStrategy.InterestRateData(92_00, 0, 5_50, 35_00)
        }),
        AssetConfig({
          key: USDT,
          liquidityFee: 10_00,
          irData: IAssetInterestRateStrategy.InterestRateData(92_00, 0, 5_50, 35_00)
        }),
        AssetConfig({
          key: GHO,
          liquidityFee: 10_00,
          irData: IAssetInterestRateStrategy.InterestRateData(92_00, 0, 5_50, 35_00)
        })
      ];
      SpokeListConfig[12] memory spokeConfigs = [
        // ----CORE_SPOKE-----
        SpokeListConfig({assetKey: WETH, spokeKey: CORE_SPOKE, addCap: 800, drawCap: 725}),
        SpokeListConfig({assetKey: wstETH, spokeKey: CORE_SPOKE, addCap: 45, drawCap: 15}),
        SpokeListConfig({assetKey: WBTC, spokeKey: CORE_SPOKE, addCap: 20, drawCap: 7}),
        SpokeListConfig({assetKey: cbBTC, spokeKey: CORE_SPOKE, addCap: 5, drawCap: 3}),
        SpokeListConfig({assetKey: AAVE, spokeKey: CORE_SPOKE, addCap: 9_500, drawCap: 5_000}),
        SpokeListConfig({
          assetKey: USDC,
          spokeKey: CORE_SPOKE,
          addCap: 3_000_000,
          drawCap: 2_760_000
        }),
        SpokeListConfig({
          assetKey: USDT,
          spokeKey: CORE_SPOKE,
          addCap: 3_000_000,
          drawCap: 2_760_000
        }),
        SpokeListConfig({
          assetKey: GHO,
          spokeKey: CORE_SPOKE,
          addCap: 8_000_000,
          drawCap: 5_500_000
        }),
        // ----LST_SPOKE-----
        SpokeListConfig({assetKey: WETH, spokeKey: LST_SPOKE, addCap: 225, drawCap: 0}),
        SpokeListConfig({assetKey: wstETH, spokeKey: LST_SPOKE, addCap: 200, drawCap: 100}),
        // ----ETHENA_SPOKE-----
        SpokeListConfig({
          assetKey: USDC,
          spokeKey: ETHENA_SPOKE,
          addCap: 2_000_000,
          drawCap: 1_000_000
        }),
        // ----FRONTIER_SPOKE-----
        SpokeListConfig({
          assetKey: USDC,
          spokeKey: FRONTIER_SPOKE,
          addCap: 2_000_000,
          drawCap: 1_000_000
        })
      ];

      console.log('\nAssetListing');
      for (uint i; i < assetConfigs.length; ++i) _process(hubKey, assetConfigs[i]);
      console.log('\nSpokeListing');
      for (uint i; i < spokeConfigs.length; ++i) _process(hubKey, spokeConfigs[i]);
      console.log('---------');
    }

    {
      console.log('-----ETHENA_HUB-----');
      string memory hubKey = 'ETHENA_HUB';
      Hub hub = new Hub(address(ACCESS_MANAGER));
      hubs[hubKey] = HubGlobalConfig(
        hub,
        new TreasurySpoke(ADMIN, address(hub)),
        new AssetInterestRateStrategy(address(hub))
      );
      setUpRoles(hubKey);

      AssetConfig[5] memory assetConfigs = [
        AssetConfig({
          key: PT_sUSDe,
          liquidityFee: 10_00,
          irData: IAssetInterestRateStrategy.InterestRateData(45_00, 0, 10_00, 300_00)
        }),
        AssetConfig({
          key: sUSDe,
          liquidityFee: 10_00,
          irData: IAssetInterestRateStrategy.InterestRateData(90_00, 0, 6_25, 40_00)
        }),
        AssetConfig({
          key: USDC,
          liquidityFee: 10_00,
          irData: IAssetInterestRateStrategy.InterestRateData(92_00, 0, 5_50, 35_00)
        }),
        AssetConfig({
          key: USDT,
          liquidityFee: 10_00,
          irData: IAssetInterestRateStrategy.InterestRateData(92_00, 0, 5_50, 35_00)
        }),
        AssetConfig({
          key: GHO,
          liquidityFee: 10_00,
          irData: IAssetInterestRateStrategy.InterestRateData(92_00, 0, 5_50, 35_00)
        })
      ];
      SpokeListConfig[5] memory spokeConfigs = [
        // ----ETHENA_SPOKE-----
        SpokeListConfig({
          assetKey: PT_sUSDe,
          spokeKey: ETHENA_SPOKE,
          addCap: 6_000_000,
          drawCap: 0
        }),
        SpokeListConfig({assetKey: sUSDe, spokeKey: ETHENA_SPOKE, addCap: 5_000_000, drawCap: 0}),
        SpokeListConfig({
          assetKey: USDC,
          spokeKey: ETHENA_SPOKE,
          addCap: 3_000_000,
          drawCap: 2_760_000
        }),
        SpokeListConfig({
          assetKey: USDT,
          spokeKey: ETHENA_SPOKE,
          addCap: 3_000_000,
          drawCap: 2_760_000
        }),
        SpokeListConfig({
          assetKey: GHO,
          spokeKey: ETHENA_SPOKE,
          addCap: 17_500_000,
          drawCap: 15_500_000
        })
      ];

      console.log('\nAssetListing');
      for (uint i; i < assetConfigs.length; ++i) _process(hubKey, assetConfigs[i]);
      console.log('\nSpokeListing');
      for (uint i; i < spokeConfigs.length; ++i) _process(hubKey, spokeConfigs[i]);
      console.log('---------');
    }

    {
      console.log('-----FRONTIER_HUB-----');
      string memory hubKey = 'FRONTIER_HUB';
      Hub hub = new Hub(address(ACCESS_MANAGER));
      hubs[hubKey] = HubGlobalConfig(
        hub,
        new TreasurySpoke(ADMIN, address(hub)),
        new AssetInterestRateStrategy(address(hub))
      );
      setUpRoles(hubKey);

      AssetConfig[6] memory assetConfigs = [
        AssetConfig({
          key: UNI,
          liquidityFee: 10_00,
          irData: IAssetInterestRateStrategy.InterestRateData(45_00, 0, 7_00, 300_00)
        }),
        AssetConfig({
          key: LDO,
          liquidityFee: 10_00,
          irData: IAssetInterestRateStrategy.InterestRateData(45_00, 0, 7_00, 300_00)
        }),
        AssetConfig({
          key: ONE_INCH,
          liquidityFee: 10_00,
          irData: IAssetInterestRateStrategy.InterestRateData(45_00, 0, 9_00, 300_00)
        }),
        AssetConfig({
          key: USDC,
          liquidityFee: 10_00,
          irData: IAssetInterestRateStrategy.InterestRateData(92_00, 0, 5_50, 35_00)
        }),
        AssetConfig({
          key: USDT,
          liquidityFee: 10_00,
          irData: IAssetInterestRateStrategy.InterestRateData(92_00, 0, 5_50, 35_00)
        }),
        AssetConfig({
          key: GHO,
          liquidityFee: 10_00,
          irData: IAssetInterestRateStrategy.InterestRateData(92_00, 0, 5_50, 35_00)
        })
      ];
      SpokeListConfig[6] memory spokeConfigs = [
        // ----FRONTIER_SPOKE-----
        SpokeListConfig({assetKey: UNI, spokeKey: FRONTIER_SPOKE, addCap: 600_000, drawCap: 0}),
        SpokeListConfig({assetKey: LDO, spokeKey: FRONTIER_SPOKE, addCap: 50_000_000, drawCap: 0}),
        SpokeListConfig({
          assetKey: ONE_INCH,
          spokeKey: FRONTIER_SPOKE,
          addCap: 500_000,
          drawCap: 0
        }),
        SpokeListConfig({
          assetKey: USDC,
          spokeKey: FRONTIER_SPOKE,
          addCap: 3_000_000,
          drawCap: 2_760_000
        }),
        SpokeListConfig({
          assetKey: USDT,
          spokeKey: FRONTIER_SPOKE,
          addCap: 3_000_000,
          drawCap: 2_760_000
        }),
        SpokeListConfig({
          assetKey: GHO,
          spokeKey: FRONTIER_SPOKE,
          addCap: 17_500_000,
          drawCap: 15_500_000
        })
      ];

      console.log('\nAssetListing');
      for (uint i; i < assetConfigs.length; ++i) _process(hubKey, assetConfigs[i]);
      console.log('\nSpokeListing');
      for (uint i; i < spokeConfigs.length; ++i) _process(hubKey, spokeConfigs[i]);
      console.log('---------');
    }
    hubSetup = true;
  }

  struct ReserveConfig {
    string assetKey;
    string hubKey;
    bool collateral;
    bool borrowable;
    uint32 maxLiquidationBonus;
    uint24 collateralRisk;
    uint16 collateralFactor;
    uint16 liquidationFee;
  }

  function setUpReserves() public {
    require(hubSetup, 'hub setup required');

    {
      string memory spokeKey = 'PRIME_SPOKE';
      console.log('-----PRIME_SPOKE-----');
      ReserveConfig[5] memory reserveConf = [
        ReserveConfig({
          assetKey: WETH,
          hubKey: PRIME_HUB,
          collateral: true,
          borrowable: true,
          maxLiquidationBonus: 105_00,
          collateralRisk: 0,
          collateralFactor: 85_00,
          liquidationFee: 10_00
        }),
        ReserveConfig({
          assetKey: wstETH,
          hubKey: PRIME_HUB,
          collateral: true,
          borrowable: true,
          maxLiquidationBonus: 106_00,
          collateralRisk: 0,
          collateralFactor: 83_00,
          liquidationFee: 10_00
        }),
        ReserveConfig({
          assetKey: USDT,
          hubKey: PRIME_HUB,
          collateral: true,
          borrowable: true,
          maxLiquidationBonus: 100_00,
          collateralRisk: 0,
          collateralFactor: 83_00,
          liquidationFee: 10_00
        }),
        ReserveConfig({
          assetKey: USDC,
          hubKey: PRIME_HUB,
          collateral: true,
          borrowable: true,
          maxLiquidationBonus: 100_00,
          collateralRisk: 0,
          collateralFactor: 83_00,
          liquidationFee: 10_00
        }),
        ReserveConfig({
          assetKey: GHO,
          hubKey: PRIME_HUB,
          collateral: true,
          borrowable: true,
          maxLiquidationBonus: 100_00,
          collateralRisk: 0,
          collateralFactor: 83_00,
          liquidationFee: 10_00
        })
      ];

      console.log('\nReserveListing');
      for (uint i; i < reserveConf.length; ++i) _process(spokeKey, reserveConf[i]);
    }

    {
      string memory spokeKey = 'CORE_SPOKE';
      console.log('-----CORE_SPOKE-----');
      ReserveConfig[7] memory reserveConf = [
        ReserveConfig({
          assetKey: WETH,
          hubKey: CORE_HUB,
          collateral: true,
          borrowable: true,
          maxLiquidationBonus: 105_00,
          collateralRisk: 0,
          collateralFactor: 85_00,
          liquidationFee: 10_00
        }),
        ReserveConfig({
          assetKey: wstETH,
          hubKey: CORE_HUB,
          collateral: true,
          borrowable: true,
          maxLiquidationBonus: 106_00,
          collateralRisk: 0,
          collateralFactor: 83_00,
          liquidationFee: 10_00
        }),
        ReserveConfig({
          assetKey: WBTC,
          hubKey: CORE_HUB,
          collateral: true,
          borrowable: true,
          maxLiquidationBonus: 106_00,
          collateralRisk: 0,
          collateralFactor: 83_00,
          liquidationFee: 10_00
        }),
        ReserveConfig({
          assetKey: cbBTC,
          hubKey: CORE_HUB,
          collateral: true,
          borrowable: true,
          maxLiquidationBonus: 105_00,
          collateralRisk: 0,
          collateralFactor: 78_00,
          liquidationFee: 10_00
        }),
        ReserveConfig({
          assetKey: USDT,
          hubKey: CORE_HUB,
          collateral: true,
          borrowable: true,
          maxLiquidationBonus: 100_00,
          collateralRisk: 0,
          collateralFactor: 83_00,
          liquidationFee: 10_00
        }),
        ReserveConfig({
          assetKey: USDC,
          hubKey: CORE_HUB,
          collateral: true,
          borrowable: true,
          maxLiquidationBonus: 100_00,
          collateralRisk: 0,
          collateralFactor: 83_00,
          liquidationFee: 10_00
        }),
        ReserveConfig({
          assetKey: GHO,
          hubKey: CORE_HUB,
          collateral: true,
          borrowable: true,
          maxLiquidationBonus: 100_00,
          collateralRisk: 0,
          collateralFactor: 83_00,
          liquidationFee: 10_00
        })
      ];

      console.log('\nReserveListing');
      for (uint i; i < reserveConf.length; ++i) _process(spokeKey, reserveConf[i]);
    }

    {
      string memory spokeKey = 'LST_SPOKE';
      console.log('-----LST_SPOKE-----');
      ReserveConfig[2] memory reserveConf = [
        ReserveConfig({
          assetKey: WETH,
          hubKey: CORE_HUB,
          collateral: false,
          borrowable: true,
          maxLiquidationBonus: 100_00,
          collateralRisk: 0,
          collateralFactor: 0,
          liquidationFee: 0
        }),
        ReserveConfig({
          assetKey: wstETH,
          hubKey: CORE_HUB,
          collateral: true,
          borrowable: false,
          maxLiquidationBonus: 106_00,
          collateralRisk: 0,
          collateralFactor: 93_00,
          liquidationFee: 15_00
        })
      ];

      console.log('\nReserveListing');
      for (uint i; i < reserveConf.length; ++i) _process(spokeKey, reserveConf[i]);
    }

    {
      string memory spokeKey = 'ETHENA_SPOKE';
      console.log('-----ETHENA_SPOKE-----');
      ReserveConfig[6] memory reserveConf = [
        ReserveConfig({
          assetKey: PT_sUSDe,
          hubKey: ETHENA_HUB,
          collateral: true,
          borrowable: false,
          maxLiquidationBonus: 105_00,
          collateralRisk: 8_00,
          collateralFactor: 78_00,
          liquidationFee: 10_00
        }),
        ReserveConfig({
          assetKey: sUSDe,
          hubKey: ETHENA_HUB,
          collateral: true,
          borrowable: false,
          maxLiquidationBonus: 106_00,
          collateralRisk: 9_00,
          collateralFactor: 80_00,
          liquidationFee: 10_00
        }),
        ReserveConfig({
          assetKey: USDT,
          hubKey: ETHENA_HUB,
          collateral: false,
          borrowable: true,
          maxLiquidationBonus: 100_00,
          collateralRisk: 0,
          collateralFactor: 0,
          liquidationFee: 0
        }),
        ReserveConfig({
          assetKey: USDC,
          hubKey: ETHENA_HUB,
          collateral: false,
          borrowable: true,
          maxLiquidationBonus: 100_00,
          collateralRisk: 0,
          collateralFactor: 0,
          liquidationFee: 0
        }),
        ReserveConfig({
          assetKey: GHO,
          hubKey: ETHENA_HUB,
          collateral: false,
          borrowable: true,
          maxLiquidationBonus: 100_00,
          collateralRisk: 0,
          collateralFactor: 0,
          liquidationFee: 0
        }),
        ReserveConfig({
          assetKey: USDC,
          hubKey: CORE_HUB,
          collateral: false,
          borrowable: true,
          maxLiquidationBonus: 100_00,
          collateralRisk: 0,
          collateralFactor: 0,
          liquidationFee: 0
        })
      ];

      console.log('\nReserveListing');
      for (uint i; i < reserveConf.length; ++i) _process(spokeKey, reserveConf[i]);
    }

    {
      string memory spokeKey = 'FRONTIER_SPOKE';
      console.log('-----FRONTIER_SPOKE-----');
      ReserveConfig[7] memory reserveConf = [
        ReserveConfig({
          assetKey: UNI,
          hubKey: FRONTIER_HUB,
          collateral: true,
          borrowable: false,
          maxLiquidationBonus: 105_00,
          collateralRisk: 5_00,
          collateralFactor: 78_00,
          liquidationFee: 10_00
        }),
        ReserveConfig({
          assetKey: LDO,
          hubKey: FRONTIER_HUB,
          collateral: true,
          borrowable: false,
          maxLiquidationBonus: 106_00,
          collateralRisk: 7_00,
          collateralFactor: 78_00,
          liquidationFee: 10_00
        }),
        ReserveConfig({
          assetKey: ONE_INCH,
          hubKey: FRONTIER_HUB,
          collateral: true,
          borrowable: false,
          maxLiquidationBonus: 105_00,
          collateralRisk: 10_00,
          collateralFactor: 78_00,
          liquidationFee: 10_00
        }),
        ReserveConfig({
          assetKey: USDT,
          hubKey: FRONTIER_HUB,
          collateral: false,
          borrowable: true,
          maxLiquidationBonus: 100_00,
          collateralRisk: 0,
          collateralFactor: 0,
          liquidationFee: 0
        }),
        ReserveConfig({
          assetKey: USDC,
          hubKey: FRONTIER_HUB,
          collateral: false,
          borrowable: true,
          maxLiquidationBonus: 100_00,
          collateralRisk: 0,
          collateralFactor: 0,
          liquidationFee: 0
        }),
        ReserveConfig({
          assetKey: GHO,
          hubKey: FRONTIER_HUB,
          collateral: false,
          borrowable: true,
          maxLiquidationBonus: 100_00,
          collateralRisk: 0,
          collateralFactor: 0,
          liquidationFee: 0
        }),
        ReserveConfig({
          assetKey: USDC,
          hubKey: CORE_HUB,
          collateral: false,
          borrowable: true,
          maxLiquidationBonus: 100_00,
          collateralRisk: 0,
          collateralFactor: 0,
          liquidationFee: 0
        })
      ];

      console.log('\nReserveListing');
      for (uint i; i < reserveConf.length; ++i) _process(spokeKey, reserveConf[i]);
    }
  }

  function _process(string memory spokeKey, ReserveConfig memory conf) internal {
    console.log('hub\t\t\t\t\t', conf.hubKey);
    console.log('token\t\t\t\t\t', conf.assetKey);

    Hub hub = _hub(conf.hubKey).hub;
    ISpoke spoke = _spoke(spokeKey);
    Token storage t = _token(conf.assetKey);
    uint assetId = _assetId(hub, address(t.token));

    ISpoke.ReserveConfig memory st = ISpoke.ReserveConfig({
      liquidatable: true,
      receiveSharesEnabled: true,
      frozen: false,
      paused: false,
      borrowable: conf.borrowable,
      collateralRisk: conf.collateralRisk
    });
    ISpoke.DynamicReserveConfig memory dyn = ISpoke.DynamicReserveConfig({
      collateralFactor: conf.collateralFactor.toUint16(),
      maxLiquidationBonus: conf.maxLiquidationBonus,
      liquidationFee: conf.liquidationFee
    });

    uint reserveId = spoke.addReserve(address(hub), assetId, t.priceFeed, st, dyn);

    assertEq(abi.encode(spoke.getReserveConfig(reserveId)), abi.encode(st));
    assertEq(
      abi.encode(
        spoke.getDynamicReserveConfig(reserveId, spoke.getReserve(reserveId).dynamicConfigKey)
      ),
      abi.encode(dyn)
    );

    console.log('reserveId\t\t\t\t', reserveId);
    console.log('assetId\t\t\t\t', assetId);
    console.log('frozen\t\t\t\t', st.frozen);
    console.log('paused\t\t\t\t', st.paused);
    console.log('borrowable\t\t\t\t', st.borrowable);
    console.log('collateralRisk\t\t\t', st.collateralRisk);
    console.log('maxLiquidationBonus\t\t\t', dyn.maxLiquidationBonus);
    console.log('liquidationFee\t\t\t', dyn.liquidationFee);
    console.log('collateralFactor\t\t\t', dyn.collateralFactor);
    console.log('price feed\t\t\t\t', IAaveOracle(spoke.ORACLE()).getReserveSource(reserveId));
    console.log('price\t\t\t\t\t %e', IAaveOracle(spoke.ORACLE()).getReservePrice(reserveId));
    console.log();
  }

  function _hub(string memory key) internal returns (HubGlobalConfig storage) {
    HubGlobalConfig storage ret = hubs[key];
    require(address(ret.hub) != address(0), string.concat('zero hub ', key));

    if (address(ret.treasury) == address(0)) {
      console.log('hub treasury not set, using asset 0s fee receiver');
      ret.treasury = TreasurySpoke(ret.hub.getAsset(0).feeReceiver);
      require(address(ret.treasury) != address(0), 'asset(0).feeReceiver == 0');
    }
    if (address(ret.irStrategy) == address(0)) {
      console.log('hub irStrategy not set, using asset 0s irStrategy');
      ret.irStrategy = AssetInterestRateStrategy(ret.hub.getAsset(0).irStrategy);
      require(address(ret.irStrategy) != address(0), 'asset(0).irStrategy == 0');
    }

    return ret;
  }

  function _process(string memory hubKey, AssetConfig memory conf) internal {
    console.log('token\t\t\t\t\t', conf.key);

    HubGlobalConfig storage hubConf = _hub(hubKey);
    address token = address(_token(conf.key).token);

    uint assetId = hubConf.hub.addAsset(
      address(token),
      TestnetERC20(token).decimals(),
      address(hubConf.treasury),
      address(hubConf.irStrategy),
      abi.encode(conf.irData)
    );
    assertEq(assetId, _assetId(hubConf.hub, token));
    assertEq(abi.encode(hubConf.irStrategy.getInterestRateData(assetId)), abi.encode(conf.irData));

    {
      IHub.AssetConfig memory assetConfig = hubConf.hub.getAssetConfig(assetId);
      assetConfig.liquidityFee = conf.liquidityFee;
      hubConf.hub.updateAssetConfig(assetId, assetConfig, new bytes(0));
      assetConfig = hubConf.hub.getAssetConfig(assetId);
      assertEq(assetConfig.liquidityFee, conf.liquidityFee);
      assertEq(assetConfig.feeReceiver, address(hubConf.treasury));
      assertEq(assetConfig.irStrategy, address(hubConf.irStrategy));
    }

    console.log('assetId\t\t\t\t', assetId);
    console.log('treasury\t\t\t\t', address(hubConf.treasury));
    console.log('liquidityFee\t\t\t\t', conf.liquidityFee);
    console.log('irStrategy\t\t\t\t', address(hubConf.irStrategy));
    console.log('irStrategy.optimalUsageRatio\t', conf.irData.optimalUsageRatio);
    console.log('irStrategy.baseVariableBorrowRate\t', conf.irData.baseVariableBorrowRate);
    console.log('irStrategy.variableRateSlope1\t', conf.irData.variableRateSlope1);
    console.log('irStrategy.variableRateSlope2\t', conf.irData.variableRateSlope2);
    console.log();
  }

  // doesn't work with asset listed multiple times on hub
  function _assetId(Hub hub, address token) internal view returns (uint) {
    uint assetCount = hub.getAssetCount();
    for (uint i; i < assetCount; ++i) {
      if (hub.getAsset(i).underlying == token) return i;
    }
    revert('token not found');
  }

  function _process(string memory hubKey, SpokeListConfig memory conf) internal {
    console.log('spoke\t\t\t\t\t', conf.spokeKey);
    console.log('token\t\t\t\t\t', conf.assetKey);
    Hub hub = _hub(hubKey).hub;
    ISpoke spoke = _spoke(conf.spokeKey);
    address token = address(_token(conf.assetKey).token);
    uint assetId = _assetId(hub, token);

    hub.addSpoke(
      assetId,
      address(spoke),
      IHub.SpokeConfig({
        addCap: conf.addCap,
        drawCap: conf.drawCap,
        riskPremiumThreshold: 1000_00,
        active: true,
        paused: false
      })
    );
    IHub.SpokeConfig memory spokeConfig = hub.getSpokeConfig(assetId, address(spoke));
    assertEq(spokeConfig.addCap, conf.addCap);
    assertEq(spokeConfig.drawCap, conf.drawCap);
    assertTrue(spokeConfig.active);

    console.log('addCap\t\t\t\t %e', spokeConfig.addCap);
    console.log('drawCap\t\t\t\t %e', spokeConfig.drawCap);
    console.log('active\t\t\t\t', spokeConfig.active);
    console.log();
  }

  function deploySpokes() internal {
    string[5] memory keys = [PRIME_SPOKE, CORE_SPOKE, LST_SPOKE, ETHENA_SPOKE, FRONTIER_SPOKE];

    for (uint i; i < keys.length; ++i) {
      (, address deployer, ) = vm.readCallers();
      address predictedSpoke = vm.computeCreateAddress(deployer, vm.getNonce(deployer) + 2);
      IAaveOracle oracle = new AaveOracle(
        address(predictedSpoke),
        8,
        string.concat(keys[i], ' (USD)')
      );
      address spokeImpl = address(new SpokeInstance(address(oracle)));
      ISpoke spoke = ISpoke(
        address(
          new TransparentUpgradeableProxy(
            spokeImpl,
            deployer,
            abi.encodeCall(SpokeInstance.initialize, (address(ACCESS_MANAGER)))
          )
        )
      );
      assertEq(address(predictedSpoke), address(spoke), 'predictedSpoke');
      assertEq(spoke.ORACLE(), address(oracle));
      assertEq(oracle.SPOKE(), address(spoke));

      spokes[keys[i]] = SpokeGlobalConfig(spoke);
    }
  }

  function _spoke(string memory key) internal view returns (ISpoke) {
    SpokeGlobalConfig storage ret = spokes[key];
    require(address(ret.spoke) != address(0), 'zero spoke');
    return ret.spoke;
  }

  function setUpRoles(string memory hubKey) public {
    ACCESS_MANAGER.grantRole(Roles.HUB_ADMIN_ROLE, ADMIN, 0);
    ACCESS_MANAGER.grantRole(Roles.SPOKE_ADMIN_ROLE, ADMIN, 0);

    Hub hub = _hub(hubKey).hub;

    string[5] memory spokeKeys = [PRIME_SPOKE, CORE_SPOKE, LST_SPOKE, ETHENA_SPOKE, FRONTIER_SPOKE];
    for (uint i; i < spokeKeys.length; ++i) {
      ISpoke spoke = _spoke(spokeKeys[i]);
      {
        bytes4[] memory selectors = new bytes4[](6);
        selectors[0] = ISpoke.updateUserRiskPremium.selector;
        selectors[1] = ISpoke.updateReservePriceSource.selector;
        selectors[2] = ISpoke.updateLiquidationConfig.selector;
        selectors[3] = ISpoke.addReserve.selector;
        selectors[4] = ISpoke.updateReserveConfig.selector;
        selectors[5] = ISpoke.updateDynamicReserveConfig.selector;
        ACCESS_MANAGER.setTargetFunctionRole(address(spoke), selectors, Roles.SPOKE_ADMIN_ROLE);
      }

      {
        bytes4[] memory selectors = new bytes4[](5);
        selectors[0] = IHub.addAsset.selector;
        selectors[1] = IHub.updateAssetConfig.selector;
        selectors[2] = IHub.addSpoke.selector;
        selectors[3] = IHub.updateSpokeConfig.selector;
        selectors[4] = IHub.setInterestRateData.selector;
        ACCESS_MANAGER.setTargetFunctionRole(address(hub), selectors, Roles.HUB_ADMIN_ROLE);
      }
    }
  }

  function logAddy() public {
    string memory root = 'root';
    {
      string[4] memory keys = [PRIME_HUB, CORE_HUB, ETHENA_HUB, FRONTIER_HUB];
      string memory HUBS;
      string memory IR_STRATEGIES;
      for (uint i; i < keys.length; ++i) {
        console.log(address(_hub(keys[i]).hub), keys[i]);
        HUBS = vm.serializeAddress('hub', keys[i], address(_hub(keys[i]).hub));
        IR_STRATEGIES = vm.serializeAddress(
          'irStrategy',
          keys[i],
          address(_hub(keys[i]).irStrategy)
        );
      }
      vm.serializeString(root, 'hub', HUBS);
      vm.serializeString(root, 'irStrategy', IR_STRATEGIES);
    }

    {
      string[5] memory keys = [PRIME_SPOKE, CORE_SPOKE, LST_SPOKE, ETHENA_SPOKE, FRONTIER_SPOKE];
      string memory SPOKES;
      for (uint i; i < keys.length; ++i) {
        console.log(address(_spoke(keys[i])), keys[i]);
        SPOKES = vm.serializeAddress('spoke', keys[i], address(_spoke(keys[i])));
      }
      vm.serializeString(root, 'spoke', SPOKES);
    }
    {
      string[15] memory keys = [
        WETH,
        cbBTC,
        WBTC,
        wstETH,
        USDC,
        GHO,
        USDS,
        AAVE,
        MKR,
        UNI,
        sUSDe,
        PT_sUSDe,
        LDO,
        ONE_INCH,
        USDT
      ];
      string memory TOKENS;
      for (uint i; i < keys.length; ++i) {
        console.log(address(_token(keys[i]).token), keys[i]);
        TOKENS = vm.serializeAddress('token', keys[i], address(_token(keys[i]).token));
      }
      vm.serializeString(root, 'token', TOKENS);
    }
    {
      vm.serializeAddress(root, 'signatureGateway', signatureGateway);
      vm.serializeAddress(root, 'nativeTokenGateway', nativeTokenGateway);
    }
    root = vm.serializeString(root, 'commit', _commit());
    console.log(root);
    vm.writeJson(root, './output/deploy.json');
  }

  function load() public {
    string memory deploy = vm.readFile('./output/deploy.json');
    {
      string[4] memory keys = [PRIME_HUB, CORE_HUB, ETHENA_HUB, FRONTIER_HUB];
      for (uint i; i < keys.length; ++i) {
        hubs[keys[i]].hub = Hub(deploy.readAddress(string.concat('.hub.', keys[i])));
        console.log(address(_hub(keys[i]).hub), keys[i]);
        vm.label(address(_hub(keys[i]).hub), keys[i]);
      }
    }
    {
      string[5] memory keys = [PRIME_SPOKE, CORE_SPOKE, LST_SPOKE, ETHENA_SPOKE, FRONTIER_SPOKE];
      for (uint i; i < keys.length; ++i) {
        spokes[keys[i]].spoke = ISpoke(deploy.readAddress(string.concat('.spoke.', keys[i])));
        console.log(address(_spoke(keys[i])), keys[i]);
        vm.label(address(_spoke(keys[i])), keys[i]);
      }
    }
    {
      string[15] memory keys = [
        WETH,
        cbBTC,
        WBTC,
        wstETH,
        USDC,
        GHO,
        USDS,
        AAVE,
        MKR,
        UNI,
        sUSDe,
        PT_sUSDe,
        LDO,
        ONE_INCH,
        USDT
      ];
      for (uint i; i < keys.length; ++i) {
        tokens[keys[i]].token = address(deploy.readAddress(string.concat('.token.', keys[i])));
        console.log(address(_token(keys[i]).token), keys[i]);
        vm.label(address(_token(keys[i]).token), keys[i]);
      }
    }
    signatureGateway = deploy.readAddress('.signatureGateway');
    nativeTokenGateway = deploy.readAddress('.nativeTokenGateway');
  }

  function _commit() internal returns (string memory) {
    string[] memory c = new string[](3);
    c[0] = 'git';
    c[1] = 'rev-parse';
    c[2] = 'HEAD';
    return slice(vm.toString(vm.ffi(c)), 2);
  }

  function slice(string memory input, uint x) internal pure returns (string memory) {
    bytes memory inputBytes = bytes(input);
    require(inputBytes.length >= x, 'Input too short');
    bytes memory result = new bytes(inputBytes.length - x);
    for (uint256 i = x; i < inputBytes.length; i++) {
      result[i - x] = inputBytes[i];
    }
    return string(result);
  }

  function _deployMockPriceFeed(uint price, string memory description) internal returns (address) {
    return address(new MockPriceFeed(8, description, price));
  }

  function seed() public {
    vm.startBroadcast();
    load();
    {
      string[5] memory keys = [PRIME_SPOKE, CORE_SPOKE, LST_SPOKE, ETHENA_SPOKE, FRONTIER_SPOKE];
      for (uint i; i < keys.length; ++i) {
        ISpoke spoke = _spoke(keys[i]);
        console.log(keys[i]);
        _run(spoke, _supply);
        // _run(spoke, _withdraw);
        // _run(spoke, _supply);
        // _run(spoke, _borrow);
        // _run(spoke, _repay);
        console.log();
      }
    }
  }

  function periphery() public {
    (, address caller, ) = vm.readCallers();
    {
      signatureGateway = address(new SignatureGateway(caller));
      nativeTokenGateway = address(new NativeTokenGateway(address(tokens[WETH].token), caller));
      console.log('signatureGateway', address(signatureGateway));
      console.log('nativeTokenGateway', address(nativeTokenGateway));

      string[5] memory keys = [PRIME_SPOKE, CORE_SPOKE, LST_SPOKE, ETHENA_SPOKE, FRONTIER_SPOKE];
      for (uint i; i < keys.length; ++i) {
        ISpoke spoke = _spoke(keys[i]);
        console.log('registered for: ', keys[i]);
        IGatewayBase(signatureGateway).registerSpoke(address(spoke), true);
        IGatewayBase(nativeTokenGateway).registerSpoke(address(spoke), true);
        spoke.updatePositionManager(address(signatureGateway), true);
        spoke.updatePositionManager(address(nativeTokenGateway), true);
      }
    }
  }

  function _run(ISpoke spoke, function(ISpoke, uint) internal _action) internal {
    uint reserveCount = spoke.getReserveCount();
    for (uint i; i < reserveCount; ++i) _action(spoke, i);
  }

  function _supply(ISpoke spoke, uint reserveId) internal {
    (, address caller, ) = vm.readCallers();
    ISpoke.Reserve memory reserve = spoke.getReserve(reserveId);
    if (IHub(address(reserve.hub)).getSpokeConfig(reserve.assetId, address(spoke)).addCap == 0)
      return;

    TestnetERC20 token = TestnetERC20(reserve.underlying);
    uint amount = _getAmount(bound(vm.randomUint(), 0.01e8, 100e8), spoke, reserveId, token);
    _mint(token, amount);

    console.log('spoke', address(spoke));
    console.log('reserve', reserveId);
    token.approve(address(spoke), amount);
    console.log('approved');
    spoke.supply(reserveId, amount, caller);
    spoke.setUsingAsCollateral(reserveId, true, caller);
  }

  function _withdraw(ISpoke spoke, uint reserveId) internal {
    (, address caller, ) = vm.readCallers();
    uint amount = bound(vm.randomUint(), 0, spoke.getUserSuppliedAssets(reserveId, caller));
    if (amount != 0) spoke.withdraw(reserveId, amount, caller);

    (bool usingAsCollateral, ) = spoke.getUserReserveStatus(reserveId, caller);
    if (usingAsCollateral) {
      spoke.setUsingAsCollateral(reserveId, false, caller);
      spoke.setUsingAsCollateral(reserveId, true, caller);
    }
  }

  function _borrow(ISpoke spoke, uint reserveId) internal {
    if (!spoke.getReserveConfig(reserveId).borrowable) return;
    ISpoke.Reserve memory reserve = spoke.getReserve(reserveId);

    (, address caller, ) = vm.readCallers();
    TestnetERC20 token = TestnetERC20(reserve.underlying);
    uint amount = bound(vm.randomUint(), 2, 10 ** (token.decimals() - 3));
    if (amount != 0) spoke.borrow(reserveId, amount, caller);
  }

  function _repay(ISpoke spoke, uint reserveId) internal {
    (, address caller, ) = vm.readCallers();
    uint amount = (spoke.getUserTotalDebt(reserveId, caller) * 3) / 5;
    ISpoke.Reserve memory reserve = spoke.getReserve(reserveId);

    TestnetERC20 token = TestnetERC20(reserve.underlying);
    token.approve(address(spoke), amount);
    console.log('repay approved');
    _mint(token, amount);

    if (amount != 0) spoke.repay(reserveId, amount, caller);
  }

  function _getAmount(
    uint targetPrice,
    ISpoke spoke,
    uint reserveId,
    TestnetERC20 token
  ) internal view returns (uint) {
    uint currentPrice = IAaveOracle(spoke.ORACLE()).getReservePrice(reserveId);
    return (targetPrice * (10 ** token.decimals())) / currentPrice;
  }

  function _mint(TestnetERC20 token, uint amount) internal {
    // if (
    //   keccak256(abi.encode(TestnetERC20(token).name())) == keccak256(abi.encode('Wrapped Ether'))
    // ) {
    //   WETH9(payable(address(token))).deposit{value: amount}();
    // } else token.mint(amount);
    (, address caller, ) = vm.readCallers();
    // vm.rpc(
    //   'tenderly_setErc20Balance',
    //   string.concat(
    //     '["',
    //     vm.toString(address(token)),
    //     '", "',
    //     vm.toString(caller),
    //     '", "0x13DA329B633647180000000000"]'
    //   )
    // );
    // assertGe(token.balanceOf(caller), amount);
  }

  function _mint(address token, uint amount) internal {
    _mint(TestnetERC20(token), amount);
  }
}
