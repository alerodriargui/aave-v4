// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script, stdJson, console2 as console} from 'forge-std/Script.sol';
import {StdAssertions} from 'forge-std/StdAssertions.sol';
import {Hub, IHub} from 'src/contracts/Hub.sol';
import {Spoke, ISpoke} from 'src/contracts/Spoke.sol';
import {TreasurySpoke} from 'src/contracts/TreasurySpoke.sol';
import {AccessManager} from 'src/dependencies/openzeppelin/AccessManager.sol';
import {TestnetERC20} from 'tests/mocks/TestnetERC20.sol';
import {MockPriceFeed} from 'tests/mocks/MockPriceFeed.sol';
import {AaveOracle, IAaveOracle} from 'src/contracts/AaveOracle.sol';
import {Roles} from 'src/libraries/types/Roles.sol';
import {DataTypes} from 'src/libraries/types/DataTypes.sol';
import {IAssetInterestRateStrategy} from 'src/interfaces/IAssetInterestRateStrategy.sol';
import {AssetInterestRateStrategy} from 'src/contracts/AssetInterestRateStrategy.sol';
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

contract Deploy is Script, StdAssertions {
  using stdJson for string;
  using SafeCast for *;

  /// ---------- TOKEN -----------
  struct Token {
    address token;
    address priceSource;
  }
  mapping(string key => Token token) internal tokens;
  bool tokenSetup;

  function run() external {
    vm.startBroadcast();
    setUpTokens();
    setUpHubs();
    setUpReserves();
    logAddy();
    // seed();
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
    return t;
  }

  // -------------------

  string internal constant CORE_HUB = 'CORE_HUB';
  string internal constant ISO_GOV_HUB = 'ISO_GOV_HUB';
  string internal constant ISO_STABLE_HUB = 'ISO_STABLE_HUB';

  struct SpokeListConfig {
    string assetKey;
    string spokeKey;
    uint56 addCap;
    uint56 drawCap;
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
      console.log('-----CORE_HUB-----');
      Hub coreHub = new Hub(address(ACCESS_MANAGER));
      hubs[CORE_HUB] = HubGlobalConfig(
        coreHub,
        new TreasurySpoke(ADMIN, address(coreHub)),
        new AssetInterestRateStrategy(address(coreHub))
      );
      setUpRoles(CORE_HUB);

      AssetConfig[7] memory assetConfigs = [
        AssetConfig({
          key: WETH,
          liquidityFee: 10_00,
          irData: IAssetInterestRateStrategy.InterestRateData(90_00, 0, 2_70, 80_00)
        }),
        AssetConfig({
          key: cbBTC,
          liquidityFee: 50_00,
          irData: IAssetInterestRateStrategy.InterestRateData(80_00, 0, 4_00, 60_00)
        }),
        AssetConfig({
          key: WBTC,
          liquidityFee: 50_00,
          irData: IAssetInterestRateStrategy.InterestRateData(80_00, 30, 4_00, 300_00)
        }),
        AssetConfig({
          key: USDS,
          liquidityFee: 10_00,
          irData: IAssetInterestRateStrategy.InterestRateData(92_00, 4_50, 75, 35_00)
        }),
        AssetConfig({
          key: USDC,
          liquidityFee: 10_00,
          irData: IAssetInterestRateStrategy.InterestRateData(92_00, 0, 5_50, 35_00)
        }),
        AssetConfig({
          key: GHO,
          liquidityFee: 5_00,
          irData: IAssetInterestRateStrategy.InterestRateData(92_00, 0, 5_50, 35_00)
        }),
        AssetConfig({
          key: wstETH,
          liquidityFee: 5_00,
          irData: IAssetInterestRateStrategy.InterestRateData(90_00, 0, 55, 85_00)
        })
      ];
      SpokeListConfig[12] memory spokeConfigs = [
        // ---- CORE_SPOKE -----
        SpokeListConfig({assetKey: WETH, spokeKey: CORE_SPOKE, addCap: 90_000, drawCap: 0}),
        SpokeListConfig({assetKey: cbBTC, spokeKey: CORE_SPOKE, addCap: 100_000, drawCap: 0}),
        SpokeListConfig({assetKey: WBTC, spokeKey: CORE_SPOKE, addCap: 100_000, drawCap: 0}),
        SpokeListConfig({
          assetKey: USDS,
          spokeKey: CORE_SPOKE,
          addCap: 2_000_000,
          drawCap: 1_800_000
        }),
        SpokeListConfig({
          assetKey: USDC,
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
        SpokeListConfig({assetKey: wstETH, spokeKey: CORE_SPOKE, addCap: 60_000, drawCap: 0}),
        // ---- E_MODE_SPOKE -----
        SpokeListConfig({assetKey: WETH, spokeKey: E_MODE_SPOKE, addCap: 90_000, drawCap: 80_000}),
        SpokeListConfig({assetKey: wstETH, spokeKey: E_MODE_SPOKE, addCap: 80_000, drawCap: 0}),
        // ---- ISO_GOV_SPOKE -----
        SpokeListConfig({assetKey: USDC, spokeKey: ISO_GOV_SPOKE, addCap: 0, drawCap: 1_000_000}),
        SpokeListConfig({assetKey: GHO, spokeKey: ISO_GOV_SPOKE, addCap: 0, drawCap: 2_000_000}),
        // ---- ISO_STABLE_SPOKE -----
        SpokeListConfig({assetKey: USDC, spokeKey: ISO_STABLE_SPOKE, addCap: 0, drawCap: 2_000_000})
      ];

      console.log('\nAssetListing');
      for (uint i; i < assetConfigs.length; ++i) _process(CORE_HUB, assetConfigs[i]);
      console.log('\nSpokeListing');
      for (uint i; i < spokeConfigs.length; ++i) _process(CORE_HUB, spokeConfigs[i]);
      console.log('---------');
    }

    {
      console.log('----- ISO_GOV_HUB -----');
      Hub isoGovHub = new Hub(address(ACCESS_MANAGER));
      hubs[ISO_GOV_HUB] = HubGlobalConfig(
        isoGovHub,
        new TreasurySpoke(ADMIN, address(isoGovHub)),
        new AssetInterestRateStrategy(address(isoGovHub))
      );
      setUpRoles(ISO_GOV_HUB);

      AssetConfig[6] memory assetConfigs = [
        AssetConfig({
          key: AAVE,
          liquidityFee: 10_00,
          irData: IAssetInterestRateStrategy.InterestRateData(45_00, 0, 7_00, 300_00)
        }),
        AssetConfig({
          key: UNI,
          liquidityFee: 50_00,
          irData: IAssetInterestRateStrategy.InterestRateData(45_00, 0, 7_00, 300_00)
        }),
        AssetConfig({
          key: MKR,
          liquidityFee: 20_00,
          irData: IAssetInterestRateStrategy.InterestRateData(45_00, 0, 7_00, 300_00)
        }),
        AssetConfig({
          key: USDS,
          liquidityFee: 10_00,
          irData: IAssetInterestRateStrategy.InterestRateData(92_00, 4_50, 75, 35_00)
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
      SpokeListConfig[6] memory spokeConfigs = [
        // ---- ISO_GOV_SPOKE -----
        SpokeListConfig({assetKey: AAVE, spokeKey: ISO_GOV_SPOKE, addCap: 90_000, drawCap: 0}),
        SpokeListConfig({assetKey: UNI, spokeKey: ISO_GOV_SPOKE, addCap: 20_000_000, drawCap: 0}),
        SpokeListConfig({assetKey: MKR, spokeKey: ISO_GOV_SPOKE, addCap: 20_000_000, drawCap: 0}),
        SpokeListConfig({
          assetKey: USDS,
          spokeKey: ISO_GOV_SPOKE,
          addCap: 20_000_000,
          drawCap: 18_000_000
        }),
        SpokeListConfig({
          assetKey: USDC,
          spokeKey: ISO_GOV_SPOKE,
          addCap: 3_000_000,
          drawCap: 2_760_000
        }),
        SpokeListConfig({
          assetKey: GHO,
          spokeKey: ISO_GOV_SPOKE,
          addCap: 8_000_000,
          drawCap: 5_500_000
        })
      ];

      console.log('\nAssetListing');
      for (uint i; i < assetConfigs.length; ++i) _process(ISO_GOV_HUB, assetConfigs[i]);
      console.log('\nSpokeListing');
      for (uint i; i < spokeConfigs.length; ++i) _process(ISO_GOV_HUB, spokeConfigs[i]);
      console.log('---------');
    }

    {
      console.log('----- ISO_STABLE_HUB -----');
      Hub isoGovHub = new Hub(address(ACCESS_MANAGER));
      hubs[ISO_STABLE_HUB] = HubGlobalConfig(
        isoGovHub,
        new TreasurySpoke(ADMIN, address(isoGovHub)),
        new AssetInterestRateStrategy(address(isoGovHub))
      );
      setUpRoles(ISO_STABLE_HUB);

      AssetConfig[2] memory assetConfigs = [
        AssetConfig({
          key: USDC,
          liquidityFee: 10_00,
          irData: IAssetInterestRateStrategy.InterestRateData(92_00, 0, 5_50, 35_00)
        }),
        AssetConfig({
          key: sUSDe,
          liquidityFee: 10_00,
          irData: IAssetInterestRateStrategy.InterestRateData(90_00, 0, 5_50, 85_00)
        })
      ];
      SpokeListConfig[2] memory spokeConfigs = [
        // ---- ISO_STABLE_SPOKE -----
        SpokeListConfig({
          assetKey: USDC,
          spokeKey: ISO_STABLE_SPOKE,
          addCap: 5_000_000,
          drawCap: 4_760_000
        }),
        SpokeListConfig({
          assetKey: sUSDe,
          spokeKey: ISO_STABLE_SPOKE,
          addCap: 5_000_000,
          drawCap: 0
        })
      ];

      console.log('\nAssetListing');
      for (uint i; i < assetConfigs.length; ++i) _process(ISO_STABLE_HUB, assetConfigs[i]);
      console.log('\nSpokeListing');
      for (uint i; i < spokeConfigs.length; ++i) _process(ISO_STABLE_HUB, spokeConfigs[i]);
      console.log('---------');
    }

    hubSetup = true;
  }

  struct ReserveConfig {
    string assetKey;
    string hubKey;
    bool collateral;
    bool borrowable;
    uint32 liquidationBonus;
    uint24 collateralRisk;
    uint16 collateralFactor;
    uint16 liquidationFee;
  }

  function setUpReserves() public {
    require(hubSetup, 'hub setup required');

    {
      console.log('-----CORE_SPOKE-----');
      ReserveConfig[7] memory reserveConf = [
        ReserveConfig({
          assetKey: WETH,
          hubKey: CORE_HUB,
          collateral: true,
          borrowable: false,
          liquidationBonus: 105_00,
          collateralRisk: 0,
          collateralFactor: 85_00,
          liquidationFee: 10_00 //
        }),
        ReserveConfig({
          assetKey: cbBTC,
          hubKey: CORE_HUB,
          collateral: true,
          borrowable: false,
          liquidationBonus: 107_50,
          collateralRisk: 4_50,
          collateralFactor: 78_00,
          liquidationFee: 10_00
        }),
        ReserveConfig({
          assetKey: WBTC,
          hubKey: CORE_HUB,
          collateral: true,
          borrowable: false,
          liquidationBonus: 105_00,
          collateralRisk: 5_00,
          collateralFactor: 78_00,
          liquidationFee: 10_00
        }),
        ReserveConfig({
          assetKey: USDS,
          hubKey: CORE_HUB,
          collateral: true,
          borrowable: true,
          liquidationBonus: 100_00,
          collateralRisk: 0,
          collateralFactor: 0,
          liquidationFee: 10_00
        }),
        ReserveConfig({
          assetKey: USDC,
          hubKey: CORE_HUB,
          collateral: true,
          borrowable: true,
          liquidationBonus: 100_00,
          collateralRisk: 0,
          collateralFactor: 0,
          liquidationFee: 10_00
        }),
        ReserveConfig({
          assetKey: GHO,
          hubKey: CORE_HUB,
          collateral: true,
          borrowable: true,
          liquidationBonus: 100_00,
          collateralRisk: 0,
          collateralFactor: 0,
          liquidationFee: 10_00
        }),
        ReserveConfig({
          assetKey: wstETH,
          hubKey: CORE_HUB,
          collateral: true,
          borrowable: false,
          liquidationBonus: 106_00,
          collateralRisk: 3_00,
          collateralFactor: 83_00,
          liquidationFee: 10_00
        })
      ];

      console.log('\nReserveListing');
      for (uint i; i < reserveConf.length; ++i) _process(CORE_SPOKE, reserveConf[i]);
    }

    {
      console.log('-----E_MODE_SPOKE-----');
      ReserveConfig[2] memory reserveConf = [
        ReserveConfig({
          assetKey: WETH,
          hubKey: CORE_HUB,
          collateral: true,
          borrowable: true,
          liquidationBonus: 100_00,
          collateralRisk: 0,
          collateralFactor: 0, // why?
          liquidationFee: 10_00
        }),
        ReserveConfig({
          assetKey: wstETH,
          hubKey: CORE_HUB,
          collateral: true,
          borrowable: false,
          liquidationBonus: 106_00,
          collateralRisk: 3_00,
          collateralFactor: 93_00,
          liquidationFee: 10_00
        })
      ];

      console.log('\nReserveListing');
      for (uint i; i < reserveConf.length; ++i) _process(E_MODE_SPOKE, reserveConf[i]);
    }

    {
      console.log('-----ISO_GOV_SPOKE-----');
      ReserveConfig[8] memory reserveConf = [
        ReserveConfig({
          assetKey: AAVE,
          hubKey: ISO_GOV_HUB,
          collateral: true,
          borrowable: false,
          liquidationBonus: 107_50,
          collateralRisk: 20_00,
          collateralFactor: 76_00,
          liquidationFee: 10_00
        }),
        ReserveConfig({
          assetKey: UNI,
          hubKey: ISO_GOV_HUB,
          collateral: true,
          borrowable: false,
          liquidationBonus: 105_00,
          collateralRisk: 25_00,
          collateralFactor: 74_00,
          liquidationFee: 10_00
        }),
        ReserveConfig({
          assetKey: MKR,
          hubKey: ISO_GOV_HUB,
          collateral: true,
          borrowable: false,
          liquidationBonus: 108_50,
          collateralRisk: 30_00,
          collateralFactor: 70_00,
          liquidationFee: 10_00
        }),
        ReserveConfig({
          assetKey: USDS,
          hubKey: ISO_GOV_HUB,
          collateral: true,
          borrowable: true,
          liquidationBonus: 100_00,
          collateralRisk: 0,
          collateralFactor: 0,
          liquidationFee: 10_00
        }),
        ReserveConfig({
          assetKey: USDC,
          hubKey: ISO_GOV_HUB,
          collateral: true,
          borrowable: true,
          liquidationBonus: 100_00,
          collateralRisk: 10_00,
          collateralFactor: 80_00,
          liquidationFee: 10_00
        }),
        ReserveConfig({
          assetKey: GHO,
          hubKey: ISO_GOV_HUB,
          collateral: true,
          borrowable: true,
          liquidationBonus: 100_00,
          collateralRisk: 8_50,
          collateralFactor: 82_50,
          liquidationFee: 10_00
        }),
        // core hub
        ReserveConfig({
          assetKey: USDC,
          hubKey: CORE_HUB,
          collateral: false,
          borrowable: true,
          liquidationBonus: 100_00,
          collateralRisk: 0,
          collateralFactor: 0,
          liquidationFee: 10_00
        }),
        ReserveConfig({
          assetKey: GHO,
          hubKey: CORE_HUB,
          collateral: false,
          borrowable: true,
          liquidationBonus: 100_00,
          collateralRisk: 0,
          collateralFactor: 0,
          liquidationFee: 10_00
        })
      ];

      console.log('\nReserveListing');
      for (uint i; i < reserveConf.length; ++i) _process(ISO_GOV_SPOKE, reserveConf[i]);
    }

    {
      console.log('-----ISO_STABLE_SPOKE-----');
      ReserveConfig[3] memory reserveConf = [
        ReserveConfig({
          assetKey: USDC,
          hubKey: ISO_STABLE_HUB,
          collateral: true,
          borrowable: true,
          liquidationBonus: 100_00,
          collateralRisk: 10_00, //
          collateralFactor: 95_00, //
          liquidationFee: 10_00
        }),
        ReserveConfig({
          assetKey: sUSDe,
          hubKey: ISO_STABLE_HUB,
          collateral: true,
          borrowable: false,
          liquidationBonus: 108_50,
          collateralRisk: 8_00, //
          collateralFactor: 95_00, //
          liquidationFee: 10_00
        }),
        // CORE
        ReserveConfig({
          assetKey: USDC,
          hubKey: CORE_HUB,
          collateral: false,
          borrowable: true,
          liquidationBonus: 100_00,
          collateralRisk: 0,
          collateralFactor: 0,
          liquidationFee: 10_00
        })
      ];

      console.log('\nReserveListing');
      for (uint i; i < reserveConf.length; ++i) _process(ISO_STABLE_SPOKE, reserveConf[i]);
    }
  }

  function _process(string memory spokeKey, ReserveConfig memory conf) internal {
    console.log('hub\t\t\t\t\t', conf.hubKey);
    console.log('token\t\t\t\t\t', conf.assetKey);

    Hub hub = _hub(conf.hubKey).hub;
    Spoke spoke = _spoke(spokeKey);
    Token storage t = _token(conf.assetKey);
    uint assetId = _assetId(hub, t.token);

    DataTypes.ReserveConfig memory st = DataTypes.ReserveConfig({
      frozen: false,
      paused: false,
      borrowable: conf.borrowable,
      collateralRisk: conf.collateralRisk
    });
    DataTypes.DynamicReserveConfig memory dyn = DataTypes.DynamicReserveConfig({
      collateralFactor: conf.collateralFactor.toUint16(),
      liquidationBonus: conf.liquidationBonus,
      liquidationFee: conf.liquidationFee
    });

    uint reserveId = spoke.addReserve(address(hub), assetId, t.priceSource, st, dyn);

    assertEq(abi.encode(spoke.getReserveConfig(reserveId)), abi.encode(st));
    assertEq(abi.encode(spoke.getDynamicReserveConfig(reserveId)), abi.encode(dyn));

    console.log('reserveId\t\t\t\t', reserveId);
    console.log('assetId\t\t\t\t', assetId);
    console.log('frozen\t\t\t\t', st.frozen);
    console.log('paused\t\t\t\t', st.paused);
    console.log('borrowable\t\t\t\t', st.borrowable);
    console.log('collateralRisk\t\t\t', st.collateralRisk);
    console.log('liquidationBonus\t\t\t', dyn.liquidationBonus);
    console.log('liquidationFee\t\t\t', dyn.liquidationFee);
    console.log('collateralFactor\t\t\t', dyn.collateralFactor);
    console.log('price feed\t\t\t\t', spoke.oracle().getReserveSource(reserveId));
    console.log('price\t\t\t\t\t %e', spoke.oracle().getReservePrice(reserveId));
    console.log();
  }

  function _hub(string memory key) internal view returns (HubGlobalConfig storage) {
    HubGlobalConfig storage ret = hubs[key];
    require(address(ret.hub) != address(0), 'zero hub');
    return ret;
  }

  function _process(string memory hubKey, AssetConfig memory conf) internal {
    console.log('token\t\t\t\t\t', conf.key);

    HubGlobalConfig storage hubConf = _hub(hubKey);
    address token = _token(conf.key).token;

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
      DataTypes.AssetConfig memory assetConfig = hubConf.hub.getAssetConfig(assetId);
      assetConfig.liquidityFee = conf.liquidityFee;
      hubConf.hub.updateAssetConfig(assetId, assetConfig);
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
    Spoke spoke = _spoke(conf.spokeKey);
    address token = _token(conf.assetKey).token;
    uint assetId = _assetId(hub, token);

    hub.addSpoke(assetId, address(spoke), DataTypes.SpokeConfig(true, conf.addCap, conf.drawCap));
    DataTypes.SpokeConfig memory spokeConfig = hub.getSpokeConfig(assetId, address(spoke));
    assertEq(spokeConfig.addCap, conf.addCap);
    assertEq(spokeConfig.drawCap, conf.drawCap);
    assertTrue(spokeConfig.active);

    console.log('addCap\t\t\t\t %e', spokeConfig.addCap);
    console.log('drawCap\t\t\t\t %e', spokeConfig.drawCap);
    console.log('active\t\t\t\t', spokeConfig.active);
    console.log();
  }

  string internal constant CORE_SPOKE = 'CORE_SPOKE';
  string internal constant E_MODE_SPOKE = 'E_MODE_SPOKE';
  string internal constant ISO_GOV_SPOKE = 'ISO_GOV_SPOKE';
  string internal constant ISO_STABLE_SPOKE = 'ISO_STABLE_SPOKE';

  struct SpokeGlobalConfig {
    Spoke spoke;
  }
  mapping(string key => SpokeGlobalConfig spoke) internal spokes;

  function deploySpokes() internal {
    string[4] memory keys = [CORE_SPOKE, E_MODE_SPOKE, ISO_GOV_SPOKE, ISO_STABLE_SPOKE];

    for (uint i; i < keys.length; ++i) {
      Spoke s = new Spoke(address(ACCESS_MANAGER));
      s.updateOracle(address(new AaveOracle(address(s), 8, string.concat(keys[i], ' (USD)'))));
      spokes[keys[i]] = SpokeGlobalConfig(s);
    }
  }

  function _spoke(string memory key) internal view returns (Spoke) {
    SpokeGlobalConfig storage ret = spokes[key];
    require(address(ret.spoke) != address(0), 'zero spoke');
    return ret.spoke;
  }

  function setUpRoles(string memory hubKey) public {
    ACCESS_MANAGER.grantRole(Roles.HUB_ADMIN_ROLE, ADMIN, 0);
    ACCESS_MANAGER.grantRole(Roles.SPOKE_ADMIN_ROLE, ADMIN, 0);

    Hub hub = _hub(hubKey).hub;

    string[3] memory spokeKeys = [CORE_SPOKE, ISO_GOV_SPOKE, ISO_STABLE_SPOKE];
    for (uint i; i < spokeKeys.length; ++i) {
      Spoke spoke = _spoke(spokeKeys[i]);
      {
        bytes4[] memory selectors = new bytes4[](7);
        selectors[0] = ISpoke.updateOracle.selector;
        selectors[1] = ISpoke.updateReservePriceSource.selector;
        selectors[2] = ISpoke.updateLiquidationConfig.selector;
        selectors[3] = ISpoke.addReserve.selector;
        selectors[4] = ISpoke.updateReserveConfig.selector;
        selectors[5] = ISpoke.updateDynamicReserveConfig.selector;
        selectors[6] = ISpoke.updateUserRiskPremium.selector;
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
      string[3] memory keys = [CORE_HUB, ISO_GOV_HUB, ISO_STABLE_HUB];
      string memory HUBS;
      for (uint i; i < keys.length; ++i) {
        console.log(address(_hub(keys[i]).hub), keys[i]);
        HUBS = vm.serializeAddress('hub', keys[i], address(_hub(keys[i]).hub));
      }
      vm.serializeString(root, 'hub', HUBS);
    }

    {
      string[4] memory keys = [CORE_SPOKE, E_MODE_SPOKE, ISO_GOV_SPOKE, ISO_STABLE_SPOKE];
      string memory SPOKES;
      for (uint i; i < keys.length; ++i) {
        console.log(address(_spoke(keys[i])), keys[i]);
        SPOKES = vm.serializeAddress('spoke', keys[i], address(_spoke(keys[i])));
      }
      vm.serializeString(root, 'spoke', SPOKES);
    }
    {
      string[11] memory keys = [WETH, cbBTC, WBTC, wstETH, USDC, GHO, USDS, AAVE, MKR, UNI, sUSDe];
      string memory TOKENS;
      for (uint i; i < keys.length; ++i) {
        console.log(address(_token(keys[i]).token), keys[i]);
        TOKENS = vm.serializeAddress('token', keys[i], address(_token(keys[i]).token));
      }
      vm.serializeString(root, 'token', TOKENS);
    }
    root = vm.serializeString(root, 'commit', _commit());
    console.log(root);
    vm.writeJson(root, './output/deploy.json');
  }

  function load() public {
    string memory deploy = vm.readFile('./output/deploy.json');
    {
      string[3] memory keys = [CORE_HUB, ISO_GOV_HUB, ISO_STABLE_HUB];
      for (uint i; i < keys.length; ++i) {
        hubs[keys[i]].hub = Hub(deploy.readAddress(string.concat('.hub.', keys[i])));
        console.log(address(_hub(keys[i]).hub), keys[i]);
      }
    }
    {
      string[4] memory keys = [CORE_SPOKE, E_MODE_SPOKE, ISO_GOV_SPOKE, ISO_STABLE_SPOKE];
      for (uint i; i < keys.length; ++i) {
        spokes[keys[i]].spoke = Spoke(deploy.readAddress(string.concat('.spoke.', keys[i])));
        console.log(address(_spoke(keys[i])), keys[i]);
      }
    }
    {
      string[11] memory keys = [WETH, cbBTC, WBTC, wstETH, USDC, GHO, USDS, AAVE, MKR, UNI, sUSDe];
      for (uint i; i < keys.length; ++i) {
        tokens[keys[i]].token = deploy.readAddress(string.concat('.token.', keys[i]));
        console.log(address(_token(keys[i]).token), keys[i]);
      }
    }
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
      string[4] memory keys = [CORE_SPOKE, E_MODE_SPOKE, ISO_GOV_SPOKE, ISO_STABLE_SPOKE];
      for (uint i; i < keys.length; ++i) {
        Spoke spoke = _spoke(keys[i]);
        console.log(keys[i]);
        // _run(spoke, _supply);
        // _run(spoke, _withdraw);
        _run(spoke, _supply);
        _run(spoke, _borrow);
        _run(spoke, _repay);
        console.log();
      }
    }
  }

  function _run(Spoke spoke, function(Spoke, uint) internal _action) internal {
    uint reserveCount = spoke.getReserveCount();
    for (uint i; i < reserveCount; ++i) _action(spoke, i);
  }

  function _supply(Spoke spoke, uint reserveId) internal {
    (, address caller, ) = vm.readCallers();
    DataTypes.Reserve memory reserve = spoke.getReserve(reserveId);
    if (reserve.hub.getSpokeConfig(reserve.assetId, address(spoke)).addCap == 0) return;

    TestnetERC20 token = TestnetERC20(reserve.hub.getAsset(reserve.assetId).underlying);
    uint amount = _getAmount(bound(vm.randomUint(), 0.01e8, 100e8), spoke, reserveId, token);
    _mint(token, amount);

    token.approve(address(reserve.hub), amount);
    spoke.supply(reserveId, amount, caller);
    spoke.setUsingAsCollateral(reserveId, true, caller);
  }

  function _withdraw(Spoke spoke, uint reserveId) internal {
    (, address caller, ) = vm.readCallers();
    uint amount = bound(vm.randomUint(), 0, spoke.getUserSuppliedAmount(reserveId, caller));
    if (amount != 0) spoke.withdraw(reserveId, amount, caller);

    if (spoke.isUsingAsCollateral(reserveId, caller)) {
      spoke.setUsingAsCollateral(reserveId, false, caller);
      spoke.setUsingAsCollateral(reserveId, true, caller);
    }
  }

  function _borrow(Spoke spoke, uint reserveId) internal {
    if (!spoke.getReserveConfig(reserveId).borrowable) return;
    DataTypes.Reserve memory reserve = spoke.getReserve(reserveId);

    (, address caller, ) = vm.readCallers();
    TestnetERC20 token = TestnetERC20(reserve.hub.getAsset(reserve.assetId).underlying);
    uint amount = bound(vm.randomUint(), 2, 10 ** (token.decimals() - 3));
    if (amount != 0) spoke.borrow(reserveId, amount, caller);
  }

  function _repay(Spoke spoke, uint reserveId) internal {
    (, address caller, ) = vm.readCallers();
    uint amount = (spoke.getUserTotalDebt(reserveId, caller) * 3) / 5;
    DataTypes.Reserve memory reserve = spoke.getReserve(reserveId);

    TestnetERC20 token = TestnetERC20(reserve.hub.getAsset(reserve.assetId).underlying);
    token.approve(address(reserve.hub), amount);
    _mint(token, amount);

    if (amount != 0) spoke.repay(reserveId, amount, caller);
  }

  function _getAmount(
    uint targetPrice,
    Spoke spoke,
    uint reserveId,
    TestnetERC20 token
  ) internal view returns (uint) {
    uint currentPrice = spoke.oracle().getReservePrice(reserveId);
    return (targetPrice * (10 ** token.decimals())) / currentPrice;
  }

  function _mint(TestnetERC20 token, uint amount) internal {
    // if (
    //   keccak256(abi.encode(TestnetERC20(token).name())) == keccak256(abi.encode('Wrapped Ether'))
    // ) {
    //   WETH9(payable(address(token))).deposit{value: amount}();
    // } else token.mint(amount);
  }

  function _mint(address token, uint amount) internal {
    _mint(TestnetERC20(token), amount);
  }
}
