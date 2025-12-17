// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {AaveV4DeployBatchBaseScript} from 'scripts/deploy/AaveV4DeployBatchBase.s.sol';
import {InputUtils} from 'src/deployments/utils/InputUtils.sol';
import {MetadataLogger} from 'src/deployments/utils/MetadataLogger.sol';

// contract AaveV4DeployBatchBaseScriptHarness is AaveV4DeployBatchBaseScript {
//   string public recordedWarnings;
//   bool public promptCalled;

//   constructor() AaveV4DeployBatchBaseScript('in.json', 'out.json') {}

//   function exposedSanitize(
//     InputUtils.FullDeployInputs memory inputs,
//     address deployer
//   ) external view returns (InputUtils.FullDeployInputs memory) {
//     return _sanitizeInputs(inputs, deployer);
//   }

//   function exposedLoadWarnings(
//     InputUtils.FullDeployInputs memory inputs
//   ) external returns (string memory warnings, bool promptWasCalled) {
//     MetadataLogger logger = new MetadataLogger('output/');
//     recordedWarnings = '';
//     promptCalled = false;
//     _loadWarnings(logger, inputs);
//     return (recordedWarnings, promptCalled);
//   }

//   function _logAndAppend(
//     MetadataLogger,
//     string memory warnings,
//     string memory warning
//   ) internal virtual override returns (string memory) {
//     recordedWarnings = string.concat(warnings, warning, '\n');
//     return recordedWarnings;
//   }

//   function _executeUserPrompt(string memory warnings) internal virtual override {
//     promptCalled = true;
//     recordedWarnings = warnings;
//   }
// }

// contract AaveV4DeployBatchBaseScriptTest is Test {
//   AaveV4DeployBatchBaseScriptHarness internal harness;

//   function setUp() public {
//     harness = new AaveV4DeployBatchBaseScriptHarness();
//   }

//   function _nonEmptyLabels() internal pure returns (string[] memory hubLabels, string[] memory spokeLabels) {
//     hubLabels = new string[](1);
//     hubLabels[0] = 'hub';
//     spokeLabels = new string[](1);
//     spokeLabels[0] = 'spoke';
//   }

//   function test_sanitize_defaultsZeroAddressesToDeployer() public {
//     (string[] memory hubLabels, string[] memory spokeLabels) = _nonEmptyLabels();
//     InputUtils.FullDeployInputs memory inputs = InputUtils.FullDeployInputs({
//       accessManagerAdmin: address(0),
//       hubAdmin: address(0),
//       hubConfiguratorOwner: address(0),
//       treasurySpokeOwner: address(0),
//       spokeAdmin: address(0),
//       spokeProxyAdminOwner: address(0),
//       spokeConfiguratorOwner: address(0),
//       gatewayOwner: address(0),
//       nativeWrapper: address(1),
//       grantRoles: true,
//       hubLabels: hubLabels,
//       spokeLabels: spokeLabels
//     });
//     address deployer = address(0xBEEF);

//     InputUtils.FullDeployInputs memory sanitized = harness.exposedSanitize(inputs, deployer);

//     assertEq(sanitized.accessManagerAdmin, deployer);
//     assertEq(sanitized.hubConfiguratorOwner, deployer);
//     assertEq(sanitized.treasurySpokeOwner, deployer);
//     assertEq(sanitized.spokeProxyAdminOwner, deployer);
//     assertEq(sanitized.spokeConfiguratorOwner, deployer);
//     assertEq(sanitized.gatewayOwner, deployer);
//     // untouched fields
//     assertEq(sanitized.nativeWrapper, inputs.nativeWrapper);
//     assertEq(sanitized.hubAdmin, inputs.hubAdmin);
//     assertEq(sanitized.spokeAdmin, inputs.spokeAdmin);
//   }

