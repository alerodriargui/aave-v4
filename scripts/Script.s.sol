// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {Script, stdJson, console2 as console} from 'forge-std/Script.sol';
import {StdAssertions} from 'forge-std/StdAssertions.sol';
import {IHub} from 'src/hub/interfaces/IHub.sol';
import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';
import {SignatureGateway} from 'src/position-manager/SignatureGateway.sol';
import {NativeTokenGateway} from 'src/position-manager/NativeTokenGateway.sol';
import {IGatewayBase} from 'src/position-manager/interfaces/IGatewayBase.sol';
import {HubConfigurator} from 'src/hub/HubConfigurator.sol';
import {IHubConfigurator} from 'src/hub/interfaces/IHubConfigurator.sol';
import {SpokeConfigurator} from 'src/spoke/SpokeConfigurator.sol';
import {ISpokeConfigurator} from 'src/spoke/interfaces/ISpokeConfigurator.sol';

import {TreasurySpoke} from 'src/spoke/TreasurySpoke.sol';
import {AccessManager, IAccessManager} from 'src/dependencies/openzeppelin/AccessManager.sol';
import {TestnetERC20} from 'tests/mocks/TestnetERC20.sol';
import {MockPriceFeed} from 'tests/mocks/MockPriceFeed.sol';
import {AaveOracle, IAaveOracle} from 'src/spoke/AaveOracle.sol';
import {Ownable2Step} from 'src/dependencies/openzeppelin/Ownable2Step.sol';
import {Roles} from 'src/libraries/types/Roles.sol';
import {IAssetInterestRateStrategy} from 'src/hub/interfaces/IAssetInterestRateStrategy.sol';
import {AssetInterestRateStrategy} from 'src/hub/AssetInterestRateStrategy.sol';
import {WETH9} from 'src/dependencies/weth/WETH9.sol';
import {SafeCast} from 'src/dependencies/openzeppelin/SafeCast.sol';
import {SafeERC20, IERC20} from 'src/dependencies/openzeppelin/SafeERC20.sol';
import {DeployUtils} from 'tests/DeployUtils.sol';
import {SpokeDeployUtils} from './SpokeDeployUtils.sol';
import {ISpokeInstance} from 'tests/mocks/ISpokeInstance.sol';
import {ITokenizationSpoke} from 'src/spoke/interfaces/ITokenizationSpoke.sol';
import {TokenizationSpokeInstance} from 'src/spoke/instances/TokenizationSpokeInstance.sol';
import {ConfigReader} from './ConfigReader.sol';
import {DeployReader} from './DeployReader.sol';
import {ScriptUtils} from './ScriptUtils.sol';
import {DeployLogger} from './DeployLogger.sol';

