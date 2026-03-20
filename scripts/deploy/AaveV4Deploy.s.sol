// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {AaveV4DeployBatchBaseScript} from 'scripts/deploy/AaveV4DeployBatchBase.s.sol';

contract AaveV4Deploy is AaveV4DeployBatchBaseScript {
  address public constant DEFAULT = address(0); // for deploy engine -> make this a sentinel
  address public constant NATIVE_WRAPPER = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
  uint256 public constant VERSION = 1;

  constructor() AaveV4DeployBatchBaseScript(_path()) {
    assert(block.chainid == 1 || block.chainid == 123456789);
  }

  function _getDeployInputs() internal view override returns (FullDeployInputs memory inputs) {
    string[] memory hubLabels = new string[](3);
    hubLabels[0] = 'PRIME_HUB';
    hubLabels[1] = 'CORE_HUB';
    hubLabels[2] = 'PLUS_HUB';

    string[] memory spokeLabels = new string[](10);
    spokeLabels[0] = 'MAIN_SPOKE';
    spokeLabels[1] = 'LIDO_ESPOKE';
    spokeLabels[2] = 'ETHERFI_ESPOKE';
    spokeLabels[3] = 'KELP_ESPOKE';
    spokeLabels[4] = 'LOMBARD_BTC_SPOKE';
    spokeLabels[5] = 'GOLD_SPOKE';
    spokeLabels[6] = 'FOREX_SPOKE';
    spokeLabels[7] = 'BLUECHIP_SPOKE';
    spokeLabels[8] = 'ETHENA_ECOSYSTEM_SPOKE';
    spokeLabels[9] = 'ETHENA_CORRELATED_SPOKE';

    inputs = FullDeployInputs({
      accessManagerAdmin: DEFAULT,
      hubAdmin: DEFAULT,
      hubProxyAdminOwner: DEFAULT,
      hubConfiguratorAdmin: DEFAULT,
      treasurySpokeOwner: DEFAULT,
      spokeAdmin: DEFAULT,
      spokeProxyAdminOwner: DEFAULT,
      spokeConfiguratorAdmin: DEFAULT,
      gatewayOwner: DEFAULT,
      positionManagerOwner: DEFAULT,
      nativeWrapper: NATIVE_WRAPPER,
      deployNativeTokenGateway: true,
      deploySignatureGateway: true,
      deployPositionManagers: true,
      grantRoles: true,
      hubLabels: hubLabels,
      spokeLabels: spokeLabels,
      spokeMaxReservesLimits: new uint16[](0), // defaults to MAX_USER_RESERVES_LIMIT
      salt: keccak256(bytes(_path()))
    });
  }

  function _path() internal view returns (string memory) {
    return string.concat('chain ', vm.toString(block.chainid), '_version ', vm.toString(VERSION));
  }
}
