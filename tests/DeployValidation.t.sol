// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {Test, stdJson, console2 as console} from 'forge-std/Test.sol';
import {IHub} from 'src/hub/interfaces/IHub.sol';
import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';
import {IAaveOracle} from 'src/spoke/interfaces/IAaveOracle.sol';
import {IPriceOracle} from 'src/spoke/interfaces/IPriceOracle.sol';
import {ITokenizationSpoke} from 'src/spoke/interfaces/ITokenizationSpoke.sol';
import {IAssetInterestRateStrategy} from 'src/hub/interfaces/IAssetInterestRateStrategy.sol';
import {IGatewayBase} from 'src/position-manager/interfaces/IGatewayBase.sol';
import {IAccessManager} from 'src/dependencies/openzeppelin/IAccessManager.sol';
import {IAccessManaged} from 'src/dependencies/openzeppelin/IAccessManaged.sol';
import {IERC20Metadata} from 'src/dependencies/openzeppelin/IERC20Metadata.sol';
import {IHubConfigurator} from 'src/hub/interfaces/IHubConfigurator.sol';
import {ISpokeConfigurator} from 'src/spoke/interfaces/ISpokeConfigurator.sol';
import {Roles} from 'src/libraries/types/Roles.sol';
import {ConfigReader} from 'scripts/ConfigReader.sol';
import {ScriptUtils} from 'scripts/ScriptUtils.sol';
import {DeployReader} from 'scripts/DeployReader.sol';

