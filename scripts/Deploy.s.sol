pragma solidity ^0.8.0;

import {Script} from 'forge-std/Script.sol';
import {Roles} from 'src/deployments/utils/libraries/Roles.sol';
import {Infra, Spokes} from './payload/AaveV4Contracts.sol';
import {AaveV4ConfigEngine} from 'src/config-engine/AaveV4ConfigEngine.sol';
import {IAccessManager} from 'src/dependencies/openzeppelin/IAccessManager.sol';
import {IPositionManagerBase} from 'src/position-manager/interfaces/IPositionManagerBase.sol';
import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';

import {ConfigPayload_1_HubAssetListings} from './payload/ConfigPayload_1_HubAssetListings.sol';
import {ConfigPayload_2_HubSpokeRegistrations} from './payload/ConfigPayload_2_HubSpokeRegistrations.sol';
import {ConfigPayload_3a_SpokeReserveListings} from './payload/ConfigPayload_3a_SpokeReserveListings.sol';
import {ConfigPayload_3b_SpokeReserveListings} from './payload/ConfigPayload_3b_SpokeReserveListings.sol';
import {ConfigPayload_4_SpokePositionManagerUpdates} from './payload/ConfigPayload_4_SpokePositionManagerUpdates.sol';
import {ConfigPayload_5_PositionManagerSpokeRegistrations} from './payload/ConfigPayload_5_PositionManagerSpokeRegistrations.sol';
import {PermissionsPayload} from './payload/PermissionsPayload.sol';
import {NativeTokenGateway} from 'src/position-manager/NativeTokenGateway.sol';
import 'forge-std/console.sol';

import {TokenizationSpokePayload} from './payload/TokenizationSpokePayload.sol';

contract Deploy is Script {
  IExecutor public constant EXECUTOR = IExecutor(0xA972CCe333e8FC64CF10118DB2f98757617A9bC9);
  // IExecutor public constant EXECUTOR = IExecutor(0x19eed38fdB33B11b24184C6a2aef5ba95E490c2E);
  address public constant NATIVE_WRAPPER = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

  function tokenize() public {
    vm.startBroadcast();
    address payload = address(new TokenizationSpokePayload(new AaveV4ConfigEngine()));
    _exec(payload);
  }

  function native() public {
    vm.startBroadcast();
    (, address caller, ) = vm.readCallers();
    NativeTokenGateway nativeGateway = new NativeTokenGateway(NATIVE_WRAPPER, caller);
    // nativeGateway.acceptOwnership();

    address[10] memory spokes = [
      Spokes.BLUECHIP_SPOKE,
      Spokes.ETHENA_CORRELATED_SPOKE,
      Spokes.ETHENA_ECOSYSTEM_SPOKE,
      Spokes.ETHERFI_ESPOKE,
      Spokes.FOREX_SPOKE,
      Spokes.GOLD_SPOKE,
      Spokes.KELP_ESPOKE,
      Spokes.LIDO_ESPOKE,
      Spokes.LOMBARD_BTC_SPOKE,
      Spokes.MAIN_SPOKE
    ];

    for (uint i; i < spokes.length; ++i) {
      address spoke = spokes[i];
      nativeGateway.registerSpoke(spoke, true);
      ISpoke(spoke).updatePositionManager(address(nativeGateway), true);
    }
  }

  function run() public {
    vm.startBroadcast();
    address[5] memory positionManagers = [
      Infra.CONFIG_POSITION_MANAGER,
      Infra.GIVER_POSITION_MANAGER,
      Infra.TAKER_POSITION_MANAGER,
      Infra.NATIVE_TOKEN_GATEWAY,
      Infra.SIGNATURE_GATEWAY
    ];
    for (uint256 i; i < positionManagers.length; ++i) {
      IOwnable2Step(positionManagers[i]).transferOwnership(address(EXECUTOR));
    }

    IAccessManager(Infra.ACCESS_MANAGER).grantRole(
      Roles.HUB_CONFIGURATOR_DEFAULT_ADMIN_ROLE,
      address(EXECUTOR),
      0
    );
    IAccessManager(Infra.ACCESS_MANAGER).grantRole(
      Roles.SPOKE_CONFIGURATOR_DEFAULT_ADMIN_ROLE,
      address(EXECUTOR),
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

  function _exec(address payload) internal {
    EXECUTOR.executeTransaction({
      target: payload,
      value: 0,
      signature: 'execute()',
      data: new bytes(0),
      withDelegatecall: true
    });
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

/*
configEngine=0xE6C7527409f362bf210ac0b7cdBF1d67f7fA3866
executor=0x19eed38fdB33B11b24184C6a2aef5ba95E490c2E
execSig=0x025d36a9 # $(cast sig "executeTransaction(address target,uint256,string memory,bytes memory,bool)")

forge create scripts/payload/ConfigPayload_1_HubAssetListings.sol:ConfigPayload_1_HubAssetListings --constructor-args $engineDevnet --rpc-url devnet --account test --broadcast
forge create scripts/payload/ConfigPayload_2_HubSpokeRegistrations.sol:ConfigPayload_2_HubSpokeRegistrations --constructor-args $engineDevnet --rpc-url devnet --account test --broadcast
forge create scripts/payload/ConfigPayload_3a_SpokeReserveListings.sol:ConfigPayload_3a_SpokeReserveListings --constructor-args $engineDevnet --rpc-url devnet --account test --broadcast
forge create scripts/payload/ConfigPayload_3b_SpokeReserveListings.sol:ConfigPayload_3b_SpokeReserveListings --constructor-args $engineDevnet --rpc-url devnet --account test --broadcast
forge create scripts/payload/ConfigPayload_4_SpokePositionManagerUpdates.sol:ConfigPayload_4_SpokePositionManagerUpdates --constructor-args $engineDevnet --rpc-url devnet --account test --broadcast
forge create scripts/payload/ConfigPayload_5_PositionManagerSpokeRegistrations.sol:ConfigPayload_5_PositionManagerSpokeRegistrations --constructor-args $engineDevnet --rpc-url devnet --account test --broadcast


payload1=0xEE48d73D3CA8C67EF3D693F97B903efd79E837E8
cast send $executor $execSig --rpc-url devnet --account test $payload1 0 'execute()' '' true

*/
