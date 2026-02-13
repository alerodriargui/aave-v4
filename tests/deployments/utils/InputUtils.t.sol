// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {InputUtils} from 'src/deployments/utils/InputUtils.sol';

contract InputUtilsTest is Test, InputUtils {
  function test_computeDerivedSalts_basic() public pure {
    string[] memory hubLabels = new string[](2);
    hubLabels[0] = 'PRIME_HUB';
    hubLabels[1] = 'CORE_HUB';

    string[] memory spokeLabels = new string[](2);
    spokeLabels[0] = 'PRIME_SPOKE';
    spokeLabels[1] = 'CORE_SPOKE';

    FullDeployInputs memory inputs = _buildInputs(hubLabels, spokeLabels, bytes32(uint256(42)));

    DerivedSalts memory salts = computeDerivedSalts(inputs);
    bytes32 expectedRoot = keccak256(abi.encode(bytes32(uint256(42))));

    assertEq(salts.rootSalt, expectedRoot, 'rootSalt');
    assertEq(salts.accessSalt, expectedRoot, 'accessSalt == rootSalt');
    assertEq(
      salts.configuratorSalt,
      keccak256(abi.encode(expectedRoot, 'config')),
      'configuratorSalt'
    );
    assertEq(salts.gatewaySalt, keccak256(abi.encode(expectedRoot, 'gateways')), 'gatewaySalt');

    assertEq(salts.hubSalts.length, 2, 'hubSalts length');
    assertEq(
      salts.hubSalts[0],
      keccak256(abi.encode(expectedRoot, 'hub', 'PRIME_HUB')),
      'hubSalt[0]'
    );
    assertEq(
      salts.hubSalts[1],
      keccak256(abi.encode(expectedRoot, 'hub', 'CORE_HUB')),
      'hubSalt[1]'
    );

    assertEq(salts.spokeSalts.length, 2, 'spokeSalts length');
    assertEq(
      salts.spokeSalts[0],
      keccak256(abi.encode(expectedRoot, 'spoke', 'PRIME_SPOKE')),
      'spokeSalt[0]'
    );
    assertEq(
      salts.spokeSalts[1],
      keccak256(abi.encode(expectedRoot, 'spoke', 'CORE_SPOKE')),
      'spokeSalt[1]'
    );
  }

  function test_computeDerivedSalts_emptyLabels() public pure {
    string[] memory empty = new string[](0);
    FullDeployInputs memory inputs = _buildInputs(empty, empty, bytes32(uint256(1)));

    DerivedSalts memory salts = computeDerivedSalts(inputs);

    assertEq(salts.hubSalts.length, 0, 'empty hubSalts');
    assertEq(salts.spokeSalts.length, 0, 'empty spokeSalts');
    // Fixed salts still derived
    assertNotEq(salts.rootSalt, bytes32(0), 'rootSalt nonzero');
    assertNotEq(salts.configuratorSalt, bytes32(0), 'configuratorSalt nonzero');
    assertNotEq(salts.gatewaySalt, bytes32(0), 'gatewaySalt nonzero');
  }

  function test_computeDerivedSalts_fuzz(bytes32 salt) public pure {
    string[] memory hubLabels = new string[](1);
    hubLabels[0] = 'HUB';
    string[] memory spokeLabels = new string[](1);
    spokeLabels[0] = 'SPOKE';

    FullDeployInputs memory inputs = _buildInputs(hubLabels, spokeLabels, salt);
    DerivedSalts memory salts = computeDerivedSalts(inputs);

    bytes32 expectedRoot = keccak256(abi.encode(salt));
    assertEq(salts.rootSalt, expectedRoot, 'rootSalt');
    assertEq(salts.accessSalt, expectedRoot, 'accessSalt');
    assertEq(
      salts.configuratorSalt,
      keccak256(abi.encode(expectedRoot, 'config')),
      'configuratorSalt'
    );
    assertEq(salts.hubSalts[0], keccak256(abi.encode(expectedRoot, 'hub', 'HUB')), 'hubSalt');
    assertEq(
      salts.spokeSalts[0],
      keccak256(abi.encode(expectedRoot, 'spoke', 'SPOKE')),
      'spokeSalt'
    );
    assertEq(salts.gatewaySalt, keccak256(abi.encode(expectedRoot, 'gateways')), 'gatewaySalt');
  }

  function test_computeDerivedSalts_uniqueness() public pure {
    string[] memory hubLabels = new string[](2);
    hubLabels[0] = 'HUB_A';
    hubLabels[1] = 'HUB_B';
    string[] memory spokeLabels = new string[](2);
    spokeLabels[0] = 'SPOKE_A';
    spokeLabels[1] = 'SPOKE_B';

    FullDeployInputs memory inputs = _buildInputs(hubLabels, spokeLabels, bytes32(uint256(99)));
    DerivedSalts memory salts = computeDerivedSalts(inputs);

    // All salts should be unique
    assertNotEq(salts.accessSalt, salts.configuratorSalt, 'access != config');
    assertNotEq(salts.accessSalt, salts.gatewaySalt, 'access != gateway');
    assertNotEq(salts.configuratorSalt, salts.gatewaySalt, 'config != gateway');
    assertNotEq(salts.hubSalts[0], salts.hubSalts[1], 'hub[0] != hub[1]');
    assertNotEq(salts.spokeSalts[0], salts.spokeSalts[1], 'spoke[0] != spoke[1]');
    assertNotEq(salts.hubSalts[0], salts.spokeSalts[0], 'hub[0] != spoke[0]');
  }

  function test_computeDerivedSalts_differentSaltsYieldDifferentResults() public pure {
    string[] memory hubLabels = new string[](1);
    hubLabels[0] = 'HUB';
    string[] memory spokeLabels = new string[](1);
    spokeLabels[0] = 'SPOKE';

    FullDeployInputs memory inputs1 = _buildInputs(hubLabels, spokeLabels, bytes32(uint256(1)));
    FullDeployInputs memory inputs2 = _buildInputs(hubLabels, spokeLabels, bytes32(uint256(2)));

    DerivedSalts memory salts1 = computeDerivedSalts(inputs1);
    DerivedSalts memory salts2 = computeDerivedSalts(inputs2);

    assertNotEq(salts1.rootSalt, salts2.rootSalt, 'different root salts');
    assertNotEq(salts1.hubSalts[0], salts2.hubSalts[0], 'different hub salts');
    assertNotEq(salts1.spokeSalts[0], salts2.spokeSalts[0], 'different spoke salts');
  }

  function _buildInputs(
    string[] memory hubLabels,
    string[] memory spokeLabels,
    bytes32 salt
  ) internal pure returns (FullDeployInputs memory) {
    return
      FullDeployInputs({
        accessManagerAdmin: address(1),
        hubAdmin: address(2),
        hubConfiguratorAdmin: address(3),
        treasurySpokeOwner: address(4),
        spokeAdmin: address(5),
        spokeProxyAdminOwner: address(6),
        spokeConfiguratorAdmin: address(7),
        gatewayOwner: address(8),
        nativeWrapper: address(9),
        grantRoles: true,
        hubLabels: hubLabels,
        spokeLabels: spokeLabels,
        spokeMaxReservesLimits: new uint16[](spokeLabels.length),
        spokeOracleDecimals: new uint8[](spokeLabels.length),
        spokeOracleDescriptions: new string[](spokeLabels.length),
        salt: salt
      });
  }
}