/// @title DeployValidation
/// @notice Validates deployed Aave V4 state against expected configuration.
/// @dev Reads config from CONFIG_PATH (default: config/mainnet.json) and deployed
///      addresses from DEPLOY_PATH (default: output/deploy.json).
///      Run against any fork: `forge test --match-contract DeployValidation --fork-url <RPC> -vvv`
contract DeployValidation is Test {
  using stdJson for string;
  using ConfigReader for string;
  using DeployReader for string;

  string internal _config;
  string internal _deploy;

  IAccessManager internal _accessManager;
  address internal _admin;
  address internal _sigGateway;
  address internal _nativeGateway;
  address internal _hubConfiguratorAddr;
  address internal _spokeConfiguratorAddr;

  function setUp() public {
    string memory configPath = vm.envOr('CONFIG_PATH', string('config/mainnet.json'));
    string memory deployPath = vm.envOr('DEPLOY_PATH', string('output/deploy.json'));
    _config = vm.readFile(configPath);
    _deploy = vm.readFile(deployPath);

    _accessManager = IAccessManager(_deploy.accessManager());
    _admin = _deploy.admin();
    _sigGateway = _deploy.signatureGateway();
    _nativeGateway = _deploy.nativeTokenGateway();
    _hubConfiguratorAddr = _deploy.hubConfigurator();
    _spokeConfiguratorAddr = _deploy.spokeConfigurator();
  }

  // ==================== Helpers ====================

  function _label(uint256 i, string memory a, string memory b) internal pure returns (string memory) {
    return string.concat('[', vm.toString(i), '] ', a, '@', b);
  }

  function _assertRole(uint64 roleId, address account, string memory msg_) internal view {
    (bool isMember, ) = _accessManager.hasRole(roleId, account);
    assertTrue(isMember, msg_);
  }

  function _assertSelectorRole(
    address target,
    bytes4 selector,
    uint64 expectedRole,
    string memory msg_
  ) internal view {
    assertEq(_accessManager.getTargetFunctionRole(target, selector), expectedRole, msg_);
  }

  // ==================== Test: Hub Assets ====================

  function test_hubAssets() public view {
    for (uint256 i; _config.assetExists(i); i++) {
      ConfigReader.AssetConfig memory asset = _config.readAsset(i);
      string memory label = _label(i, asset.tokenKey, asset.hubKey);

      address hubAddr = _deploy.hub(asset.hubKey);
      address tokenAddr = _deploy.token(asset.tokenKey);
      address irStratAddr = _deploy.irStrategy(asset.hubKey);
      address treasuryAddr = _deploy.treasury(asset.hubKey);
      IHub hub = IHub(hubAddr);

      // Asset is listed
      assertTrue(hub.isUnderlyingListed(tokenAddr), string.concat(label, ': not listed'));

      uint256 assetId = hub.getAssetId(tokenAddr);
      IHub.Asset memory a = hub.getAsset(assetId);

      // Asset data matches
      assertEq(a.underlying, tokenAddr, string.concat(label, ': underlying'));
      assertEq(a.decimals, IERC20Metadata(tokenAddr).decimals(), string.concat(label, ': decimals'));
      assertEq(a.feeReceiver, treasuryAddr, string.concat(label, ': feeReceiver'));
      assertEq(a.irStrategy, irStratAddr, string.concat(label, ': irStrategy'));

      // Asset config matches
      IHub.AssetConfig memory ac = hub.getAssetConfig(assetId);
      assertEq(ac.liquidityFee, asset.liquidityFee, string.concat(label, ': liquidityFee'));
      assertEq(ac.feeReceiver, treasuryAddr, string.concat(label, ': config.feeReceiver'));
      assertEq(ac.irStrategy, irStratAddr, string.concat(label, ': config.irStrategy'));

      // IR data matches
      IAssetInterestRateStrategy.InterestRateData memory irData = IAssetInterestRateStrategy(
        irStratAddr
      ).getInterestRateData(assetId);
      assertEq(
        irData.optimalUsageRatio,
        asset.irData.optimalUsageRatio,
        string.concat(label, ': optimalUsageRatio')
      );
      assertEq(
        irData.baseVariableBorrowRate,
        asset.irData.baseVariableBorrowRate,
        string.concat(label, ': baseVariableBorrowRate')
      );
      assertEq(
        irData.variableRateSlope1,
        asset.irData.variableRateSlope1,
        string.concat(label, ': variableRateSlope1')
      );
      assertEq(
        irData.variableRateSlope2,
        asset.irData.variableRateSlope2,
        string.concat(label, ': variableRateSlope2')
      );
    }
  }

  // ==================== Test: Spoke Registrations ====================

  function test_spokeRegistrations() public view {
    for (uint256 i; _config.spokeRegExists(i); i++) {
      ConfigReader.SpokeRegConfig memory reg = _config.readSpokeReg(i);
      string memory label = _label(i, reg.assetKey, reg.spokeKey);

      address hubAddr = _deploy.hub(reg.hubKey);
      address spokeAddr = _deploy.spoke(reg.spokeKey);
      address tokenAddr = _deploy.token(reg.assetKey);
      IHub hub = IHub(hubAddr);
      uint256 assetId = ScriptUtils.assetId(hub, tokenAddr);

      // Spoke is registered
      assertTrue(hub.isSpokeListed(assetId, spokeAddr), string.concat(label, ': not listed'));

      // SpokeConfig matches
      IHub.SpokeConfig memory sc = hub.getSpokeConfig(assetId, spokeAddr);
      assertEq(sc.addCap, reg.addCap, string.concat(label, ': addCap'));
      assertEq(sc.drawCap, reg.drawCap, string.concat(label, ': drawCap'));
      assertEq(
        sc.riskPremiumThreshold,
        reg.riskPremiumThreshold,
        string.concat(label, ': riskPremiumThreshold')
      );
      assertTrue(sc.active == reg.active, string.concat(label, ': active'));
      assertTrue(sc.halted == reg.halted, string.concat(label, ': halted'));
    }
  }

  // ==================== Test: Treasury Spoke Registrations ====================

  function test_treasurySpokeRegistrations() public view {
    for (uint256 hi; _config.hubExists(hi); hi++) {
      string memory hubKey = _config.hubKey(hi);
      address hubAddr = _deploy.hub(hubKey);
      address treasuryAddr = _deploy.treasury(hubKey);
      IHub hub = IHub(hubAddr);

      uint256 assetCount = hub.getAssetCount();
      for (uint256 assetId; assetId < assetCount; assetId++) {
        string memory label = string.concat(hubKey, ':asset', vm.toString(assetId), ':treasury');

        assertTrue(
          hub.isSpokeListed(assetId, treasuryAddr),
          string.concat(label, ': not listed')
        );

        IHub.SpokeConfig memory sc = hub.getSpokeConfig(assetId, treasuryAddr);
        assertEq(sc.addCap, type(uint40).max, string.concat(label, ': addCap'));
        assertEq(sc.drawCap, 0, string.concat(label, ': drawCap'));
        assertTrue(sc.active, string.concat(label, ': active'));
        assertFalse(sc.halted, string.concat(label, ': halted'));
      }
    }
  }

  // ==================== Test: Reserves ====================

  function test_reserves() public view {
    for (uint256 i; _config.reserveExists(i); i++) {
      ConfigReader.ReserveConfig memory res = _config.readReserve(i);
      string memory label = _label(i, res.assetKey, res.spokeKey);

      address hubAddr = _deploy.hub(res.hubKey);
      address spokeAddr = _deploy.spoke(res.spokeKey);
      address tokenAddr = _deploy.token(res.assetKey);
      IHub hub = IHub(hubAddr);
      ISpoke spoke = ISpoke(spokeAddr);
      uint256 assetId = ScriptUtils.assetId(hub, tokenAddr);

      // Reserve exists
      uint256 reserveId = spoke.getReserveId(hubAddr, assetId);
      ISpoke.Reserve memory reserve = spoke.getReserve(reserveId);

      // Reserve data matches
      assertEq(reserve.underlying, tokenAddr, string.concat(label, ': underlying'));
      assertEq(address(reserve.hub), hubAddr, string.concat(label, ': hub'));
      assertEq(reserve.assetId, assetId, string.concat(label, ': assetId'));

      // ReserveConfig matches
      ISpoke.ReserveConfig memory rc = spoke.getReserveConfig(reserveId);
      assertTrue(rc.borrowable == res.borrowable, string.concat(label, ': borrowable'));
      assertEq(rc.collateralRisk, res.collateralRisk, string.concat(label, ': collateralRisk'));
      assertTrue(rc.paused == res.paused, string.concat(label, ': paused'));
      assertTrue(rc.frozen == res.frozen, string.concat(label, ': frozen'));
      assertTrue(
        rc.receiveSharesEnabled == res.receiveSharesEnabled,
        string.concat(label, ': receiveSharesEnabled')
      );

      // DynamicReserveConfig matches
      uint32 dynKey = reserve.dynamicConfigKey;
      ISpoke.DynamicReserveConfig memory dyn = spoke.getDynamicReserveConfig(reserveId, dynKey);
      assertEq(
        dyn.collateralFactor,
        res.collateralFactor,
        string.concat(label, ': collateralFactor')
      );
      assertEq(
        dyn.maxLiquidationBonus,
        res.maxLiquidationBonus,
        string.concat(label, ': maxLiquidationBonus')
      );
      assertEq(dyn.liquidationFee, res.liquidationFee, string.concat(label, ': liquidationFee'));
    }
  }

  // ==================== Test: Liquidation Configs ====================

  function test_liquidationConfigs() public view {
    for (uint256 i; _config.spokeExists(i); i++) {
      string memory spokeKey = _config.spokeKey(i);
      ISpoke.LiquidationConfig memory expected = _config.readLiquidationConfig(i);

      address spokeAddr = _deploy.spoke(spokeKey);
      ISpoke.LiquidationConfig memory actual = ISpoke(spokeAddr).getLiquidationConfig();

      assertEq(
        actual.targetHealthFactor,
        expected.targetHealthFactor,
        string.concat(spokeKey, ': targetHealthFactor')
      );
      assertEq(
        actual.healthFactorForMaxBonus,
        expected.healthFactorForMaxBonus,
        string.concat(spokeKey, ': healthFactorForMaxBonus')
      );
      assertEq(
        actual.liquidationBonusFactor,
        expected.liquidationBonusFactor,
        string.concat(spokeKey, ': liquidationBonusFactor')
      );
    }
  }

  // ==================== Test: Spoke Immutables ====================

  function test_spokeImmutables() public view {
    for (uint256 i; _config.spokeExists(i); i++) {
      ConfigReader.SpokeDeployConfig memory sc = _config.readSpoke(i);
      address spokeAddr = _deploy.spoke(sc.key);
      address oracleAddr = _deploy.oracle(sc.key);

      assertEq(
        ISpoke(spokeAddr).MAX_USER_RESERVES_LIMIT(),
        sc.maxUserReservesLimit,
        string.concat(sc.key, ': MAX_USER_RESERVES_LIMIT')
      );
      assertEq(ISpoke(spokeAddr).ORACLE(), oracleAddr, string.concat(sc.key, ': ORACLE'));
    }
  }

  // ==================== Test: Oracle Setup ====================

  function test_oracleSetup() public view {
    // Validate per-spoke oracle linkage
    for (uint256 i; _config.spokeExists(i); i++) {
      ConfigReader.SpokeDeployConfig memory sc = _config.readSpoke(i);
      address spokeAddr = _deploy.spoke(sc.key);
      address oracleAddr = _deploy.oracle(sc.key);

      assertEq(ISpoke(spokeAddr).ORACLE(), oracleAddr, string.concat(sc.key, ': ORACLE'));
      assertEq(IPriceOracle(oracleAddr).SPOKE(), spokeAddr, string.concat(sc.key, ': SPOKE'));
      assertEq(
        IPriceOracle(oracleAddr).DECIMALS(),
        sc.oracleDecimals,
        string.concat(sc.key, ': DECIMALS')
      );
    }

    // Validate per-reserve price sources and prices
    for (uint256 i; _config.reserveExists(i); i++) {
      ConfigReader.ReserveConfig memory res = _config.readReserve(i);
      string memory label = _label(i, res.assetKey, res.spokeKey);

      address hubAddr = _deploy.hub(res.hubKey);
      address spokeAddr = _deploy.spoke(res.spokeKey);
      address tokenAddr = _deploy.token(res.assetKey);
      address oracleAddr = _deploy.oracle(res.spokeKey);
      IHub hub = IHub(hubAddr);
      ISpoke spoke = ISpoke(spokeAddr);
      uint256 assetId = ScriptUtils.assetId(hub, tokenAddr);
      uint256 reserveId = spoke.getReserveId(hubAddr, assetId);

      // Check price source
      address configPriceFeed = _config.tokenPriceFeed(res.assetKey);
      address onChainSource = IAaveOracle(oracleAddr).getReserveSource(reserveId);
      if (configPriceFeed != address(0)) {
        assertEq(onChainSource, configPriceFeed, string.concat(label, ': priceSource'));
      } else {
        assertTrue(onChainSource != address(0), string.concat(label, ': mock feed not deployed'));
      }

      // Price must be valid regardless
      assertGt(
        IAaveOracle(oracleAddr).getReservePrice(reserveId),
        0,
        string.concat(label, ': price > 0')
      );
    }
  }

  // ==================== Test: Position Managers ====================

  function test_positionManagers() public view {
    bool deploySigGw = _config.deploySignatureGateway();
    bool deployNativeGw = _config.deployNativeTokenGateway();

    for (uint256 i; _config.spokeExists(i); i++) {
      ConfigReader.SpokeDeployConfig memory sc = _config.readSpoke(i);
      address spokeAddr = _deploy.spoke(sc.key);
      ISpoke spoke = ISpoke(spokeAddr);

      if (sc.registerOnPositionManagers) {
        if (deploySigGw) {
          assertTrue(
            spoke.isPositionManagerActive(_sigGateway),
            string.concat(sc.key, ': sigGateway not active PM')
          );
          assertTrue(
            IGatewayBase(_sigGateway).isSpokeRegistered(spokeAddr),
            string.concat(sc.key, ': not registered on sigGateway')
          );
        }

        if (deployNativeGw) {
          assertTrue(
            spoke.isPositionManagerActive(_nativeGateway),
            string.concat(sc.key, ': nativeGateway not active PM')
          );
          assertTrue(
            IGatewayBase(_nativeGateway).isSpokeRegistered(spokeAddr),
            string.concat(sc.key, ': not registered on nativeGateway')
          );
        }
      } else {
        if (deploySigGw) {
          assertFalse(
            spoke.isPositionManagerActive(_sigGateway),
            string.concat(sc.key, ': sigGateway should not be active PM')
          );
        }
        if (deployNativeGw) {
          assertFalse(
            spoke.isPositionManagerActive(_nativeGateway),
            string.concat(sc.key, ': nativeGateway should not be active PM')
          );
        }
      }
    }
  }

  // ==================== Test: Access Control Roles ====================

  function test_accessControlRoles() public view {
    _assertRole(Roles.HUB_ADMIN_ROLE, _admin, 'admin: HUB_ADMIN_ROLE');
    _assertRole(Roles.SPOKE_ADMIN_ROLE, _admin, 'admin: SPOKE_ADMIN_ROLE');
    _assertRole(Roles.HUB_ADMIN_ROLE, _hubConfiguratorAddr, 'hubConfigurator: HUB_ADMIN_ROLE');
    _assertRole(
      Roles.SPOKE_ADMIN_ROLE,
      _spokeConfiguratorAddr,
      'spokeConfigurator: SPOKE_ADMIN_ROLE'
    );
  }

  // ==================== Test: Access Control Hub Selectors ====================

  function test_accessControlHubSelectors() public view {
    bytes4[6] memory hubAdminSelectors = [
      IHub.addAsset.selector,
      IHub.updateAssetConfig.selector,
      IHub.addSpoke.selector,
      IHub.updateSpokeConfig.selector,
      IHub.setInterestRateData.selector,
      IHub.mintFeeShares.selector
    ];

    for (uint256 hi; _config.hubExists(hi); hi++) {
      string memory hubKey = _config.hubKey(hi);
      address hubAddr = _deploy.hub(hubKey);

      for (uint256 s; s < hubAdminSelectors.length; s++) {
        _assertSelectorRole(
          hubAddr,
          hubAdminSelectors[s],
          Roles.HUB_ADMIN_ROLE,
          string.concat(hubKey, ': HUB_ADMIN selector ', vm.toString(s))
        );
      }

      _assertSelectorRole(
        hubAddr,
        IHub.eliminateDeficit.selector,
        Roles.DEFICIT_ELIMINATOR_ROLE,
        string.concat(hubKey, ': eliminateDeficit')
      );
    }
  }

  // ==================== Test: Access Control Spoke Selectors ====================

  function test_accessControlSpokeSelectors() public view {
    bytes4[7] memory spokeAdminSelectors = [
      ISpoke.updateLiquidationConfig.selector,
      ISpoke.addReserve.selector,
      ISpoke.updateReserveConfig.selector,
      ISpoke.updateDynamicReserveConfig.selector,
      ISpoke.addDynamicReserveConfig.selector,
      ISpoke.updatePositionManager.selector,
      ISpoke.updateReservePriceSource.selector
    ];

    bytes4[2] memory userUpdaterSelectors = [
      ISpoke.updateUserDynamicConfig.selector,
      ISpoke.updateUserRiskPremium.selector
    ];

    for (uint256 i; _config.spokeExists(i); i++) {
      string memory spokeKey = _config.spokeKey(i);
      address spokeAddr = _deploy.spoke(spokeKey);

      for (uint256 s; s < spokeAdminSelectors.length; s++) {
        _assertSelectorRole(
          spokeAddr,
          spokeAdminSelectors[s],
          Roles.SPOKE_ADMIN_ROLE,
          string.concat(spokeKey, ': SPOKE_ADMIN selector ', vm.toString(s))
        );
      }

      for (uint256 s; s < userUpdaterSelectors.length; s++) {
        _assertSelectorRole(
          spokeAddr,
          userUpdaterSelectors[s],
          Roles.USER_POSITION_UPDATER_ROLE,
          string.concat(spokeKey, ': USER_UPDATER selector ', vm.toString(s))
        );
      }
    }
  }

  // ==================== Test: Access Control Configurator Selectors ====================

  function test_accessControlConfiguratorSelectors() public view {
    // HubConfigurator: 22 selectors → HUB_CONFIGURATOR_ROLE
    bytes4[22] memory hubConfigSelectors = [
      IHubConfigurator.updateLiquidityFee.selector,
      IHubConfigurator.updateFeeReceiver.selector,
      IHubConfigurator.updateFeeConfig.selector,
      IHubConfigurator.updateInterestRateStrategy.selector,
      IHubConfigurator.updateReinvestmentController.selector,
      IHubConfigurator.resetAssetCaps.selector,
      IHubConfigurator.deactivateAsset.selector,
      IHubConfigurator.haltAsset.selector,
      IHubConfigurator.addSpoke.selector,
      IHubConfigurator.addSpokeToAssets.selector,
      IHubConfigurator.updateSpokeActive.selector,
      IHubConfigurator.updateSpokeHalted.selector,
      IHubConfigurator.updateSpokeSupplyCap.selector,
      IHubConfigurator.updateSpokeDrawCap.selector,
      IHubConfigurator.updateSpokeRiskPremiumThreshold.selector,
      IHubConfigurator.updateSpokeCaps.selector,
      IHubConfigurator.deactivateSpoke.selector,
      IHubConfigurator.haltSpoke.selector,
      IHubConfigurator.resetSpokeCaps.selector,
      IHubConfigurator.updateInterestRateData.selector,
      IHubConfigurator.addAsset.selector,
      IHubConfigurator.addAssetWithDecimals.selector
    ];

    for (uint256 s; s < hubConfigSelectors.length; s++) {
      _assertSelectorRole(
        _hubConfiguratorAddr,
        hubConfigSelectors[s],
        Roles.HUB_CONFIGURATOR_ROLE,
        string.concat('hubConfigurator: selector ', vm.toString(s))
      );
    }

    // SpokeConfigurator: 25 selectors → SPOKE_CONFIGURATOR_ROLE
    bytes4[25] memory spokeConfigSelectors = [
      ISpokeConfigurator.updateReservePriceSource.selector,
      ISpokeConfigurator.updateLiquidationTargetHealthFactor.selector,
      ISpokeConfigurator.updateHealthFactorForMaxBonus.selector,
      ISpokeConfigurator.updateLiquidationBonusFactor.selector,
      ISpokeConfigurator.updateLiquidationConfig.selector,
      ISpokeConfigurator.updateMaxReserves.selector,
      ISpokeConfigurator.addReserve.selector,
      ISpokeConfigurator.updatePaused.selector,
      ISpokeConfigurator.updateFrozen.selector,
      ISpokeConfigurator.updateBorrowable.selector,
      ISpokeConfigurator.updateReceiveSharesEnabled.selector,
      ISpokeConfigurator.updateCollateralRisk.selector,
      ISpokeConfigurator.addCollateralFactor.selector,
      ISpokeConfigurator.updateCollateralFactor.selector,
      ISpokeConfigurator.addMaxLiquidationBonus.selector,
      ISpokeConfigurator.updateMaxLiquidationBonus.selector,
      ISpokeConfigurator.addLiquidationFee.selector,
      ISpokeConfigurator.updateLiquidationFee.selector,
      ISpokeConfigurator.addDynamicReserveConfig.selector,
      ISpokeConfigurator.updateDynamicReserveConfig.selector,
      ISpokeConfigurator.pauseAllReserves.selector,
      ISpokeConfigurator.freezeAllReserves.selector,
      ISpokeConfigurator.pauseReserve.selector,
      ISpokeConfigurator.freezeReserve.selector,
      ISpokeConfigurator.updatePositionManager.selector
    ];

    for (uint256 s; s < spokeConfigSelectors.length; s++) {
      _assertSelectorRole(
        _spokeConfiguratorAddr,
        spokeConfigSelectors[s],
        Roles.SPOKE_CONFIGURATOR_ROLE,
        string.concat('spokeConfigurator: selector ', vm.toString(s))
      );
    }
  }

  // ==================== Test: Tokenization Spokes ====================

  function test_tokenizationSpokes() public view {
    for (uint256 i; _config.assetExists(i); i++) {
      ConfigReader.AssetConfig memory asset = _config.readAsset(i);
      string memory hubPrefix = ConfigReader.trimEnd(asset.hubKey, 4);
      string memory tsKey = string.concat(asset.tokenKey, '_', hubPrefix);
      string memory label = string.concat('tokenized:', tsKey);

      if (!asset.tokenizeEnabled) {
        assertFalse(
          _deploy.keyExists(string.concat('.tokenized.', tsKey)),
          string.concat(label, ': should not be deployed')
        );
        continue;
      }

      address tsAddr = _deploy.tokenized(tsKey);
      assertTrue(tsAddr != address(0), string.concat(label, ': zero address'));

      address hubAddr = _deploy.hub(asset.hubKey);
      address tokenAddr = _deploy.token(asset.tokenKey);
      IHub hub = IHub(hubAddr);
      uint256 assetId = ScriptUtils.assetId(hub, tokenAddr);

      // Hub registration
      assertTrue(hub.isSpokeListed(assetId, tsAddr), string.concat(label, ': not listed on hub'));

      // SpokeConfig
      IHub.SpokeConfig memory sc = hub.getSpokeConfig(assetId, tsAddr);
      assertEq(sc.addCap, asset.tokenizeAddCap, string.concat(label, ': addCap'));
      assertEq(sc.drawCap, 0, string.concat(label, ': drawCap'));
      assertEq(sc.riskPremiumThreshold, 0, string.concat(label, ': riskPremiumThreshold'));
      assertTrue(sc.active, string.concat(label, ': active'));
      assertFalse(sc.halted, string.concat(label, ': halted'));

      // ERC20 metadata
      string memory expectedName = string.concat(hubPrefix, ' ', asset.tokenKey);
      string memory expectedSymbol = string.concat('t', asset.tokenKey, '-', hubPrefix);
      assertTrue(
        ScriptUtils.strEq(IERC20Metadata(tsAddr).name(), expectedName),
        string.concat(label, ': name')
      );
      assertTrue(
        ScriptUtils.strEq(IERC20Metadata(tsAddr).symbol(), expectedSymbol),
        string.concat(label, ': symbol')
      );

      // Hub/assetId references
      assertEq(ITokenizationSpoke(tsAddr).hub(), hubAddr, string.concat(label, ': hub()'));
      assertEq(ITokenizationSpoke(tsAddr).assetId(), assetId, string.concat(label, ': assetId()'));
    }
  }

  // ==================== Test: Completeness Counts ====================

  function test_hubAssetCounts() public view {
    for (uint256 hi; _config.hubExists(hi); hi++) {
      string memory hubKey = _config.hubKey(hi);
      address hubAddr = _deploy.hub(hubKey);
      IHub hub = IHub(hubAddr);

      uint256 expectedCount;
      for (uint256 i; _config.assetExists(i); i++) {
        ConfigReader.AssetConfig memory asset = _config.readAsset(i);
        if (ScriptUtils.strEq(asset.hubKey, hubKey)) expectedCount++;
      }

      assertEq(
        hub.getAssetCount(),
        expectedCount,
        string.concat(hubKey, ': asset count')
      );
    }
  }

  function _countExpectedSpokes(
    string memory hubKey,
    address underlying
  ) internal view returns (uint256 count) {
    count = 1; // treasury is always registered

    for (uint256 ri; _config.spokeRegExists(ri); ri++) {
      ConfigReader.SpokeRegConfig memory reg = _config.readSpokeReg(ri);
      if (ScriptUtils.strEq(reg.hubKey, hubKey) && _deploy.token(reg.assetKey) == underlying) {
        count++;
      }
    }

    for (uint256 ai; _config.assetExists(ai); ai++) {
      ConfigReader.AssetConfig memory asset = _config.readAsset(ai);
      if (
        ScriptUtils.strEq(asset.hubKey, hubKey) &&
        _deploy.token(asset.tokenKey) == underlying &&
        asset.tokenizeEnabled
      ) {
        count++;
      }
    }
  }

  function _isKnownSpoke(
    string memory hubKey,
    address underlying,
    address spokeAddr
  ) internal view returns (bool) {
    if (spokeAddr == _deploy.treasury(hubKey)) return true;

    for (uint256 ri; _config.spokeRegExists(ri); ri++) {
      ConfigReader.SpokeRegConfig memory reg = _config.readSpokeReg(ri);
      if (
        ScriptUtils.strEq(reg.hubKey, hubKey) &&
        _deploy.token(reg.assetKey) == underlying &&
        _deploy.spoke(reg.spokeKey) == spokeAddr
      ) return true;
    }

    for (uint256 ai; _config.assetExists(ai); ai++) {
      ConfigReader.AssetConfig memory asset = _config.readAsset(ai);
      if (
        ScriptUtils.strEq(asset.hubKey, hubKey) &&
        _deploy.token(asset.tokenKey) == underlying &&
        asset.tokenizeEnabled
      ) {
        string memory hubPrefix = ConfigReader.trimEnd(asset.hubKey, 4);
        string memory tsKey = string.concat(asset.tokenKey, '_', hubPrefix);
        if (_deploy.tokenized(tsKey) == spokeAddr) return true;
      }
    }

    return false;
  }

  function test_spokeCountsPerAsset() public view {
    for (uint256 hi; _config.hubExists(hi); hi++) {
      string memory hubKey = _config.hubKey(hi);
      IHub hub = IHub(_deploy.hub(hubKey));
      uint256 assetCount = hub.getAssetCount();

      for (uint256 assetId; assetId < assetCount; assetId++) {
        address underlying = hub.getAsset(assetId).underlying;
        string memory label = string.concat(hubKey, ':asset', vm.toString(assetId));

        assertEq(
          hub.getSpokeCount(assetId),
          _countExpectedSpokes(hubKey, underlying),
          string.concat(label, ': spoke count')
        );

        uint256 spokeCount = hub.getSpokeCount(assetId);
        for (uint256 si; si < spokeCount; si++) {
          assertTrue(
            _isKnownSpoke(hubKey, underlying, hub.getSpokeAddress(assetId, si)),
            string.concat(label, ': unknown spoke at index ', vm.toString(si))
          );
        }
      }
    }
  }

  function test_reserveCountsPerSpoke() public view {
    for (uint256 si; _config.spokeExists(si); si++) {
      string memory spokeKey = _config.spokeKey(si);
      address spokeAddr = _deploy.spoke(spokeKey);
      ISpoke spoke = ISpoke(spokeAddr);

      uint256 expectedCount;
      for (uint256 ri; _config.reserveExists(ri); ri++) {
        ConfigReader.ReserveConfig memory res = _config.readReserve(ri);
        if (ScriptUtils.strEq(res.spokeKey, spokeKey)) expectedCount++;
      }

      assertEq(
        spoke.getReserveCount(),
        expectedCount,
        string.concat(spokeKey, ': reserve count')
      );
    }
  }

  // ==================== Test: Authority Chain ====================

  function test_authority() public view {
    address am = address(_accessManager);

    // All hubs
    for (uint256 hi; _config.hubExists(hi); hi++) {
      string memory hubKey = _config.hubKey(hi);
      address hubAddr = _deploy.hub(hubKey);
      assertEq(IAccessManaged(hubAddr).authority(), am, string.concat(hubKey, ': authority'));
    }

    // All spokes
    for (uint256 si; _config.spokeExists(si); si++) {
      string memory spokeKey = _config.spokeKey(si);
      address spokeAddr = _deploy.spoke(spokeKey);
      assertEq(IAccessManaged(spokeAddr).authority(), am, string.concat(spokeKey, ': authority'));
    }

    // Configurators
    assertEq(
      IAccessManaged(_hubConfiguratorAddr).authority(),
      am,
      'hubConfigurator: authority'
    );
    assertEq(
      IAccessManaged(_spokeConfiguratorAddr).authority(),
      am,
      'spokeConfigurator: authority'
    );
  }
}
