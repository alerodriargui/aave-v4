// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {AaveV4DeployBatchBaseScript} from './AaveV4DeployBatchBase.s.sol';
import {DeployConstants} from 'src/deployments/utils/libraries/DeployConstants.sol';

/// @title Anvil deploy script
/// @notice Deploys the full Aave V4 stack on a local Anvil instance.
///         All admin roles default to the deployer.
///   1. anvil
///   2. Etch the Safe Singleton Factory (CREATE2 factory) onto Anvil:
///        cast rpc anvil_setCode 0x914d7Fec6aaC8cd542e72Bca78B30650d45643d7 0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe03601600081602082378035828234f58015156039578182fd5b8082525050506014600cf3 --rpc-url http://127.0.0.1:8545
///   3. make deploy-precompile chain=anvil account=anvil
///   4. make deploy-contracts chain=anvil account=anvil
contract AaveV4DeployBatchAnvilScript is AaveV4DeployBatchBaseScript {
  constructor() AaveV4DeployBatchBaseScript('mainnet') {}

  function _getDeployInputs() internal pure override returns (FullDeployInputs memory inputs) {
    // All admin addresses left as address(0) — the base script defaults them to the deployer.

    inputs.grantRoles = true;
    inputs.deploySignatureGateway = true;
    inputs.deployNativeTokenGateway = true;
    inputs.deployPositionManagers = true;
    inputs.nativeWrapper = address(1);

    inputs.hubLabels = new string[](3);
    inputs.hubLabels[0] = 'PRIME_HUB';
    inputs.hubLabels[1] = 'CORE_HUB';
    inputs.hubLabels[2] = 'PLUS_HUB';

    inputs.spokeLabels = new string[](10);
    inputs.spokeLabels[0] = 'MAIN_SPOKE';
    inputs.spokeLabels[1] = 'LIDO_ESPOKE';
    inputs.spokeLabels[2] = 'ETHERFI_ESPOKE';
    inputs.spokeLabels[3] = 'KELP_ESPOKE';
    inputs.spokeLabels[4] = 'LOMBARD_BTC_SPOKE';
    inputs.spokeLabels[5] = 'GOLD_SPOKE';
    inputs.spokeLabels[6] = 'FOREX_SPOKE';
    inputs.spokeLabels[7] = 'BLUECHIP_SPOKE';
    inputs.spokeLabels[8] = 'ETHENA_ECOSYSTEM_SPOKE';
    inputs.spokeLabels[9] = 'ETHENA_CORRELATED_SPOKE';

    inputs.spokeMaxReservesLimits = new uint16[](inputs.spokeLabels.length);
    for (uint256 i; i < inputs.spokeMaxReservesLimits.length; ++i) {
      inputs.spokeMaxReservesLimits[i] = DeployConstants.MAX_ALLOWED_USER_RESERVES_LIMIT;
    }

    inputs.salt = keccak256('mainnet1');
  }

  /// @dev Skip the interactive prompt on Anvil.
  // function _executeUserPrompt() internal override {}
}
