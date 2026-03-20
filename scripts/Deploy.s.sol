pragma solidity ^0.8.0;

import {Script} from 'forge-std/Script.sol';
import {Roles} from 'src/deployments/utils/libraries/Roles.sol';
import {Infra, Spokes} from 'scripts/payload/AaveV4Contracts.sol';
import {AaveV4ConfigEngine} from 'src/config-engine/AaveV4ConfigEngine.sol';
import {IAccessManager} from 'src/dependencies/openzeppelin/IAccessManager.sol';
import {IPositionManagerBase} from 'src/position-manager/interfaces/IPositionManagerBase.sol';
import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';

import {ConfigPayload_1_HubAssetListings} from 'src/config-engine/payloads/ConfigPayload_1_HubAssetListings.sol';
import {ConfigPayload_2_HubSpokeRegistrations} from 'src/config-engine/payloads/ConfigPayload_2_HubSpokeRegistrations.sol';
import {ConfigPayload_3a_SpokeReserveListings} from 'src/config-engine/payloads/ConfigPayload_3a_SpokeReserveListings.sol';
import {ConfigPayload_3b_SpokeReserveListings} from 'src/config-engine/payloads/ConfigPayload_3b_SpokeReserveListings.sol';
import {ConfigPayload_4_SpokePositionManagerUpdates} from 'src/config-engine/payloads/ConfigPayload_4_SpokePositionManagerUpdates.sol';
import {ConfigPayload_5_PositionManagerSpokeRegistrations} from 'src/config-engine/payloads/ConfigPayload_5_PositionManagerSpokeRegistrations.sol';
import {PermissionsPayload} from 'src/config-engine/payloads/PermissionsPayload.sol';

// import {TokenizationSpokePayload} from './payload/TokenizationSpokePayload.sol';
// import {Payload} from 'src/Payload.sol';

contract Deploy is Script {
  address public constant NATIVE_WRAPPER = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

  function payload() public {
    vm.startBroadcast();
    address[5] memory positionManagers = [
      Infra.CONFIG_POSITION_MANAGER,
      Infra.GIVER_POSITION_MANAGER,
      Infra.TAKER_POSITION_MANAGER,
      Infra.NATIVE_TOKEN_GATEWAY,
      Infra.SIGNATURE_GATEWAY
    ];
    for (uint256 i; i < positionManagers.length; ++i) {
      IOwnable2Step(positionManagers[i]).transferOwnership(address(_executor()));
    }

    IAccessManager(Infra.ACCESS_MANAGER).grantRole(
      Roles.HUB_CONFIGURATOR_DOMAIN_ADMIN_ROLE,
      address(_executor()),
      0
    );
    IAccessManager(Infra.ACCESS_MANAGER).grantRole(
      Roles.SPOKE_CONFIGURATOR_DOMAIN_ADMIN_ROLE,
      address(_executor()),
      0
    );

    _exec(address(new PermissionsPayload()));

    AaveV4ConfigEngine configEngine = new AaveV4ConfigEngine();

    address[6] memory payloads = [
      address(new ConfigPayload_1_HubAssetListings(configEngine)),
      address(new ConfigPayload_2_HubSpokeRegistrations(configEngine)),
      address(new ConfigPayload_3a_SpokeReserveListings(configEngine)),
      address(new ConfigPayload_3b_SpokeReserveListings(configEngine)),
      address(new ConfigPayload_4_SpokePositionManagerUpdates(configEngine)),
      address(new ConfigPayload_5_PositionManagerSpokeRegistrations(configEngine))
    ];

    for (uint256 i; i < payloads.length; ++i) {
      _exec(payloads[i]);
    }
  }

  function _exec(address target) internal {
    _executor().executeTransaction({
      target: target,
      value: 0,
      signature: 'execute()',
      data: new bytes(0),
      withDelegatecall: true
    });
  }

  function _executor() internal view returns (IExecutor) {
    if (block.chainid == 1) return IExecutor(0xA972CCe333e8FC64CF10118DB2f98757617A9bC9);
    else if (block.chainid == 123456789)
      return IExecutor(0x19eed38fdB33B11b24184C6a2aef5ba95E490c2E);
    revert(string.concat(vm.toString(block.chainid), 'not configured'));
  }
}

interface IExecutor {
  function executeTransaction(
    address target,
    uint256 value,
    string memory signature,
    bytes memory data,
    bool withDelegatecall
  ) external payable returns (bytes memory);
}

interface IOwnable2Step {
  function transferOwnership(address newOwner) external;
}
