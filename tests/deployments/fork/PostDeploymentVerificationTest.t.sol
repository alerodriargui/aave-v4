// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {PostDeploymentVerificationBase} from 'tests/deployments/fork/PostDeploymentVerificationBase.t.sol';
import {AaveV4DeployAnvil} from 'scripts/deploy/examples/AaveV4DeployAnvil.s.sol';
import {InputUtils} from 'src/deployments/utils/libraries/InputUtils.sol';

/// @title PostDeploymentVerificationTest
/// @author Aave Labs
/// @notice Integration test that deploys all Aave V4 contracts, writes the JSON deployment report,
///         reads it back, and verifies the parsed report matches on-chain state.
contract PostDeploymentVerificationTest is PostDeploymentVerificationBase, AaveV4DeployAnvil {
  string internal constant FILE_NAME = 'anvil-integration';

  /// @dev Fuzz input struct to keep the parameter count under the Solidity limit.
  struct FuzzParams {
    address accessManagerAdmin;
    address hubAdmin;
    address hubProxyAdminOwner;
    address hubConfiguratorAdmin;
    address treasurySpokeOwner;
    address spokeAdmin;
    address spokeProxyAdminOwner;
    address spokeConfiguratorAdmin;
    address gatewayOwner;
    address positionManagerOwner;
    bool deployNativeTokenGateway;
    bool useValidNativeWrapper;
    bool deploySignatureGateway;
    bool deployPositionManagers;
    bool grantRoles;
    bytes32 salt;
    uint8 hubCount;
    uint8 spokeCount;
  }

  function setUp() public override(PostDeploymentVerificationBase) {
    _etchCreate2Factory();
    _deployer = makeAddr('deployer');
    PostDeploymentVerificationBase.setUp();
  }

  /// @notice Deterministic test with the hardcoded Anvil deploy inputs (includes JSON round-trip).
  function testPostDeploymentCheck() public {
    InputUtils.FullDeployInputs memory sanitizedInputs = _loadWarningsAndSanitizeInputs(
      _getDeployInputs(),
      _deployer
    );
    _deployWriteReportAndVerify(sanitizedInputs, OUTPUT_DIR, FILE_NAME);
  }

  /// forge-config: default.fuzz.runs = 1000
  function testFuzz_postDeploymentCheck(FuzzParams memory params) public {
    params.hubCount = uint8(bound(params.hubCount, 1, 5));
    params.spokeCount = uint8(bound(params.spokeCount, 1, 5));

    InputUtils.FullDeployInputs memory rawInputs = _bound(params);

    if (_shouldExpectRevert(rawInputs)) {
      vm.expectRevert();
      this.sanitizeAndDeploy(rawInputs);
    } else {
      InputUtils.FullDeployInputs memory sanitizedInputs = _loadWarningsAndSanitizeInputs(
        rawInputs,
        _deployer
      );
      string memory fuzzFileName = string.concat('fuzz-', vm.toString(params.salt));
      _deployWriteReportAndVerify(sanitizedInputs, OUTPUT_DIR, fuzzFileName);
      // rm file after deployment to avoid serialize collisions on subsequent fuzz runs
      try vm.removeFile(_reportFile) {} catch {}
    }
  }

  /// @dev External entry point so tests work for revert handling.
  function sanitizeAndDeploy(InputUtils.FullDeployInputs memory rawInputs) external {
    InputUtils.FullDeployInputs memory sanitizedInputs = _loadWarningsAndSanitizeInputs(
      rawInputs,
      _deployer
    );
    _deployAndVerify(sanitizedInputs);
  }

  function _bound(
    FuzzParams memory p
  ) internal view returns (InputUtils.FullDeployInputs memory inputs) {
    string[] memory hubLabels = new string[](p.hubCount);
    for (uint256 i; i < p.hubCount; i++) {
      hubLabels[i] = string.concat('hub', vm.toString(i));
    }

    string[] memory spokeLabels = new string[](p.spokeCount);
    for (uint256 i; i < p.spokeCount; i++) {
      spokeLabels[i] = string.concat('spoke', vm.toString(i));
    }

    inputs = InputUtils.FullDeployInputs({
      accessManagerAdmin: p.accessManagerAdmin,
      hubAdmin: p.hubAdmin,
      hubProxyAdminOwner: p.hubProxyAdminOwner,
      hubConfiguratorAdmin: p.hubConfiguratorAdmin,
      treasurySpokeOwner: p.treasurySpokeOwner,
      spokeAdmin: p.spokeAdmin,
      spokeProxyAdminOwner: p.spokeProxyAdminOwner,
      spokeConfiguratorAdmin: p.spokeConfiguratorAdmin,
      gatewayOwner: p.gatewayOwner,
      positionManagerOwner: p.positionManagerOwner,
      nativeWrapper: (p.deployNativeTokenGateway && p.useValidNativeWrapper) ? weth : address(0),
      deployNativeTokenGateway: p.deployNativeTokenGateway,
      deploySignatureGateway: p.deploySignatureGateway,
      deployPositionManagers: p.deployPositionManagers,
      grantRoles: p.grantRoles,
      hubLabels: hubLabels,
      spokeLabels: spokeLabels,
      spokeMaxReservesLimits: new uint16[](0),
      salt: p.salt
    });
  }

  /// @dev Returns true if the given inputs are expected to cause a revert during deployment.
  function _shouldExpectRevert(
    InputUtils.FullDeployInputs memory inputs
  ) internal pure returns (bool) {
    // NativeTokenGateway requires a non-zero nativeWrapper address
    if (inputs.deployNativeTokenGateway && inputs.nativeWrapper == address(0)) {
      return true;
    }
    return false;
  }
}
