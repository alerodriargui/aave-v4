// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';
import {OwnableUpgradeable} from 'src/dependencies/openzeppelin-upgradeable/OwnableUpgradeable.sol';
import {TransparentUpgradeableProxy} from 'src/dependencies/openzeppelin/TransparentUpgradeableProxy.sol';
import {V4AddressesProvider} from 'src/addresses-provider/V4AddressesProvider.sol';
import {V4AddressesProviderInstance} from 'src/addresses-provider/instances/V4AddressesProviderInstance.sol';
import {IV4AddressesProvider} from 'src/addresses-provider/interfaces/IV4AddressesProvider.sol';

contract V4AddressesProviderTest is Test {
  address internal OWNER = makeAddr('OWNER');
  address internal PROXY_ADMIN_OWNER = makeAddr('PROXY_ADMIN_OWNER');

  V4AddressesProvider internal provider;

  function setUp() public {
    provider = V4AddressesProvider(
      address(
        new TransparentUpgradeableProxy(
          address(new V4AddressesProviderInstance()),
          PROXY_ADMIN_OWNER,
          abi.encodeCall(V4AddressesProviderInstance.initialize, (OWNER))
        )
      )
    );
  }

  function test_initialize() public view {
    assertEq(provider.owner(), OWNER);
    assertEq(provider.CANONICAL_HUB_TAG(), 'CANONICAL_HUB');
    assertEq(provider.CANONICAL_SPOKE_TAG(), 'CANONICAL_SPOKE');
    assertEq(provider.TOKENIZATION_SPOKE_TAG(), 'TOKENIZATION_SPOKE');
    assertEq(provider.TREASURY_SPOKE_TAG(), 'TREASURY_SPOKE');
  }

  function test_transferOwnership_twoStep() public {
    address newOwner = makeAddr('NEW_OWNER');

    vm.prank(OWNER);
    provider.transferOwnership(newOwner);

    assertEq(provider.owner(), OWNER);
    assertEq(provider.pendingOwner(), newOwner);

    vm.prank(newOwner);
    provider.acceptOwnership();

    assertEq(provider.owner(), newOwner);
    assertEq(provider.pendingOwner(), address(0));
  }

  function test_getId() public view {
    assertEq(
      provider.getId({name: 'CORE', tag: provider.CANONICAL_HUB_TAG()}),
      keccak256(bytes('CORE_CANONICAL_HUB'))
    );
    assertEq(
      provider.getId({name: 'MAIN', tag: provider.CANONICAL_SPOKE_TAG()}),
      keccak256(bytes('MAIN_CANONICAL_SPOKE'))
    );
    assertEq(
      provider.getId({name: 'CORE_WETH', tag: provider.TOKENIZATION_SPOKE_TAG()}),
      keccak256(bytes('CORE_WETH_TOKENIZATION_SPOKE'))
    );
    assertEq(
      provider.getId({name: 'MAIN', tag: provider.TREASURY_SPOKE_TAG()}),
      keccak256(bytes('MAIN_TREASURY_SPOKE'))
    );
  }

  function test_setAddress() public {
    bytes32 id = provider.getId({name: 'CONFIG_ENGINE', tag: 'PERIPHERY'});
    address configEngine = makeAddr('CONFIG_ENGINE');

    vm.expectEmit(address(provider));
    emit IV4AddressesProvider.AddressSet(
      id,
      'CONFIG_ENGINE',
      'PERIPHERY',
      address(0),
      configEngine
    );

    vm.prank(OWNER);
    provider.setAddress({name: 'CONFIG_ENGINE', tag: 'PERIPHERY', newAddress: configEngine});

    assertEq(provider.getAddress(id), configEngine);
    assertEq(provider.getAddress({name: 'CONFIG_ENGINE', tag: 'PERIPHERY'}), configEngine);

    IV4AddressesProvider.AddressEntry memory entry = provider.getAddressEntry(id);
    assertEq(entry.addr, configEngine);
    assertEq(entry.tag, 'PERIPHERY');

    bytes32[] memory ids = provider.getIds('PERIPHERY');
    assertEq(ids.length, 1);
    assertEq(ids[0], id);

    string[] memory tags = provider.getTags();
    assertEq(tags.length, 1);
    assertEq(tags[0], 'PERIPHERY');
  }

  function test_setAddress_remove() public {
    bytes32 id = provider.getId({name: 'CONFIG_ENGINE', tag: 'PERIPHERY'});

    vm.startPrank(OWNER);
    provider.setAddress({
      name: 'CONFIG_ENGINE',
      tag: 'PERIPHERY',
      newAddress: makeAddr('CONFIG_ENGINE')
    });
    provider.setAddress({name: 'CONFIG_ENGINE', tag: 'PERIPHERY', newAddress: address(0)});
    vm.stopPrank();

    assertEq(provider.getAddress(id), address(0));
    assertEq(provider.getAddressEntry(id).tag, '');
    assertEq(provider.getIds('PERIPHERY').length, 0);
    assertEq(provider.getTags().length, 0);
  }

  function test_setAddress_removeThenSet() public {
    bytes32 id = provider.getId({name: 'CONFIG_ENGINE', tag: 'PERIPHERY'});
    address newConfigEngine = makeAddr('NEW_CONFIG_ENGINE');

    vm.startPrank(OWNER);
    provider.setAddress({
      name: 'CONFIG_ENGINE',
      tag: 'PERIPHERY',
      newAddress: makeAddr('CONFIG_ENGINE')
    });
    provider.setAddress({name: 'CONFIG_ENGINE', tag: 'PERIPHERY', newAddress: address(0)});
    provider.setAddress({name: 'CONFIG_ENGINE', tag: 'PERIPHERY', newAddress: newConfigEngine});
    vm.stopPrank();

    assertEq(provider.getAddress(id), newConfigEngine);

    bytes32[] memory ids = provider.getIds('PERIPHERY');
    assertEq(ids.length, 1);
    assertEq(ids[0], id);
  }

  function test_setAddress_revertsWith_AddressAlreadySet() public {
    bytes32 id = provider.getId({name: 'CONFIG_ENGINE', tag: 'PERIPHERY'});
    address configEngine = makeAddr('CONFIG_ENGINE');

    vm.startPrank(OWNER);
    provider.setAddress({name: 'CONFIG_ENGINE', tag: 'PERIPHERY', newAddress: configEngine});

    vm.expectRevert(abi.encodeWithSelector(IV4AddressesProvider.AddressAlreadySet.selector, id));
    provider.setAddress({
      name: 'CONFIG_ENGINE',
      tag: 'PERIPHERY',
      newAddress: makeAddr('NEW_CONFIG_ENGINE')
    });

    vm.expectRevert(abi.encodeWithSelector(IV4AddressesProvider.AddressAlreadySet.selector, id));
    provider.setAddress({name: 'CONFIG_ENGINE', tag: 'PERIPHERY', newAddress: configEngine});
    vm.stopPrank();
  }

  function test_setAddress_idCollision_revertsWith_AddressAlreadySet() public {
    bytes32 id = provider.getId({name: 'A', tag: 'B_C'});
    assertEq(id, provider.getId({name: 'A_B', tag: 'C'}));

    vm.startPrank(OWNER);
    provider.setAddress({name: 'A', tag: 'B_C', newAddress: makeAddr('A')});

    vm.expectRevert(abi.encodeWithSelector(IV4AddressesProvider.AddressAlreadySet.selector, id));
    provider.setAddress({name: 'A_B', tag: 'C', newAddress: makeAddr('A_B')});
    vm.stopPrank();
  }

  function test_setAddress_sameAddressUnderMultipleIds() public {
    address configEngine = makeAddr('CONFIG_ENGINE');

    vm.startPrank(OWNER);
    provider.setAddress({name: 'CONFIG_ENGINE', tag: 'PERIPHERY', newAddress: configEngine});
    provider.setAddress({name: 'ENGINE', tag: 'PERIPHERY', newAddress: configEngine});
    provider.setAddress({name: 'CONFIG_ENGINE', tag: 'ENGINE', newAddress: configEngine});
    provider.setAddress({name: 'V3_CONFIG_ENGINE', tag: 'V3_PERIPHERY', newAddress: configEngine});
    vm.stopPrank();

    assertEq(provider.getAddress({name: 'CONFIG_ENGINE', tag: 'PERIPHERY'}), configEngine);
    assertEq(provider.getAddress({name: 'ENGINE', tag: 'PERIPHERY'}), configEngine);
    assertEq(provider.getAddress({name: 'CONFIG_ENGINE', tag: 'ENGINE'}), configEngine);
    assertEq(provider.getAddress({name: 'V3_CONFIG_ENGINE', tag: 'V3_PERIPHERY'}), configEngine);

    bytes32[] memory peripheryIds = provider.getIds('PERIPHERY');
    assertEq(peripheryIds.length, 2);
    assertEq(peripheryIds[0], provider.getId({name: 'CONFIG_ENGINE', tag: 'PERIPHERY'}));
    assertEq(peripheryIds[1], provider.getId({name: 'ENGINE', tag: 'PERIPHERY'}));

    string[] memory tags = provider.getTags();
    assertEq(tags.length, 3);
    assertEq(tags[0], 'PERIPHERY');
    assertEq(tags[1], 'ENGINE');
    assertEq(tags[2], 'V3_PERIPHERY');

    // removing one entry does not affect the other entries of the same address
    vm.prank(OWNER);
    provider.setAddress({name: 'ENGINE', tag: 'PERIPHERY', newAddress: address(0)});

    assertEq(provider.getAddress({name: 'ENGINE', tag: 'PERIPHERY'}), address(0));
    assertEq(provider.getAddress({name: 'CONFIG_ENGINE', tag: 'PERIPHERY'}), configEngine);
    assertEq(provider.getAddress({name: 'CONFIG_ENGINE', tag: 'ENGINE'}), configEngine);
    assertEq(provider.getIds('PERIPHERY').length, 1);
  }

  function test_setHubAndSpoke_sameAddressAcrossTags() public {
    address sharedSpoke = makeAddr('SHARED_SPOKE');

    vm.startPrank(OWNER);
    provider.setCanonicalSpoke('MAIN', sharedSpoke);
    provider.setTokenizationSpoke('MAIN', sharedSpoke);
    provider.setTreasurySpoke('MAIN', sharedSpoke);
    vm.stopPrank();

    assertEq(provider.getCanonicalSpoke('MAIN'), sharedSpoke);
    assertEq(provider.getTokenizationSpoke('MAIN'), sharedSpoke);
    assertEq(provider.getTreasurySpoke('MAIN'), sharedSpoke);

    address[] memory canonicalSpokes = provider.getCanonicalSpokes();
    assertEq(canonicalSpokes.length, 1);
    assertEq(canonicalSpokes[0], sharedSpoke);

    address[] memory tokenizationSpokes = provider.getTokenizationSpokes();
    assertEq(tokenizationSpokes.length, 1);
    assertEq(tokenizationSpokes[0], sharedSpoke);

    address[] memory treasurySpokes = provider.getTreasurySpokes();
    assertEq(treasurySpokes.length, 1);
    assertEq(treasurySpokes[0], sharedSpoke);
  }

  function test_setAddress_remove_revertsWith_AddressNotSet() public {
    bytes32 id = provider.getId({name: 'CONFIG_ENGINE', tag: 'PERIPHERY'});

    vm.startPrank(OWNER);
    vm.expectRevert(abi.encodeWithSelector(IV4AddressesProvider.AddressNotSet.selector, id));
    provider.setAddress({name: 'CONFIG_ENGINE', tag: 'PERIPHERY', newAddress: address(0)});

    provider.setAddress({
      name: 'CONFIG_ENGINE',
      tag: 'PERIPHERY',
      newAddress: makeAddr('CONFIG_ENGINE')
    });
    provider.setAddress({name: 'CONFIG_ENGINE', tag: 'PERIPHERY', newAddress: address(0)});

    vm.expectRevert(abi.encodeWithSelector(IV4AddressesProvider.AddressNotSet.selector, id));
    provider.setAddress({name: 'CONFIG_ENGINE', tag: 'PERIPHERY', newAddress: address(0)});
    vm.stopPrank();
  }

  function test_setAddress_revertsWith_InvalidName() public {
    vm.expectRevert(IV4AddressesProvider.InvalidName.selector);
    vm.prank(OWNER);
    provider.setAddress({name: '', tag: 'PERIPHERY', newAddress: makeAddr('CONFIG_ENGINE')});
  }

  function test_setAddress_revertsWith_InvalidTag() public {
    vm.expectRevert(IV4AddressesProvider.InvalidTag.selector);
    vm.prank(OWNER);
    provider.setAddress({name: 'CONFIG_ENGINE', tag: '', newAddress: makeAddr('CONFIG_ENGINE')});
  }

  function test_setAddress_revertsWith_OwnableUnauthorizedAccount() public {
    address caller = makeAddr('caller');

    vm.expectRevert(
      abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, caller)
    );
    vm.prank(caller);
    provider.setAddress({
      name: 'CONFIG_ENGINE',
      tag: 'PERIPHERY',
      newAddress: makeAddr('CONFIG_ENGINE')
    });
  }

  function test_setCanonicalHub() public {
    address coreHub = makeAddr('CORE_HUB');
    address plusHub = makeAddr('PLUS_HUB');
    address primeHub = makeAddr('PRIME_HUB');

    vm.startPrank(OWNER);
    vm.expectEmit(address(provider));
    emit IV4AddressesProvider.AddressSet(
      keccak256(bytes('CORE_CANONICAL_HUB')),
      'CORE',
      'CANONICAL_HUB',
      address(0),
      coreHub
    );
    provider.setCanonicalHub('CORE', coreHub);
    provider.setCanonicalHub('PLUS', plusHub);
    provider.setCanonicalHub('PRIME', primeHub);
    vm.stopPrank();

    assertEq(provider.getCanonicalHub('CORE'), coreHub);
    assertEq(provider.getCanonicalHub('PLUS'), plusHub);
    assertEq(provider.getCanonicalHub('PRIME'), primeHub);
    assertEq(provider.getAddress(keccak256(bytes('CORE_CANONICAL_HUB'))), coreHub);
    assertEq(provider.getAddressEntry(keccak256(bytes('CORE_CANONICAL_HUB'))).tag, 'CANONICAL_HUB');

    bytes32[] memory hubIds = provider.getIds('CANONICAL_HUB');
    assertEq(hubIds.length, 3);
    assertEq(hubIds[0], keccak256(bytes('CORE_CANONICAL_HUB')));
    assertEq(hubIds[1], keccak256(bytes('PLUS_CANONICAL_HUB')));
    assertEq(hubIds[2], keccak256(bytes('PRIME_CANONICAL_HUB')));

    address[] memory hubs = provider.getCanonicalHubs();
    assertEq(hubs.length, 3);
    assertEq(hubs[0], coreHub);
    assertEq(hubs[1], plusHub);
    assertEq(hubs[2], primeHub);
    assertEq(provider.getAddresses(provider.CANONICAL_HUB_TAG()), hubs);
  }

  function test_setCanonicalHub_removeThenSet() public {
    address coreHub = makeAddr('CORE_HUB');
    address newCoreHub = makeAddr('NEW_CORE_HUB');

    vm.startPrank(OWNER);
    provider.setCanonicalHub('CORE', coreHub);
    provider.setCanonicalHub('CORE', address(0));

    vm.expectEmit(address(provider));
    emit IV4AddressesProvider.AddressSet(
      keccak256(bytes('CORE_CANONICAL_HUB')),
      'CORE',
      'CANONICAL_HUB',
      address(0),
      newCoreHub
    );
    provider.setCanonicalHub('CORE', newCoreHub);
    vm.stopPrank();

    assertEq(provider.getCanonicalHub('CORE'), newCoreHub);
    assertEq(provider.getCanonicalHubs().length, 1);
  }

  function test_setCanonicalHub_revertsWith_AddressAlreadySet() public {
    vm.startPrank(OWNER);
    provider.setCanonicalHub('CORE', makeAddr('CORE_HUB'));

    vm.expectRevert(
      abi.encodeWithSelector(
        IV4AddressesProvider.AddressAlreadySet.selector,
        keccak256(bytes('CORE_CANONICAL_HUB'))
      )
    );
    provider.setCanonicalHub('CORE', makeAddr('NEW_CORE_HUB'));
    vm.stopPrank();
  }

  function test_setCanonicalHub_remove() public {
    vm.startPrank(OWNER);
    provider.setCanonicalHub('CORE', makeAddr('CORE_HUB'));
    provider.setCanonicalHub('PLUS', makeAddr('PLUS_HUB'));
    provider.setCanonicalHub('CORE', address(0));
    vm.stopPrank();

    assertEq(provider.getCanonicalHub('CORE'), address(0));

    address[] memory hubs = provider.getCanonicalHubs();
    assertEq(hubs.length, 1);
    assertEq(hubs[0], provider.getCanonicalHub('PLUS'));
  }

  function test_setCanonicalHub_remove_revertsWith_AddressNotSet() public {
    vm.expectRevert(
      abi.encodeWithSelector(
        IV4AddressesProvider.AddressNotSet.selector,
        keccak256(bytes('CORE_CANONICAL_HUB'))
      )
    );
    vm.prank(OWNER);
    provider.setCanonicalHub('CORE', address(0));
  }

  function test_setCanonicalHub_revertsWith_InvalidName() public {
    vm.expectRevert(IV4AddressesProvider.InvalidName.selector);
    vm.prank(OWNER);
    provider.setCanonicalHub('', makeAddr('CORE_HUB'));
  }

  function test_setCanonicalHub_revertsWith_OwnableUnauthorizedAccount() public {
    address caller = makeAddr('caller');

    vm.expectRevert(
      abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, caller)
    );
    vm.prank(caller);
    provider.setCanonicalHub('CORE', makeAddr('CORE_HUB'));
  }

  function test_setCanonicalHub_fuzz(string memory name, address hub) public {
    vm.assume(bytes(name).length > 0);
    vm.assume(hub != address(0));

    vm.prank(OWNER);
    provider.setCanonicalHub(name, hub);

    assertEq(provider.getCanonicalHub(name), hub);

    address[] memory hubs = provider.getCanonicalHubs();
    assertEq(hubs.length, 1);
    assertEq(hubs[0], hub);
  }

  function test_setCanonicalSpoke() public {
    address mainSpoke = makeAddr('MAIN_SPOKE');
    address bluechipSpoke = makeAddr('BLUECHIP_SPOKE');
    address forexSpoke = makeAddr('FOREX_SPOKE');

    vm.startPrank(OWNER);
    vm.expectEmit(address(provider));
    emit IV4AddressesProvider.AddressSet(
      keccak256(bytes('MAIN_CANONICAL_SPOKE')),
      'MAIN',
      'CANONICAL_SPOKE',
      address(0),
      mainSpoke
    );
    provider.setCanonicalSpoke('MAIN', mainSpoke);
    provider.setCanonicalSpoke('BLUECHIP', bluechipSpoke);
    provider.setCanonicalSpoke('FOREX', forexSpoke);
    vm.stopPrank();

    assertEq(provider.getCanonicalSpoke('MAIN'), mainSpoke);
    assertEq(provider.getCanonicalSpoke('BLUECHIP'), bluechipSpoke);
    assertEq(provider.getCanonicalSpoke('FOREX'), forexSpoke);
    assertEq(provider.getAddress(keccak256(bytes('MAIN_CANONICAL_SPOKE'))), mainSpoke);

    address[] memory canonicalSpokes = provider.getCanonicalSpokes();
    assertEq(canonicalSpokes.length, 3);
    assertEq(canonicalSpokes[0], mainSpoke);
    assertEq(canonicalSpokes[1], bluechipSpoke);
    assertEq(canonicalSpokes[2], forexSpoke);
  }

  function test_setTokenizationSpoke() public {
    address coreWethSpoke = makeAddr('CORE_WETH_TOKENIZATION_SPOKE');
    address primeGhoSpoke = makeAddr('PRIME_GHO_TOKENIZATION_SPOKE');

    vm.startPrank(OWNER);
    provider.setTokenizationSpoke('CORE_WETH', coreWethSpoke);
    provider.setTokenizationSpoke('PRIME_GHO', primeGhoSpoke);
    vm.stopPrank();

    assertEq(provider.getTokenizationSpoke('CORE_WETH'), coreWethSpoke);
    assertEq(provider.getTokenizationSpoke('PRIME_GHO'), primeGhoSpoke);
    assertEq(provider.getAddress(keccak256(bytes('CORE_WETH_TOKENIZATION_SPOKE'))), coreWethSpoke);

    address[] memory tokenizationSpokes = provider.getTokenizationSpokes();
    assertEq(tokenizationSpokes.length, 2);
    assertEq(tokenizationSpokes[0], coreWethSpoke);
    assertEq(tokenizationSpokes[1], primeGhoSpoke);
  }

  function test_setTreasurySpoke() public {
    address treasurySpoke = makeAddr('TREASURY_SPOKE');

    vm.prank(OWNER);
    provider.setTreasurySpoke('MAIN', treasurySpoke);

    assertEq(provider.getTreasurySpoke('MAIN'), treasurySpoke);
    assertEq(provider.getAddress(keccak256(bytes('MAIN_TREASURY_SPOKE'))), treasurySpoke);

    address[] memory treasurySpokes = provider.getTreasurySpokes();
    assertEq(treasurySpokes.length, 1);
    assertEq(treasurySpokes[0], treasurySpoke);
  }

  function test_setSpoke_sameNameAcrossTags() public {
    address mainSpoke = makeAddr('MAIN_SPOKE');
    address treasurySpoke = makeAddr('TREASURY_SPOKE');

    vm.startPrank(OWNER);
    provider.setCanonicalSpoke('MAIN', mainSpoke);
    provider.setTreasurySpoke('MAIN', treasurySpoke);
    vm.stopPrank();

    assertEq(provider.getCanonicalSpoke('MAIN'), mainSpoke);
    assertEq(provider.getTreasurySpoke('MAIN'), treasurySpoke);
  }

  function test_setSpoke_removeThenSet() public {
    address mainSpoke = makeAddr('MAIN_SPOKE');
    address newMainSpoke = makeAddr('NEW_MAIN_SPOKE');

    vm.startPrank(OWNER);
    provider.setCanonicalSpoke('MAIN', mainSpoke);
    provider.setCanonicalSpoke('MAIN', address(0));
    provider.setCanonicalSpoke('MAIN', newMainSpoke);
    vm.stopPrank();

    assertEq(provider.getCanonicalSpoke('MAIN'), newMainSpoke);
    assertEq(provider.getCanonicalSpokes().length, 1);
  }

  function test_setSpoke_revertsWith_AddressAlreadySet() public {
    vm.startPrank(OWNER);
    provider.setCanonicalSpoke('MAIN', makeAddr('MAIN_SPOKE'));

    vm.expectRevert(
      abi.encodeWithSelector(
        IV4AddressesProvider.AddressAlreadySet.selector,
        keccak256(bytes('MAIN_CANONICAL_SPOKE'))
      )
    );
    provider.setCanonicalSpoke('MAIN', makeAddr('NEW_MAIN_SPOKE'));
    vm.stopPrank();
  }

  function test_setSpoke_remove() public {
    vm.startPrank(OWNER);
    provider.setCanonicalSpoke('MAIN', makeAddr('MAIN_SPOKE'));
    provider.setCanonicalSpoke('BLUECHIP', makeAddr('BLUECHIP_SPOKE'));
    provider.setTreasurySpoke('MAIN', makeAddr('TREASURY_SPOKE'));

    provider.setCanonicalSpoke('MAIN', address(0));
    vm.stopPrank();

    assertEq(provider.getCanonicalSpoke('MAIN'), address(0));

    address[] memory canonicalSpokes = provider.getCanonicalSpokes();
    assertEq(canonicalSpokes.length, 1);
    assertEq(canonicalSpokes[0], provider.getCanonicalSpoke('BLUECHIP'));
    assertEq(provider.getTreasurySpokes().length, 1);
  }

  function test_setSpoke_removeLastIdOfTag() public {
    vm.startPrank(OWNER);
    provider.setCanonicalSpoke('MAIN', makeAddr('MAIN_SPOKE'));
    provider.setTreasurySpoke('MAIN', makeAddr('TREASURY_SPOKE'));

    provider.setTreasurySpoke('MAIN', address(0));
    vm.stopPrank();

    assertEq(provider.getTreasurySpokes().length, 0);

    string[] memory tags = provider.getTags();
    assertEq(tags.length, 1);
    assertEq(tags[0], 'CANONICAL_SPOKE');
  }

  function test_setSpoke_remove_revertsWith_AddressNotSet() public {
    vm.expectRevert(
      abi.encodeWithSelector(
        IV4AddressesProvider.AddressNotSet.selector,
        keccak256(bytes('MAIN_CANONICAL_SPOKE'))
      )
    );
    vm.prank(OWNER);
    provider.setCanonicalSpoke('MAIN', address(0));
  }

  function test_setSpoke_revertsWith_InvalidName() public {
    vm.startPrank(OWNER);

    vm.expectRevert(IV4AddressesProvider.InvalidName.selector);
    provider.setCanonicalSpoke('', makeAddr('MAIN_SPOKE'));

    vm.expectRevert(IV4AddressesProvider.InvalidName.selector);
    provider.setTokenizationSpoke('', makeAddr('CORE_WETH_TOKENIZATION_SPOKE'));

    vm.expectRevert(IV4AddressesProvider.InvalidName.selector);
    provider.setTreasurySpoke('', makeAddr('TREASURY_SPOKE'));

    vm.stopPrank();
  }

  function test_setSpoke_revertsWith_OwnableUnauthorizedAccount() public {
    address caller = makeAddr('caller');
    vm.startPrank(caller);

    vm.expectRevert(
      abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, caller)
    );
    provider.setCanonicalSpoke('MAIN', makeAddr('MAIN_SPOKE'));

    vm.expectRevert(
      abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, caller)
    );
    provider.setTokenizationSpoke('CORE_WETH', makeAddr('CORE_WETH_TOKENIZATION_SPOKE'));

    vm.expectRevert(
      abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, caller)
    );
    provider.setTreasurySpoke('MAIN', makeAddr('TREASURY_SPOKE'));

    vm.stopPrank();
  }

  function test_setSpoke_fuzz(string memory name, address spoke) public {
    vm.assume(bytes(name).length > 0);
    vm.assume(spoke != address(0));

    vm.prank(OWNER);
    provider.setCanonicalSpoke(name, spoke);

    assertEq(provider.getCanonicalSpoke(name), spoke);

    address[] memory canonicalSpokes = provider.getCanonicalSpokes();
    assertEq(canonicalSpokes.length, 1);
    assertEq(canonicalSpokes[0], spoke);
  }

  function test_getTags() public {
    vm.startPrank(OWNER);
    provider.setCanonicalHub('CORE', makeAddr('CORE_HUB'));
    provider.setCanonicalSpoke('MAIN', makeAddr('MAIN_SPOKE'));
    provider.setTokenizationSpoke('CORE_WETH', makeAddr('CORE_WETH_TOKENIZATION_SPOKE'));
    provider.setTreasurySpoke('MAIN', makeAddr('TREASURY_SPOKE'));
    vm.stopPrank();

    string[] memory tags = provider.getTags();
    assertEq(tags.length, 4);
    assertEq(tags[0], 'CANONICAL_HUB');
    assertEq(tags[1], 'CANONICAL_SPOKE');
    assertEq(tags[2], 'TOKENIZATION_SPOKE');
    assertEq(tags[3], 'TREASURY_SPOKE');
  }
}
