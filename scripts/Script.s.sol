// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {Script, stdJson, console2 as console} from 'forge-std/Script.sol';
import {StdAssertions} from 'forge-std/StdAssertions.sol';
import {IHub} from 'src/hub/interfaces/IHub.sol';
import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';
import {IPositionManagerBase} from 'src/position-manager/interfaces/IPositionManagerBase.sol';
import {SignatureGateway} from 'src/position-manager/SignatureGateway.sol';
import {NativeTokenGateway} from 'src/position-manager/NativeTokenGateway.sol';
import {GiverPositionManager} from 'src/position-manager/GiverPositionManager.sol';
import {TakerPositionManager} from 'src/position-manager/TakerPositionManager.sol';
import {ConfigPositionManager} from 'src/position-manager/ConfigPositionManager.sol';
import {HubConfigurator} from 'src/hub/HubConfigurator.sol';
import {IHubConfigurator} from 'src/hub/interfaces/IHubConfigurator.sol';
import {SpokeConfigurator} from 'src/spoke/SpokeConfigurator.sol';
import {ISpokeConfigurator} from 'src/spoke/interfaces/ISpokeConfigurator.sol';

import {TreasurySpokeInstance} from 'src/spoke/instances/TreasurySpokeInstance.sol';
import {AccessManager} from 'src/dependencies/openzeppelin/AccessManager.sol';
import {TestnetERC20} from 'tests/mocks/TestnetERC20.sol';
import {MockPriceFeed} from 'tests/mocks/MockPriceFeed.sol';
import {AaveOracle, IAaveOracle} from 'src/spoke/AaveOracle.sol';
import {IPriceFeed} from 'src/spoke/interfaces/IPriceFeed.sol';
import {Roles} from 'src/libraries/types/Roles.sol';
import {AssetInterestRateStrategy} from 'src/hub/AssetInterestRateStrategy.sol';
import {DeployUtils} from 'tests/DeployUtils.sol';
import {SpokeDeployUtils} from './SpokeDeployUtils.sol';
import {ISpokeInstance} from 'tests/mocks/ISpokeInstance.sol';
import {TokenizationSpokeInstance} from 'src/spoke/instances/TokenizationSpokeInstance.sol';
import {ConfigReader} from './ConfigReader.sol';
import {DeployReader} from './DeployReader.sol';
import {ScriptUtils} from './ScriptUtils.sol';
import {DeployLogger} from './DeployLogger.sol';

