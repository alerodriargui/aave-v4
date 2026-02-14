// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {AaveV4DeployBatchBaseScript} from 'scripts/deploy/AaveV4DeployBatchBase.s.sol';
import {MetadataLogger} from 'src/deployments/utils/MetadataLogger.sol';
import {InputUtils} from 'src/deployments/utils/InputUtils.sol';
import {Constants} from 'tests/Constants.sol';
import {WETH9} from 'src/dependencies/weth/WETH9.sol';

contract AaveV4DeployBatchBaseScriptHarness is AaveV4DeployBatchBaseScript {
  constructor() AaveV4DeployBatchBaseScript('in.json', 'out.json') {}

  function loadWarningsAndSanitizeInputs(
    MetadataLogger logger,
    InputUtils.FullDeployInputs memory inputs,
    address deployer
  ) public returns (InputUtils.FullDeployInputs memory) {
    return _loadWarningsAndSanitizeInputs(logger, inputs, deployer);
  }

  function logAndAppend(MetadataLogger logger, string memory warning) public {
    _logAndAppend(logger, warning);
  }

  function _executeUserPrompt() internal override {}
}

contract AaveV4DeployBatchBaseScriptTest is Test {
  AaveV4DeployBatchBaseScriptHarness internal _harness;
  InputUtils.FullDeployInputs internal _inputs;
  MetadataLogger internal _logger;
  address internal _deployer;

  function setUp() public {
    _harness = new AaveV4DeployBatchBaseScriptHarness();

    _inputs.hubLabels = ['hub1', 'hub2', 'hub3'];
    _inputs.spokeLabels = ['spoke1', 'spoke2', 'spoke3'];
    _inputs.spokeMaxReservesLimits = _defaultSpokeMaxReservesLimits(3);
    _inputs.spokeOracleDecimals = _defaultSpokeOracleDecimals(3);
    _inputs.spokeOracleDescriptions = _defaultSpokeOracleDescriptions(_inputs.spokeLabels);
    _inputs.accessManagerAdmin = makeAddr('accessManagerAdmin');
    _inputs.hubAdmin = makeAddr('hubAdmin');
    _inputs.hubConfiguratorAdmin = makeAddr('hubConfiguratorAdmin');
    _inputs.treasurySpokeOwner = makeAddr('treasurySpokeOwner');
    _inputs.spokeAdmin = makeAddr('spokeAdmin');
    _inputs.spokeProxyAdminOwner = makeAddr('spokeProxyAdminOwner');
    _inputs.spokeConfiguratorAdmin = makeAddr('spokeConfiguratorAdmin');
    _inputs.gatewayOwner = makeAddr('gatewayOwner');
    _inputs.nativeWrapper = address(new WETH9());
    _inputs.deployNativeTokenGateway = true;
    _inputs.deploySignatureGateway = true;
    _inputs.grantRoles = true;

    _logger = new MetadataLogger('dummy/path');
    _deployer = makeAddr('deployer');
  }

  function test_loadWarningsAndSanitizeInputs() public {
    InputUtils.FullDeployInputs memory expected = _inputs;
    InputUtils.FullDeployInputs memory sanitized = _harness.loadWarningsAndSanitizeInputs(
      _logger,
      _inputs,
      _deployer
    );
    assertEq(sanitized, expected);
  }

  function test_loadWarningsAndSanitizeInputs_withZeroAccessManagerAdmin_fuzz(
    bool grantRoles
  ) public {
    _inputs.accessManagerAdmin = address(0);
    _inputs.grantRoles = grantRoles;
    InputUtils.FullDeployInputs memory sanitized = _harness.loadWarningsAndSanitizeInputs(
      _logger,
      _inputs,
      _deployer
    );
    InputUtils.FullDeployInputs memory expected = _inputs;
    if (grantRoles) {
      expected.accessManagerAdmin = _deployer;
    }
    assertEq(sanitized, expected);
  }

  function test_loadWarningsAndSanitizeInputs_withZeroHubAdmin_fuzz(bool grantRoles) public {
    _inputs.hubAdmin = address(0);
    _inputs.grantRoles = grantRoles;
    InputUtils.FullDeployInputs memory sanitized = _harness.loadWarningsAndSanitizeInputs(
      _logger,
      _inputs,
      _deployer
    );
    InputUtils.FullDeployInputs memory expected = _inputs;
    if (grantRoles) {
      expected.hubAdmin = _deployer;
    }
    assertEq(sanitized, expected);
  }

  function test_loadWarningsAndSanitizeInputs_withZeroSpokeAdmin_fuzz(bool grantRoles) public {
    _inputs.spokeAdmin = address(0);
    _inputs.grantRoles = grantRoles;
    InputUtils.FullDeployInputs memory sanitized = _harness.loadWarningsAndSanitizeInputs(
      _logger,
      _inputs,
      _deployer
    );
    InputUtils.FullDeployInputs memory expected = _inputs;
    if (grantRoles) {
      expected.spokeAdmin = _deployer;
    }
    assertEq(sanitized, expected);
  }

  function test_loadWarningsAndSanitizeInputs_withZeroHubConfiguratorAdmin_fuzz(
    bool grantRoles
  ) public {
    _inputs.hubConfiguratorAdmin = address(0);
    _inputs.grantRoles = grantRoles;
    InputUtils.FullDeployInputs memory sanitized = _harness.loadWarningsAndSanitizeInputs(
      _logger,
      _inputs,
      _deployer
    );
    InputUtils.FullDeployInputs memory expected = _inputs;
    if (grantRoles) {
      expected.hubConfiguratorAdmin = _deployer;
    }
    assertEq(sanitized, expected);
  }

  function test_loadWarningsAndSanitizeInputs_withZeroSpokeConfiguratorAdmin_fuzz(
    bool grantRoles
  ) public {
    _inputs.spokeConfiguratorAdmin = address(0);
    _inputs.grantRoles = grantRoles;
    InputUtils.FullDeployInputs memory sanitized = _harness.loadWarningsAndSanitizeInputs(
      _logger,
      _inputs,
      _deployer
    );
    InputUtils.FullDeployInputs memory expected = _inputs;
    if (grantRoles) {
      expected.spokeConfiguratorAdmin = _deployer;
    }
    assertEq(sanitized, expected);
  }

  function test_loadWarningsAndSanitizeInputs_withZeroSpokeProxyAdminOwner_fuzz(
    bool grantRoles
  ) public {
    _inputs.spokeProxyAdminOwner = address(0);
    _inputs.grantRoles = grantRoles;
    InputUtils.FullDeployInputs memory sanitized = _harness.loadWarningsAndSanitizeInputs(
      _logger,
      _inputs,
      _deployer
    );

    InputUtils.FullDeployInputs memory expected = _inputs;
    if (grantRoles) {
      expected.spokeProxyAdminOwner = _deployer;
    }
    assertEq(sanitized, expected);
  }

  function test_loadWarningsAndSanitizeInputs_withZeroTreasurySpokeOwner_fuzz(
    bool grantRoles
  ) public {
    _inputs.treasurySpokeOwner = address(0);
    _inputs.grantRoles = grantRoles;
    InputUtils.FullDeployInputs memory sanitized = _harness.loadWarningsAndSanitizeInputs(
      _logger,
      _inputs,
      _deployer
    );
    InputUtils.FullDeployInputs memory expected = _inputs;
    if (grantRoles) {
      expected.treasurySpokeOwner = _deployer;
    }
    assertEq(sanitized, expected);
  }

  function test_loadWarningsAndSanitizeInputs_withZeroGatewayOwner_fuzz(bool grantRoles) public {
    _inputs.gatewayOwner = address(0);
    _inputs.grantRoles = grantRoles;
    InputUtils.FullDeployInputs memory sanitized = _harness.loadWarningsAndSanitizeInputs(
      _logger,
      _inputs,
      _deployer
    );
    InputUtils.FullDeployInputs memory expected = _inputs;
    expected.gatewayOwner = _deployer;
    assertEq(sanitized, expected);
  }

  function test_loadWarningsAndSanitizeInputs_withZeroNativeWrapper_fuzz(bool grantRoles) public {
    _inputs.nativeWrapper = address(0);
    _inputs.grantRoles = grantRoles;
    InputUtils.FullDeployInputs memory sanitized = _harness.loadWarningsAndSanitizeInputs(
      _logger,
      _inputs,
      _deployer
    );
    InputUtils.FullDeployInputs memory expected = _inputs;
    expected.nativeWrapper = address(0);
    assertEq(sanitized, expected);
  }

  function assertEq(
    InputUtils.FullDeployInputs memory a,
    InputUtils.FullDeployInputs memory b
  ) public pure {
    assertEq(a.accessManagerAdmin, b.accessManagerAdmin, 'access manager admin');
    assertEq(a.hubAdmin, b.hubAdmin, 'hub admin');
    assertEq(a.hubConfiguratorAdmin, b.hubConfiguratorAdmin, 'hub configurator admin');
    assertEq(a.treasurySpokeOwner, b.treasurySpokeOwner, 'treasury spoke owner');
    assertEq(a.spokeProxyAdminOwner, b.spokeProxyAdminOwner, 'spoke proxy admin owner');
    assertEq(a.spokeConfiguratorAdmin, b.spokeConfiguratorAdmin, 'spoke configurator admin');
    assertEq(a.spokeAdmin, b.spokeAdmin, 'spoke admin');
    assertEq(a.gatewayOwner, b.gatewayOwner, 'gateway owner');
    assertEq(a.nativeWrapper, b.nativeWrapper, 'native wrapper');
    assertEq(a.deployNativeTokenGateway, b.deployNativeTokenGateway, 'deploy native token gateway');
    assertEq(a.deploySignatureGateway, b.deploySignatureGateway, 'deploy signature gateway');
    assertEq(a.grantRoles, b.grantRoles, 'grant roles');
    assertEq(a.hubLabels, b.hubLabels, 'hub labels');
    assertEq(a.spokeLabels, b.spokeLabels, 'spoke labels');
    assertEq(abi.encode(a), abi.encode(b));
  }

  function _defaultSpokeMaxReservesLimits(
    uint256 count
  ) internal pure returns (uint16[] memory limits) {
    limits = new uint16[](count);
    for (uint256 i; i < count; i++) {
      limits[i] = Constants.MAX_ALLOWED_USER_RESERVES_LIMIT;
    }
  }

  function _defaultSpokeOracleDecimals(
    uint256 count
  ) internal pure returns (uint8[] memory decimals) {
    decimals = new uint8[](count);
    for (uint256 i; i < count; i++) {
      decimals[i] = Constants.ORACLE_DECIMALS;
    }
  }

  function _defaultSpokeOracleDescriptions(
    string[] memory labels
  ) internal pure returns (string[] memory descriptions) {
    descriptions = new string[](labels.length);
    for (uint256 i; i < labels.length; i++) {
      descriptions[i] = string.concat(labels[i], ' (USD)');
    }
  }
}