contract Deploy is Script, StdAssertions {
  using stdJson for string;
  using SafeCast for *;
  using SafeERC20 for *;
  using ConfigReader for string;
  using DeployReader for string;

  // ==================== JSON Config ====================

  string internal _json;

  // Keys read from JSON (stored for logAddy)
  string[] internal _hubKeys;
  string[] internal _spokeKeys;
  string[] internal _tokenKeys;

  // ==================== Token ====================

  struct Token {
    address token;
    address priceFeed;
  }
  mapping(string key => Token token) internal tokens;
  bool tokenSetup;

  // ==================== Periphery ====================

  address signatureGateway;
  address nativeTokenGateway;

  // ==================== Configurators ====================

  address hubConfigurator;
  address spokeConfigurator;

  // ==================== Hub ====================

  struct HubGlobalConfig {
    IHub hub;
    TreasurySpoke treasury;
    AssetInterestRateStrategy irStrategy;
  }
  mapping(string key => HubGlobalConfig conf) hubs;
  AccessManager internal ACCESS_MANAGER;
  address public ADMIN;
  bool hubSetup;

  // ==================== Spoke ====================

  struct SpokeGlobalConfig {
    ISpoke spoke;
    address oracle;
  }
  mapping(string key => SpokeGlobalConfig spoke) internal spokes;

  // ==================== Tokenization Spoke ====================

  mapping(string key => address) internal tokenizationSpokes;
  string[] internal _tokenizationSpokeKeys;

  // ==================== Entry Points ====================

  function run() external {
    vm.startBroadcast();
    _loadConfig();
    setUpTokens();
    setUpHubs();
    setUpReserves();
    periphery();
    _deployConfigurators();
    logAddy();
  }

  // ==================== Config Loading ====================

  function _loadConfig() internal {
    string memory configPath = vm.envOr('CONFIG_PATH', string('config/mainnet.json'));
    _json = vm.readFile(configPath);
  }

  // ==================== Token Setup ====================

  function setUpTokens() public {
    _tokenKeys = _json.tokenKeys();
    for (uint i; i < _tokenKeys.length; ++i) {
      tokens[_tokenKeys[i]] = Token(
        _json.tokenAddress(_tokenKeys[i]),
        _json.tokenPriceFeed(_tokenKeys[i])
      );
    }
    _deployMockPriceFeeds();
    tokenSetup = true;
  }

  /// @dev Temporary: deploy mock feeds for tokens without real Chainlink feeds.
  /// Remove once real feeds are available.
  function _deployMockPriceFeeds() internal {
    if (tokens['wstETH'].priceFeed == address(0)) {
      tokens['wstETH'].priceFeed = _deployMockPriceFeed(550429206740, 'wstETH');
    }
    if (tokens['LDO'].priceFeed == address(0)) {
      tokens['LDO'].priceFeed = _deployMockPriceFeed(85721424, 'LDO');
    }
  }

  // ==================== Hub Setup ====================

  function setUpHubs() public {
    require(tokenSetup, 'token setup required');
    (, address caller, ) = vm.readCallers();
    ADMIN = caller;
    ACCESS_MANAGER = new AccessManager(ADMIN);

    // Deploy all spokes first (oracles need predicted spoke address)
    deploySpokes();

    // Deploy hubs, list assets, register spokes
    for (uint hi = 0; _json.hubExists(hi); hi++) {
      string memory hubKey = _json.hubKey(hi);
      DeployLogger.logSection(hubKey);

      IHub hub = DeployUtils.deployHub(
        address(ACCESS_MANAGER),
        keccak256(abi.encodePacked(hubKey))
      );
      hubs[hubKey] = HubGlobalConfig(
        hub,
        new TreasurySpoke(ADMIN, address(hub)),
        new AssetInterestRateStrategy(address(hub))
      );
      _hubKeys.push(hubKey);
      setUpRoles(hubKey);
    }

    // List assets on hubs
    DeployLogger.logSection('Asset Listing');
    for (uint ai = 0; _json.assetExists(ai); ai++) {
      _processAsset(_json.readAsset(ai));
    }

    // Register spokes on hub assets
    DeployLogger.logSection('Spoke Registration');
    for (uint si = 0; _json.spokeRegExists(si); si++) {
      _processSpokeReg(_json.readSpokeReg(si));
    }

    // Deploy tokenization spokes for all enabled assets
    deployTokenizationSpokes();

    hubSetup = true;
  }

  // ==================== Reserve Setup ====================

  function setUpReserves() public {
    require(hubSetup, 'hub setup required');

    DeployLogger.logSection('Reserve Listing');
    for (uint ri = 0; _json.reserveExists(ri); ri++) {
      _processReserve(_json.readReserve(ri));
    }

    // Apply liquidation configs to spokes
    for (uint i; i < _spokeKeys.length; ++i) {
      (ISpoke.LiquidationConfig memory lc, bool exists) = _json.readLiquidationConfig(i);
      if (exists) {
        _spoke(_spokeKeys[i]).updateLiquidationConfig(lc);
        DeployLogger.logLiquidationConfig(_spokeKeys[i], lc);
      }
    }
  }

  // ==================== Periphery ====================

  function periphery() public {
    (, address caller, ) = vm.readCallers();

    bool deploySigGw = _json.deploySignatureGateway();
    bool deployNativeGw = _json.deployNativeTokenGateway();

    if (deploySigGw) {
      signatureGateway = address(new SignatureGateway(caller));
      DeployLogger.logPeriphery('signatureGateway', signatureGateway);
    }
    if (deployNativeGw) {
      nativeTokenGateway = address(
        new NativeTokenGateway(tokens[_json.nativeTokenKey()].token, caller)
      );
      DeployLogger.logPeriphery('nativeTokenGateway', nativeTokenGateway);
    }

    for (uint i; i < _spokeKeys.length; ++i) {
      ConfigReader.SpokeDeployConfig memory sc = _json.readSpoke(i);
      if (!sc.registerOnPositionManagers) continue;

      ISpoke spoke = _spoke(_spokeKeys[i]);
      DeployLogger.logMessage(
        'positionManagerRegistered',
        string.concat('registered for: ', _spokeKeys[i])
      );
      if (deploySigGw) {
        IGatewayBase(signatureGateway).registerSpoke(address(spoke), true);
        spoke.updatePositionManager(signatureGateway, true);
      }
      if (deployNativeGw) {
        IGatewayBase(nativeTokenGateway).registerSpoke(address(spoke), true);
        spoke.updatePositionManager(nativeTokenGateway, true);
      }
    }
  }

  // ==================== Spoke Deployment ====================

  function deploySpokes() internal {
    (, address deployer, ) = vm.readCallers();

    address liquidationLogic = SpokeDeployUtils._getLiquidationLogicAddress();
    require(
      liquidationLogic.code.length > 0,
      'LiquidationLogic not deployed. Run LibraryPreCompile first.'
    );

    for (uint si = 0; _json.spokeExists(si); si++) {
      ConfigReader.SpokeDeployConfig memory sc = _json.readSpoke(si);
      _spokeKeys.push(sc.key);

      IAaveOracle oracle = new AaveOracle(sc.oracleDecimals, string.concat(sc.key, ' (USD)'));

      ISpoke spoke = SpokeDeployUtils.deploySpoke(
        address(oracle),
        sc.maxUserReservesLimit,
        deployer,
        abi.encodeCall(ISpokeInstance.initialize, (address(ACCESS_MANAGER)))
      );

      oracle.setSpoke(address(spoke));

      assertEq(spoke.ORACLE(), address(oracle));
      assertEq(oracle.SPOKE(), address(spoke));

      spokes[sc.key] = SpokeGlobalConfig(spoke, address(oracle));
      DeployLogger.logSpokeDeployed(sc.key, address(spoke));
    }
  }

  // ==================== Tokenization Spoke Deployment ====================

  function deployTokenizationSpokes() internal {
    (, address deployer, ) = vm.readCallers();
    DeployLogger.logSection('Tokenization Spoke Deployment');

    for (uint ai = 0; _json.assetExists(ai); ai++) {
      ConfigReader.AssetConfig memory asset = _json.readAsset(ai);
      if (!asset.tokenizeEnabled) continue;
      _deployOneTokenizationSpoke(asset, deployer);
    }
  }

  function _deployOneTokenizationSpoke(
    ConfigReader.AssetConfig memory asset,
    address deployer
  ) internal {
    IHub hub = _hub(asset.hubKey).hub;
    uint assetId = ScriptUtils.assetId(hub, address(_token(asset.tokenKey).token));

    string memory hubPrefix = ConfigReader.trimEnd(asset.hubKey, 4); // strip "_HUB"
    string memory tsKey = string.concat(asset.tokenKey, '_', hubPrefix);

    // Deploy impl + proxy
    address ts;
    {
      address impl = address(new TokenizationSpokeInstance(address(hub), assetId));
      string memory shareName = string.concat(hubPrefix, ' ', asset.tokenKey);
      string memory shareSymbol = string.concat('t', asset.tokenKey, '-', hubPrefix);
      ts = DeployUtils.proxify(
        impl,
        deployer,
        abi.encodeCall(TokenizationSpokeInstance.initialize, (shareName, shareSymbol))
      );
    }

    // Register on hub (supply-only: drawCap=0)
    hub.addSpoke(
      assetId,
      ts,
      IHub.SpokeConfig({
        addCap: asset.tokenizeAddCap,
        drawCap: 0,
        riskPremiumThreshold: 0,
        active: true,
        halted: false
      })
    );

    tokenizationSpokes[tsKey] = ts;
    _tokenizationSpokeKeys.push(tsKey);
    DeployLogger.logTokenizationSpokeDeployed(tsKey, ts);
  }

  // ==================== Roles ====================

  function setUpRoles(string memory hubKey) public {
    ACCESS_MANAGER.grantRole(Roles.HUB_ADMIN_ROLE, ADMIN, 0);
    ACCESS_MANAGER.grantRole(Roles.SPOKE_ADMIN_ROLE, ADMIN, 0);

    IHub hub = _hub(hubKey).hub;

    for (uint i; i < _spokeKeys.length; ++i) {
      ISpoke spoke = _spoke(_spokeKeys[i]);
      {
        bytes4[] memory selectors = new bytes4[](7);
        selectors[0] = ISpoke.updateLiquidationConfig.selector;
        selectors[1] = ISpoke.addReserve.selector;
        selectors[2] = ISpoke.updateReserveConfig.selector;
        selectors[3] = ISpoke.updateDynamicReserveConfig.selector;
        selectors[4] = ISpoke.addDynamicReserveConfig.selector;
        selectors[5] = ISpoke.updatePositionManager.selector;
        selectors[6] = ISpoke.updateReservePriceSource.selector;
        ACCESS_MANAGER.setTargetFunctionRole(address(spoke), selectors, Roles.SPOKE_ADMIN_ROLE);
      }

      {
        bytes4[] memory selectors = new bytes4[](2);
        selectors[0] = ISpoke.updateUserDynamicConfig.selector;
        selectors[1] = ISpoke.updateUserRiskPremium.selector;
        ACCESS_MANAGER.setTargetFunctionRole(
          address(spoke),
          selectors,
          Roles.USER_POSITION_UPDATER_ROLE
        );
      }
    }

    {
      bytes4[] memory selectors = new bytes4[](6);
      selectors[0] = IHub.addAsset.selector;
      selectors[1] = IHub.updateAssetConfig.selector;
      selectors[2] = IHub.addSpoke.selector;
      selectors[3] = IHub.updateSpokeConfig.selector;
      selectors[4] = IHub.setInterestRateData.selector;
      selectors[5] = IHub.mintFeeShares.selector;
      ACCESS_MANAGER.setTargetFunctionRole(address(hub), selectors, Roles.HUB_ADMIN_ROLE);
    }

    {
      bytes4[] memory selectors = new bytes4[](1);
      selectors[0] = IHub.eliminateDeficit.selector;
      ACCESS_MANAGER.setTargetFunctionRole(address(hub), selectors, Roles.DEFICIT_ELIMINATOR_ROLE);
    }
  }

  // ==================== Process: Asset Listing ====================

  function _processAsset(ConfigReader.AssetConfig memory conf) internal {
    HubGlobalConfig storage hubConf = _hub(conf.hubKey);
    address token = address(_token(conf.tokenKey).token);

    uint assetId = hubConf.hub.addAsset(
      address(token),
      TestnetERC20(token).decimals(),
      address(hubConf.treasury),
      address(hubConf.irStrategy),
      abi.encode(conf.irData)
    );
    assertEq(assetId, ScriptUtils.assetId(hubConf.hub, token));
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

    DeployLogger.logAssetListed(
      conf,
      assetId,
      address(hubConf.treasury),
      address(hubConf.irStrategy)
    );
  }

  // ==================== Process: Spoke Registration ====================

  function _processSpokeReg(ConfigReader.SpokeRegConfig memory conf) internal {
    IHub hub = _hub(conf.hubKey).hub;
    ISpoke spoke = _spoke(conf.spokeKey);
    address token = address(_token(conf.assetKey).token);
    uint assetId = ScriptUtils.assetId(hub, token);

    hub.addSpoke(
      assetId,
      address(spoke),
      IHub.SpokeConfig({
        addCap: conf.addCap,
        drawCap: conf.drawCap,
        riskPremiumThreshold: conf.riskPremiumThreshold,
        active: conf.active,
        halted: conf.halted
      })
    );
    IHub.SpokeConfig memory spokeConfig = hub.getSpokeConfig(assetId, address(spoke));
    assertEq(spokeConfig.addCap, conf.addCap);
    assertEq(spokeConfig.drawCap, conf.drawCap);
    assertTrue(spokeConfig.active);

    DeployLogger.logSpokeRegistered(conf, spokeConfig);
  }

  // ==================== Process: Reserve Listing ====================

  function _processReserve(ConfigReader.ReserveConfig memory conf) internal {
    IHub hub = _hub(conf.hubKey).hub;
    ISpoke spoke = _spoke(conf.spokeKey);
    Token storage t = _token(conf.assetKey);
    uint assetId = ScriptUtils.assetId(hub, address(t.token));

    ISpoke.ReserveConfig memory st = ISpoke.ReserveConfig({
      receiveSharesEnabled: conf.receiveSharesEnabled,
      frozen: conf.frozen,
      paused: conf.paused,
      borrowable: conf.borrowable,
      collateralRisk: conf.collateralRisk
    });
    ISpoke.DynamicReserveConfig memory dyn = ISpoke.DynamicReserveConfig({
      collateralFactor: conf.collateralFactor,
      maxLiquidationBonus: conf.maxLiquidationBonus,
      liquidationFee: conf.liquidationFee
    });
    require(address(t.priceFeed) != address(0), 'price feed unset');
    uint reserveId = spoke.addReserve(address(hub), assetId, t.priceFeed, st, dyn);

    assertEq(abi.encode(spoke.getReserveConfig(reserveId)), abi.encode(st));
    assertEq(
      abi.encode(
        spoke.getDynamicReserveConfig(reserveId, spoke.getReserve(reserveId).dynamicConfigKey)
      ),
      abi.encode(dyn)
    );

    DeployLogger.logReserveListed(
      conf,
      reserveId,
      assetId,
      st,
      dyn,
      IAaveOracle(spoke.ORACLE()).getReserveSource(reserveId),
      IAaveOracle(spoke.ORACLE()).getReservePrice(reserveId)
    );
  }

  // ==================== Update: Spoke Config ====================

  function _updateSpokeReg(ConfigReader.SpokeRegConfig memory conf) internal {
    IHub hub = _hub(conf.hubKey).hub;
    ISpoke spoke = _spoke(conf.spokeKey);
    address token = address(_token(conf.assetKey).token);
    uint assetId = ScriptUtils.assetId(hub, token);
    IHub.SpokeConfig memory spokeConfig = hub.getSpokeConfig(assetId, address(spoke));

    spokeConfig.addCap = conf.addCap;
    spokeConfig.drawCap = conf.drawCap;
    hub.updateSpokeConfig(assetId, address(spoke), spokeConfig);

    spokeConfig = hub.getSpokeConfig(assetId, address(spoke));
    assertEq(spokeConfig.addCap, conf.addCap);
    assertEq(spokeConfig.drawCap, conf.drawCap);
    assertTrue(spokeConfig.active);

    DeployLogger.logSpokeUpdated(conf, spokeConfig);
  }

  // ==================== Resolution Helpers ====================

  function _token(string memory key) internal view returns (Token storage) {
    Token storage t = tokens[key];
    require(address(t.token) != address(0), 'token unset');
    return t;
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

  function _spoke(string memory key) internal view returns (ISpoke) {
    SpokeGlobalConfig storage ret = spokes[key];
    require(address(ret.spoke) != address(0), 'zero spoke');
    return ret.spoke;
  }

  // ==================== Output ====================

  function logAddy() public {
    string memory root = 'root';
    {
      string memory HUBS;
      string memory IR_STRATEGIES;
      string memory TREASURIES;
      for (uint i; i < _hubKeys.length; ++i) {
        console.log(address(_hub(_hubKeys[i]).hub), _hubKeys[i]);
        HUBS = vm.serializeAddress('hub', _hubKeys[i], address(_hub(_hubKeys[i]).hub));
        IR_STRATEGIES = vm.serializeAddress(
          'irStrategy',
          _hubKeys[i],
          address(_hub(_hubKeys[i]).irStrategy)
        );
        TREASURIES = vm.serializeAddress(
          'treasury',
          _hubKeys[i],
          address(_hub(_hubKeys[i]).treasury)
        );
      }
      vm.serializeString(root, 'hub', HUBS);
      vm.serializeString(root, 'irStrategy', IR_STRATEGIES);
      vm.serializeString(root, 'treasury', TREASURIES);
    }

    {
      string memory SPOKES;
      string memory ORACLES;
      for (uint i; i < _spokeKeys.length; ++i) {
        console.log(address(_spoke(_spokeKeys[i])), _spokeKeys[i]);
        SPOKES = vm.serializeAddress('spoke', _spokeKeys[i], address(_spoke(_spokeKeys[i])));
        ORACLES = vm.serializeAddress('oracle', _spokeKeys[i], spokes[_spokeKeys[i]].oracle);
      }
      vm.serializeString(root, 'spoke', SPOKES);
      vm.serializeString(root, 'oracle', ORACLES);
    }
    {
      string memory TOKENS;
      for (uint i; i < _tokenKeys.length; ++i) {
        console.log(address(_token(_tokenKeys[i]).token), _tokenKeys[i]);
        TOKENS = vm.serializeAddress('token', _tokenKeys[i], address(_token(_tokenKeys[i]).token));
      }
      vm.serializeString(root, 'token', TOKENS);
    }
    {
      string memory TOKENIZED;
      for (uint i; i < _tokenizationSpokeKeys.length; ++i) {
        TOKENIZED = vm.serializeAddress(
          'tokenized',
          _tokenizationSpokeKeys[i],
          tokenizationSpokes[_tokenizationSpokeKeys[i]]
        );
      }
      if (_tokenizationSpokeKeys.length > 0) {
        vm.serializeString(root, 'tokenized', TOKENIZED);
      }
    }
    {
      vm.serializeAddress(root, 'admin', ADMIN);
      vm.serializeAddress(root, 'accessManager', address(ACCESS_MANAGER));
      vm.serializeAddress(root, 'signatureGateway', signatureGateway);
      vm.serializeAddress(root, 'nativeTokenGateway', nativeTokenGateway);
      vm.serializeAddress(root, 'hubConfigurator', hubConfigurator);
      vm.serializeAddress(root, 'spokeConfigurator', spokeConfigurator);
    }
    root = vm.serializeString(root, 'commit', ScriptUtils.commit());
    console.log(root);
    vm.writeJson(root, './output/deploy.json');
  }

  // ==================== Load (for debug / incremental) ====================

  function load() public {
    string memory deploy = vm.readFile('./output/deploy.json');

    // Load hub/spoke keys from JSON config
    for (uint hi = 0; _json.hubExists(hi); hi++) {
      _hubKeys.push(_json.hubKey(hi));
    }
    for (uint si = 0; _json.spokeExists(si); si++) {
      _spokeKeys.push(_json.spokeKey(si));
    }

    ADMIN = deploy.admin();
    ACCESS_MANAGER = AccessManager(deploy.accessManager());
    vm.label(address(ACCESS_MANAGER), 'AccessManager');

    for (uint i; i < _hubKeys.length; ++i) {
      string memory key = _hubKeys[i];
      hubs[key].hub = IHub(deploy.hub(key));
      hubs[key].irStrategy = AssetInterestRateStrategy(deploy.irStrategy(key));
      hubs[key].treasury = TreasurySpoke(deploy.treasury(key));
      console.log(address(hubs[key].hub), key);
      vm.label(address(hubs[key].hub), key);
    }

    for (uint i; i < _spokeKeys.length; ++i) {
      string memory key = _spokeKeys[i];
      spokes[key].spoke = ISpoke(deploy.spoke(key));
      spokes[key].oracle = deploy.oracle(key);
      console.log(address(spokes[key].spoke), key);
      vm.label(address(spokes[key].spoke), key);
    }

    // Load tokenization spokes
    for (uint ai = 0; _json.assetExists(ai); ai++) {
      ConfigReader.AssetConfig memory asset = _json.readAsset(ai);
      if (!asset.tokenizeEnabled) continue;
      string memory hubPrefix = ConfigReader.trimEnd(asset.hubKey, 4);
      string memory tsKey = string.concat(asset.tokenKey, '_', hubPrefix);
      _tokenizationSpokeKeys.push(tsKey);
      tokenizationSpokes[tsKey] = deploy.tokenized(tsKey);
      console.log(tokenizationSpokes[tsKey], string.concat('TOKENIZED_', tsKey));
      vm.label(tokenizationSpokes[tsKey], string.concat('TOKENIZED_', tsKey));
    }

    signatureGateway = deploy.signatureGateway();
    nativeTokenGateway = deploy.nativeTokenGateway();
    hubConfigurator = deploy.hubConfigurator();
    spokeConfigurator = deploy.spokeConfigurator();

    hubSetup = true;
    tokenSetup = true;
  }

  // ==================== Configurator Deployment ====================

  function _deployConfigurators() internal {
    hubConfigurator = address(new HubConfigurator(address(ACCESS_MANAGER)));
    spokeConfigurator = address(new SpokeConfigurator(address(ACCESS_MANAGER)));
    DeployLogger.logConfigurator('hubConfigurator', hubConfigurator);
    DeployLogger.logConfigurator('spokeConfigurator', spokeConfigurator);

    // Level 1: Grant admin roles to configurators so they can call Hub/Spoke
    ACCESS_MANAGER.grantRole(Roles.HUB_ADMIN_ROLE, hubConfigurator, 0);
    ACCESS_MANAGER.grantRole(Roles.SPOKE_ADMIN_ROLE, spokeConfigurator, 0);

    // Level 2: Map HubConfigurator functions to HUB_CONFIGURATOR_ROLE (22 selectors)
    {
      bytes4[] memory selectors = new bytes4[](22);
      selectors[0] = IHubConfigurator.updateLiquidityFee.selector;
      selectors[1] = IHubConfigurator.updateFeeReceiver.selector;
      selectors[2] = IHubConfigurator.updateFeeConfig.selector;
      selectors[3] = IHubConfigurator.updateInterestRateStrategy.selector;
      selectors[4] = IHubConfigurator.updateReinvestmentController.selector;
      selectors[5] = IHubConfigurator.resetAssetCaps.selector;
      selectors[6] = IHubConfigurator.deactivateAsset.selector;
      selectors[7] = IHubConfigurator.haltAsset.selector;
      selectors[8] = IHubConfigurator.addSpoke.selector;
      selectors[9] = IHubConfigurator.addSpokeToAssets.selector;
      selectors[10] = IHubConfigurator.updateSpokeActive.selector;
      selectors[11] = IHubConfigurator.updateSpokeHalted.selector;
      selectors[12] = IHubConfigurator.updateSpokeSupplyCap.selector;
      selectors[13] = IHubConfigurator.updateSpokeDrawCap.selector;
      selectors[14] = IHubConfigurator.updateSpokeRiskPremiumThreshold.selector;
      selectors[15] = IHubConfigurator.updateSpokeCaps.selector;
      selectors[16] = IHubConfigurator.deactivateSpoke.selector;
      selectors[17] = IHubConfigurator.haltSpoke.selector;
      selectors[18] = IHubConfigurator.resetSpokeCaps.selector;
      selectors[19] = IHubConfigurator.updateInterestRateData.selector;
      selectors[20] = IHubConfigurator.addAsset.selector;
      selectors[21] = IHubConfigurator.addAssetWithDecimals.selector;
      ACCESS_MANAGER.setTargetFunctionRole(hubConfigurator, selectors, Roles.HUB_CONFIGURATOR_ROLE);
    }

    // Level 2: Map SpokeConfigurator functions to SPOKE_CONFIGURATOR_ROLE (25 selectors)
    {
      bytes4[] memory selectors = new bytes4[](25);
      selectors[0] = ISpokeConfigurator.updateReservePriceSource.selector;
      selectors[1] = ISpokeConfigurator.updateLiquidationTargetHealthFactor.selector;
      selectors[2] = ISpokeConfigurator.updateHealthFactorForMaxBonus.selector;
      selectors[3] = ISpokeConfigurator.updateLiquidationBonusFactor.selector;
      selectors[4] = ISpokeConfigurator.updateLiquidationConfig.selector;
      selectors[5] = ISpokeConfigurator.updateMaxReserves.selector;
      selectors[6] = ISpokeConfigurator.addReserve.selector;
      selectors[7] = ISpokeConfigurator.updatePaused.selector;
      selectors[8] = ISpokeConfigurator.updateFrozen.selector;
      selectors[9] = ISpokeConfigurator.updateBorrowable.selector;
      selectors[10] = ISpokeConfigurator.updateReceiveSharesEnabled.selector;
      selectors[11] = ISpokeConfigurator.updateCollateralRisk.selector;
      selectors[12] = ISpokeConfigurator.addCollateralFactor.selector;
      selectors[13] = ISpokeConfigurator.updateCollateralFactor.selector;
      selectors[14] = ISpokeConfigurator.addMaxLiquidationBonus.selector;
      selectors[15] = ISpokeConfigurator.updateMaxLiquidationBonus.selector;
      selectors[16] = ISpokeConfigurator.addLiquidationFee.selector;
      selectors[17] = ISpokeConfigurator.updateLiquidationFee.selector;
      selectors[18] = ISpokeConfigurator.addDynamicReserveConfig.selector;
      selectors[19] = ISpokeConfigurator.updateDynamicReserveConfig.selector;
      selectors[20] = ISpokeConfigurator.pauseAllReserves.selector;
      selectors[21] = ISpokeConfigurator.freezeAllReserves.selector;
      selectors[22] = ISpokeConfigurator.pauseReserve.selector;
      selectors[23] = ISpokeConfigurator.freezeReserve.selector;
      selectors[24] = ISpokeConfigurator.updatePositionManager.selector;
      ACCESS_MANAGER.setTargetFunctionRole(
        spokeConfigurator,
        selectors,
        Roles.SPOKE_CONFIGURATOR_ROLE
      );
    }

    // Verify all hubs and spokes use the same AccessManager
    for (uint i; i < _hubKeys.length; ++i) {
      assertEq(_hub(_hubKeys[i]).hub.authority(), address(ACCESS_MANAGER));
    }
    for (uint i; i < _spokeKeys.length; ++i) {
      assertEq(_spoke(_spokeKeys[i]).authority(), address(ACCESS_MANAGER));
    }
  }

  // ==================== Utilities ====================

  function _deployMockPriceFeed(uint price, string memory description) internal returns (address) {
    return address(new MockPriceFeed(8, description, price));
  }
}