contract Deploy is Script, StdAssertions {
  using stdJson for string;
  using ConfigReader for string;
  using DeployReader for string;

  // ==================== JSON Config ====================

  string internal _json;

  // Keys read from JSON (stored for output)
  string[] internal _hubKeys;
  string[] internal _spokeKeys;
  string[] internal _tokenKeys;

  // ==================== Token ====================

  struct Token {
    address token;
    address priceFeed;
  }
  mapping(string key => Token token) internal tokens;
  bool internal tokenSetup;

  // ==================== Periphery ====================

  address internal signatureGateway;
  address internal nativeTokenGateway;
  address internal giverPositionManager;
  address internal takerPositionManager;
  address internal configPositionManager;

  // ==================== Configurators ====================

  address internal hubConfigurator;
  address internal spokeConfigurator;

  // ==================== Hub ====================

  struct HubState {
    IHub hub;
    address treasury;
    AssetInterestRateStrategy irStrategy;
  }
  mapping(string key => HubState conf) internal hubs;
  AccessManager internal accessManager;
  address internal admin;
  bool internal hubSetup;

  // ==================== Spoke ====================

  struct SpokeState {
    ISpoke spoke;
    address oracle;
  }
  mapping(string key => SpokeState spoke) internal spokes;

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
    deployPeriphery();
    _deployConfigurators();
    writeDeployJson();
  }

  // ==================== Config Loading ====================

  function _loadConfig() internal {
    string memory configPath = vm.envOr('CONFIG_PATH', string('config/mainnet.json'));
    _json = vm.readFile(configPath);
  }

  // ==================== Token Setup ====================

  function setUpTokens() public {
    _tokenKeys = _json.tokenKeys();
    for (uint256 i; i < _tokenKeys.length; ++i) {
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
    admin = caller;
    accessManager = new AccessManager(admin);

    // Deploy all spokes first (oracles need predicted spoke address)
    _deploySpokes();

    // Deploy hubs, list assets, register spokes
    for (uint256 hi = 0; _json.hubExists(hi); hi++) {
      string memory hubKey = _json.hubKey(hi);
      DeployLogger.logSection(hubKey);

      IHub hub = DeployUtils.deployHub(address(accessManager), keccak256(abi.encodePacked(hubKey)));
      address treasuryImpl = address(new TreasurySpokeInstance());
      address treasury = DeployUtils.proxify(
        treasuryImpl,
        admin,
        abi.encodeCall(TreasurySpokeInstance.initialize, (admin))
      );
      hubs[hubKey] = HubState(
        hub,
        treasury,
        new AssetInterestRateStrategy(address(hub))
      );
      _hubKeys.push(hubKey);
      setUpRoles(hubKey);
    }

    // List assets on hubs
    DeployLogger.logSection('Asset Listing');
    for (uint256 ai = 0; _json.assetExists(ai); ai++) {
      _processAsset(_json.readAsset(ai));
    }

    // Register spokes on hub assets
    DeployLogger.logSection('Spoke Registration');
    for (uint256 si = 0; _json.spokeRegExists(si); si++) {
      _processSpokeReg(_json.readSpokeReg(si));
    }

    // Deploy tokenization spokes for all enabled assets
    _deployTokenizationSpokes();

    hubSetup = true;
  }

  // ==================== Reserve Setup ====================

  function setUpReserves() public {
    require(hubSetup, 'hub setup required');

    DeployLogger.logSection('Reserve Listing');
    for (uint256 ri = 0; _json.reserveExists(ri); ri++) {
      _processReserve(_json.readReserve(ri));
    }

    // Apply liquidation configs to spokes
    for (uint256 i; i < _spokeKeys.length; ++i) {
      ISpoke.LiquidationConfig memory lc = _json.readLiquidationConfig(i);
      _spoke(_spokeKeys[i]).updateLiquidationConfig(lc);
      DeployLogger.logLiquidationConfig(_spokeKeys[i], lc);
    }
  }

  // ==================== Periphery ====================

  function deployPeriphery() public {
    (, address caller, ) = vm.readCallers();

    if (_json.deploySignatureGateway()) {
      signatureGateway = address(new SignatureGateway(caller));
      DeployLogger.logPeriphery('signatureGateway', signatureGateway);
    }
    if (_json.deployNativeTokenGateway()) {
      nativeTokenGateway = address(
        new NativeTokenGateway(tokens[_json.nativeTokenKey()].token, caller)
      );
      DeployLogger.logPeriphery('nativeTokenGateway', nativeTokenGateway);
    }
    if (_json.deployGiverPositionManager()) {
      giverPositionManager = address(new GiverPositionManager(caller));
      DeployLogger.logPeriphery('giverPositionManager', giverPositionManager);
    }
    if (_json.deployTakerPositionManager()) {
      takerPositionManager = address(new TakerPositionManager(caller));
      DeployLogger.logPeriphery('takerPositionManager', takerPositionManager);
    }
    if (_json.deployConfigPositionManager()) {
      configPositionManager = address(new ConfigPositionManager(caller));
      DeployLogger.logPeriphery('configPositionManager', configPositionManager);
    }

    for (uint256 i; i < _spokeKeys.length; ++i) {
      ConfigReader.SpokeDeployConfig memory sc = _json.readSpoke(i);
      if (!sc.registerOnPositionManagers) continue;

      ISpoke spoke = _spoke(_spokeKeys[i]);
      _registerPm(spoke, signatureGateway);
      _registerPm(spoke, nativeTokenGateway);
      _registerPm(spoke, giverPositionManager);
      _registerPm(spoke, takerPositionManager);
      _registerPm(spoke, configPositionManager);
    }
  }

  function _registerPm(ISpoke spoke, address pm) internal {
    if (pm == address(0)) return;
    IPositionManagerBase(pm).registerSpoke(address(spoke), true);
    spoke.updatePositionManager(pm, true);
  }

  // ==================== Spoke Deployment ====================

  function _deploySpokes() internal {
    (, address deployer, ) = vm.readCallers();

    address liquidationLogic = SpokeDeployUtils._getLiquidationLogicAddress();
    require(
      liquidationLogic.code.length > 0,
      'LiquidationLogic not deployed. Run LibraryPreCompile first.'
    );

    for (uint256 si = 0; _json.spokeExists(si); si++) {
      ConfigReader.SpokeDeployConfig memory sc = _json.readSpoke(si);
      _spokeKeys.push(sc.key);

      IAaveOracle oracle = new AaveOracle(sc.oracleDecimals);

      ISpoke spoke = SpokeDeployUtils.deploySpoke(
        address(oracle),
        sc.maxUserReservesLimit,
        deployer,
        abi.encodeCall(ISpokeInstance.initialize, (address(accessManager)))
      );

      oracle.setSpoke(address(spoke));

      assertEq(spoke.ORACLE(), address(oracle));
      assertEq(oracle.spoke(), address(spoke));

      spokes[sc.key] = SpokeState(spoke, address(oracle));
      DeployLogger.logSpokeDeployed(sc.key, address(spoke));
    }
  }

  // ==================== Tokenization Spoke Deployment ====================

  function _deployTokenizationSpokes() internal {
    (, address deployer, ) = vm.readCallers();
    DeployLogger.logSection('Tokenization Spoke Deployment');

    for (uint256 ai = 0; _json.assetExists(ai); ai++) {
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
    uint256 assetId = ScriptUtils.assetId(hub, _token(asset.tokenKey).token);

    string memory hubPrefix = ConfigReader.trimEnd(asset.hubKey, 4); // strip "_HUB"
    string memory tsKey = string.concat(asset.tokenKey, '_', hubPrefix);

    // Deploy impl + proxy
    address ts;
    {
      address impl = address(new TokenizationSpokeInstance(address(hub), _token(asset.tokenKey).token));
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
    accessManager.grantRole(Roles.HUB_ADMIN_ROLE, admin, 0);
    accessManager.grantRole(Roles.SPOKE_ADMIN_ROLE, admin, 0);

    IHub hub = _hub(hubKey).hub;

    for (uint256 i; i < _spokeKeys.length; ++i) {
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
        accessManager.setTargetFunctionRole(address(spoke), selectors, Roles.SPOKE_ADMIN_ROLE);
      }

      {
        bytes4[] memory selectors = new bytes4[](2);
        selectors[0] = ISpoke.updateUserDynamicConfig.selector;
        selectors[1] = ISpoke.updateUserRiskPremium.selector;
        accessManager.setTargetFunctionRole(
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
      accessManager.setTargetFunctionRole(address(hub), selectors, Roles.HUB_ADMIN_ROLE);
    }

    {
      bytes4[] memory selectors = new bytes4[](1);
      selectors[0] = IHub.eliminateDeficit.selector;
      accessManager.setTargetFunctionRole(address(hub), selectors, Roles.DEFICIT_ELIMINATOR_ROLE);
    }
  }

  // ==================== Process: Asset Listing ====================

  function _processAsset(ConfigReader.AssetConfig memory conf) internal {
    HubState storage hubConf = _hub(conf.hubKey);
    address token = _token(conf.tokenKey).token;

    uint256 assetId = hubConf.hub.addAsset(
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
    address token = _token(conf.assetKey).token;
    uint256 assetId = ScriptUtils.assetId(hub, token);

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
    uint256 assetId = ScriptUtils.assetId(hub, t.token);

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
    require(t.priceFeed != address(0), 'price feed unset');
    uint256 reserveId = spoke.addReserve(address(hub), assetId, t.priceFeed, st, dyn);

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

  // ==================== Resolution Helpers ====================

  function _token(string memory key) internal view returns (Token storage) {
    Token storage t = tokens[key];
    require(t.token != address(0), 'token unset');
    return t;
  }

  function _hub(string memory key) internal view returns (HubState storage) {
    HubState storage ret = hubs[key];
    require(address(ret.hub) != address(0), string.concat('zero hub ', key));
    return ret;
  }

  function _spoke(string memory key) internal view returns (ISpoke) {
    SpokeState storage ret = spokes[key];
    require(address(ret.spoke) != address(0), 'zero spoke');
    return ret.spoke;
  }

  // ==================== Output ====================

  function writeDeployJson() public {
    string memory root = 'root';

    string memory hubJson;
    string memory irJson;
    string memory treasuryJson;
    for (uint256 i; i < _hubKeys.length; ++i) {
      string memory k = _hubKeys[i];
      HubState storage h = hubs[k];
      hubJson = vm.serializeAddress('hub', k, address(h.hub));
      irJson = vm.serializeAddress('irStrategy', k, address(h.irStrategy));
      treasuryJson = vm.serializeAddress('treasury', k, address(h.treasury));
    }
    vm.serializeString(root, 'hub', hubJson);
    vm.serializeString(root, 'irStrategy', irJson);
    vm.serializeString(root, 'treasury', treasuryJson);

    string memory spokeJson;
    string memory oracleJson;
    for (uint256 i; i < _spokeKeys.length; ++i) {
      string memory k = _spokeKeys[i];
      SpokeState storage s = spokes[k];
      spokeJson = vm.serializeAddress('spoke', k, address(s.spoke));
      oracleJson = vm.serializeAddress('oracle', k, s.oracle);
    }
    vm.serializeString(root, 'spoke', spokeJson);
    vm.serializeString(root, 'oracle', oracleJson);

    string memory tokenJson;
    for (uint256 i; i < _tokenKeys.length; ++i) {
      tokenJson = vm.serializeAddress('token', _tokenKeys[i], tokens[_tokenKeys[i]].token);
    }
    vm.serializeString(root, 'token', tokenJson);

    if (_tokenizationSpokeKeys.length > 0) {
      string memory tsJson;
      for (uint256 i; i < _tokenizationSpokeKeys.length; ++i) {
        tsJson = vm.serializeAddress(
          'tokenized',
          _tokenizationSpokeKeys[i],
          tokenizationSpokes[_tokenizationSpokeKeys[i]]
        );
      }
      vm.serializeString(root, 'tokenized', tsJson);
    }

    vm.serializeAddress(root, 'admin', admin);
    vm.serializeAddress(root, 'accessManager', address(accessManager));
    vm.serializeAddress(root, 'signatureGateway', signatureGateway);
    vm.serializeAddress(root, 'nativeTokenGateway', nativeTokenGateway);
    vm.serializeAddress(root, 'giverPositionManager', giverPositionManager);
    vm.serializeAddress(root, 'takerPositionManager', takerPositionManager);
    vm.serializeAddress(root, 'configPositionManager', configPositionManager);
    vm.serializeAddress(root, 'hubConfigurator', hubConfigurator);
    vm.serializeAddress(root, 'spokeConfigurator', spokeConfigurator);
    root = vm.serializeString(root, 'commit', ScriptUtils.commit());

    vm.writeJson(root, './output/deploy.json');
  }

  // ==================== Load ====================

  function load() public {
    string memory deploy = vm.readFile('./output/deploy.json');

    for (uint256 hi = 0; _json.hubExists(hi); hi++) {
      _hubKeys.push(_json.hubKey(hi));
    }
    for (uint256 si = 0; _json.spokeExists(si); si++) {
      _spokeKeys.push(_json.spokeKey(si));
    }

    admin = deploy.admin();
    accessManager = AccessManager(deploy.accessManager());
    vm.label(address(accessManager), 'AccessManager');

    for (uint256 i; i < _hubKeys.length; ++i) {
      string memory key = _hubKeys[i];
      hubs[key].hub = IHub(deploy.hub(key));
      hubs[key].irStrategy = AssetInterestRateStrategy(deploy.irStrategy(key));
      hubs[key].treasury = deploy.treasury(key);
      vm.label(address(hubs[key].hub), key);
    }

    for (uint256 i; i < _spokeKeys.length; ++i) {
      string memory key = _spokeKeys[i];
      spokes[key].spoke = ISpoke(deploy.spoke(key));
      spokes[key].oracle = deploy.oracle(key);
      vm.label(address(spokes[key].spoke), key);
    }

    for (uint256 ai = 0; _json.assetExists(ai); ai++) {
      ConfigReader.AssetConfig memory asset = _json.readAsset(ai);
      if (!asset.tokenizeEnabled) continue;
      string memory hubPrefix = ConfigReader.trimEnd(asset.hubKey, 4);
      string memory tsKey = string.concat(asset.tokenKey, '_', hubPrefix);
      _tokenizationSpokeKeys.push(tsKey);
      tokenizationSpokes[tsKey] = deploy.tokenized(tsKey);
      vm.label(tokenizationSpokes[tsKey], string.concat('TOKENIZED_', tsKey));
    }

    signatureGateway = deploy.signatureGateway();
    nativeTokenGateway = deploy.nativeTokenGateway();
    giverPositionManager = deploy.giverPositionManager();
    takerPositionManager = deploy.takerPositionManager();
    configPositionManager = deploy.configPositionManager();
    hubConfigurator = deploy.hubConfigurator();
    spokeConfigurator = deploy.spokeConfigurator();

    hubSetup = true;
    tokenSetup = true;
  }

  // ==================== Debug ====================

  /// @notice Debug: print reserve info for a specific reserve on a spoke.
  function debugReserve(string calldata spokeKey, uint256 reserveId) external {
    string memory deploy = vm.readFile(vm.envOr('DEPLOY_PATH', string('./output/deploy.json')));

    ISpoke spoke = ISpoke(deploy.spoke(spokeKey));
    address deployOracle = deploy.oracle(spokeKey);
    address spokeOracle = spoke.ORACLE();

    console.log('spoke:', spokeKey, address(spoke));
    console.log('oracle (deploy.json):', deployOracle);
    console.log('oracle (spoke.ORACLE):', spokeOracle);
    require(deployOracle == spokeOracle, 'oracle mismatch: deploy.json vs spoke.ORACLE()');

    IAaveOracle oracle = IAaveOracle(spokeOracle);
    ISpoke.Reserve memory r = spoke.getReserve(reserveId);
    address source = oracle.getReserveSource(reserveId);
    uint256 price = oracle.getReservePrice(reserveId);
    int256 latestAnswer = IPriceFeed(source).latestAnswer();

    console.log('reserveId:', reserveId);
    console.log('underlying:', r.underlying);
    console.log('priceSource:', source);
    console.log('price:', price);
    console.log('latestAnswer:', latestAnswer);
  }

  // ==================== Configurator Deployment ====================

  function _deployConfigurators() internal {
    hubConfigurator = address(new HubConfigurator(address(accessManager)));
    spokeConfigurator = address(new SpokeConfigurator(address(accessManager)));
    DeployLogger.logConfigurator('hubConfigurator', hubConfigurator);
    DeployLogger.logConfigurator('spokeConfigurator', spokeConfigurator);

    // Level 1: Grant admin roles to configurators so they can call Hub/Spoke
    accessManager.grantRole(Roles.HUB_ADMIN_ROLE, hubConfigurator, 0);
    accessManager.grantRole(Roles.SPOKE_ADMIN_ROLE, spokeConfigurator, 0);

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
      selectors[12] = IHubConfigurator.updateSpokeAddCap.selector;
      selectors[13] = IHubConfigurator.updateSpokeDrawCap.selector;
      selectors[14] = IHubConfigurator.updateSpokeRiskPremiumThreshold.selector;
      selectors[15] = IHubConfigurator.updateSpokeCaps.selector;
      selectors[16] = IHubConfigurator.deactivateSpoke.selector;
      selectors[17] = IHubConfigurator.haltSpoke.selector;
      selectors[18] = IHubConfigurator.resetSpokeCaps.selector;
      selectors[19] = IHubConfigurator.updateInterestRateData.selector;
      selectors[20] = IHubConfigurator.addAsset.selector;
      selectors[21] = IHubConfigurator.addAssetWithDecimals.selector;
      accessManager.setTargetFunctionRole(hubConfigurator, selectors, Roles.HUB_CONFIGURATOR_ROLE);
    }

    // Level 2: Map SpokeConfigurator functions to SPOKE_CONFIGURATOR_ROLE (24 selectors)
    {
      bytes4[] memory selectors = new bytes4[](24);
      selectors[0] = ISpokeConfigurator.updateReservePriceSource.selector;
      selectors[1] = ISpokeConfigurator.updateLiquidationTargetHealthFactor.selector;
      selectors[2] = ISpokeConfigurator.updateHealthFactorForMaxBonus.selector;
      selectors[3] = ISpokeConfigurator.updateLiquidationBonusFactor.selector;
      selectors[4] = ISpokeConfigurator.updateLiquidationConfig.selector;
      selectors[5] = ISpokeConfigurator.addReserve.selector;
      selectors[6] = ISpokeConfigurator.updatePaused.selector;
      selectors[7] = ISpokeConfigurator.updateFrozen.selector;
      selectors[8] = ISpokeConfigurator.updateBorrowable.selector;
      selectors[9] = ISpokeConfigurator.updateReceiveSharesEnabled.selector;
      selectors[10] = ISpokeConfigurator.updateCollateralRisk.selector;
      selectors[11] = ISpokeConfigurator.addCollateralFactor.selector;
      selectors[12] = ISpokeConfigurator.updateCollateralFactor.selector;
      selectors[13] = ISpokeConfigurator.addMaxLiquidationBonus.selector;
      selectors[14] = ISpokeConfigurator.updateMaxLiquidationBonus.selector;
      selectors[15] = ISpokeConfigurator.addLiquidationFee.selector;
      selectors[16] = ISpokeConfigurator.updateLiquidationFee.selector;
      selectors[17] = ISpokeConfigurator.addDynamicReserveConfig.selector;
      selectors[18] = ISpokeConfigurator.updateDynamicReserveConfig.selector;
      selectors[19] = ISpokeConfigurator.pauseAllReserves.selector;
      selectors[20] = ISpokeConfigurator.freezeAllReserves.selector;
      selectors[21] = ISpokeConfigurator.pauseReserve.selector;
      selectors[22] = ISpokeConfigurator.freezeReserve.selector;
      selectors[23] = ISpokeConfigurator.updatePositionManager.selector;
      accessManager.setTargetFunctionRole(
        spokeConfigurator,
        selectors,
        Roles.SPOKE_CONFIGURATOR_ROLE
      );
    }

    // Verify all hubs and spokes use the same AccessManager
    for (uint256 i; i < _hubKeys.length; ++i) {
      assertEq(_hub(_hubKeys[i]).hub.authority(), address(accessManager));
    }
    for (uint256 i; i < _spokeKeys.length; ++i) {
      assertEq(_spoke(_spokeKeys[i]).authority(), address(accessManager));
    }
  }

  // ==================== Utilities ====================

  function _deployMockPriceFeed(
    uint256 price,
    string memory description
  ) internal returns (address) {
    return address(new MockPriceFeed(8, description, price));
  }
}