//   function test_sanitize_preservesNonZero() public {
//     (string[] memory hubLabels, string[] memory spokeLabels) = _nonEmptyLabels();
//     InputUtils.FullDeployInputs memory inputs = InputUtils.FullDeployInputs({
//       accessManagerAdmin: address(1),
//       hubAdmin: address(2),
//       hubConfiguratorOwner: address(3),
//       treasurySpokeOwner: address(4),
//       spokeAdmin: address(5),
//       spokeProxyAdminOwner: address(6),
//       spokeConfiguratorOwner: address(7),
//       gatewayOwner: address(8),
//       nativeWrapper: address(9),
//       grantRoles: true,
//       hubLabels: hubLabels,
//       spokeLabels: spokeLabels
//     });

//     InputUtils.FullDeployInputs memory sanitized = harness.exposedSanitize(inputs, address(0xBEEF));

//     assertEq(sanitized.accessManagerAdmin, inputs.accessManagerAdmin);
//     assertEq(sanitized.hubConfiguratorOwner, inputs.hubConfiguratorOwner);
//     assertEq(sanitized.treasurySpokeOwner, inputs.treasurySpokeOwner);
//     assertEq(sanitized.spokeProxyAdminOwner, inputs.spokeProxyAdminOwner);
//     assertEq(sanitized.spokeConfiguratorOwner, inputs.spokeConfiguratorOwner);
//     assertEq(sanitized.gatewayOwner, inputs.gatewayOwner);
//     assertEq(sanitized.nativeWrapper, inputs.nativeWrapper);
//   }

//   function test_loadWarnings_noWarnings_noPrompt() public {
//     (string[] memory hubLabels, string[] memory spokeLabels) = _nonEmptyLabels();
//     InputUtils.FullDeployInputs memory inputs = InputUtils.FullDeployInputs({
//       accessManagerAdmin: address(1),
//       hubAdmin: address(2),
//       hubConfiguratorOwner: address(3),
//       treasurySpokeOwner: address(4),
//       spokeAdmin: address(5),
//       spokeProxyAdminOwner: address(6),
//       spokeConfiguratorOwner: address(7),
//       gatewayOwner: address(8),
//       nativeWrapper: address(9),
//       grantRoles: false,
//       hubLabels: hubLabels,
//       spokeLabels: spokeLabels
//     });

//     (string memory warnings, bool promptCalled) = harness.exposedLoadWarnings(inputs);

//     assertEq(bytes(warnings).length, 0);
//     assertFalse(promptCalled);
//   }

//   function test_loadWarnings_withWarnings_triggersPrompt() public {
//     string[] memory empty;
//     InputUtils.FullDeployInputs memory inputs = InputUtils.FullDeployInputs({
//       accessManagerAdmin: address(0),
//       hubAdmin: address(0),
//       hubConfiguratorOwner: address(0),
//       treasurySpokeOwner: address(0),
//       spokeAdmin: address(0),
//       spokeProxyAdminOwner: address(0),
//       spokeConfiguratorOwner: address(0),
//       gatewayOwner: address(0),
//       nativeWrapper: address(0),
//       grantRoles: true,
//       hubLabels: empty,
//       spokeLabels: empty
//     });

//     (string memory warnings, bool promptCalled) = harness.exposedLoadWarnings(inputs);

//     assertTrue(promptCalled);
//     assertTrue(bytes(warnings).length > 0);
//     // Should include at least one known warning
//     assertTrue(_contains(warnings, 'Roles are being set'));
//     assertTrue(_contains(warnings, 'Spoke will not be deployed'));
//   }

//   function _contains(string memory haystack, string memory needle) internal pure returns (bool) {
//     return bytes(haystack).length >= bytes(needle).length &&
//       bytes(haystack).length != 0 &&
//       bytes(needle).length != 0 &&
//       _indexOf(haystack, needle) != type(uint256).max;
//   }

//   function _indexOf(string memory haystack, string memory needle) internal pure returns (uint256) {
//     bytes memory h = bytes(haystack);
//     bytes memory n = bytes(needle);
//     if (n.length == 0 || n.length > h.length) return type(uint256).max;
//     for (uint256 i; i <= h.length - n.length; ++i) {
//       bool match = true;
//       for (uint256 j; j < n.length; ++j) {
//         if (h[i + j] != n[j]) {
//           match = false;
//           break;
//         }
//       }
//       if (match) return i;
//     }
//     return type(uint256).max;
//   }
// }
