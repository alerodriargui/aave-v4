// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity 0.8.28;

import {Ownable2StepUpgradeable} from 'src/dependencies/openzeppelin-upgradeable/Ownable2StepUpgradeable.sol';
import {EnumerableSet} from 'src/dependencies/openzeppelin/EnumerableSet.sol';
import {V4AddressesProviderStorage} from 'src/addresses-provider/V4AddressesProviderStorage.sol';
import {IV4AddressesProvider} from 'src/addresses-provider/interfaces/IV4AddressesProvider.sol';

/// @title V4AddressesProvider
/// @author Aave Labs
/// @notice Main registry of Aave V4 contract addresses.
abstract contract V4AddressesProvider is
  V4AddressesProviderStorage,
  Ownable2StepUpgradeable,
  IV4AddressesProvider
{
  using EnumerableSet for *;

  /// @inheritdoc IV4AddressesProvider
  string public constant CANONICAL_HUB_TAG = 'CANONICAL_HUB';

  /// @inheritdoc IV4AddressesProvider
  string public constant CANONICAL_SPOKE_TAG = 'CANONICAL_SPOKE';

  /// @inheritdoc IV4AddressesProvider
  string public constant TOKENIZATION_SPOKE_TAG = 'TOKENIZATION_SPOKE';

  /// @inheritdoc IV4AddressesProvider
  string public constant TREASURY_SPOKE_TAG = 'TREASURY_SPOKE';

  /// @dev To be overridden by the inheriting V4AddressesProvider instance contract.
  function initialize(address owner) external virtual;

  /// @inheritdoc IV4AddressesProvider
  function setAddress(
    string memory name,
    string memory tag,
    address newAddress
  ) external onlyOwner {
    _setAddress({name: name, tag: tag, newAddress: newAddress});
  }

  /// @inheritdoc IV4AddressesProvider
  function setCanonicalHub(string memory name, address hub) external onlyOwner {
    _setAddress({name: name, tag: CANONICAL_HUB_TAG, newAddress: hub});
  }

  /// @inheritdoc IV4AddressesProvider
  function setCanonicalSpoke(string memory name, address spoke) external onlyOwner {
    _setAddress({name: name, tag: CANONICAL_SPOKE_TAG, newAddress: spoke});
  }

  /// @inheritdoc IV4AddressesProvider
  function setTokenizationSpoke(string memory name, address spoke) external onlyOwner {
    _setAddress({name: name, tag: TOKENIZATION_SPOKE_TAG, newAddress: spoke});
  }

  /// @inheritdoc IV4AddressesProvider
  function setTreasurySpoke(string memory name, address spoke) external onlyOwner {
    _setAddress({name: name, tag: TREASURY_SPOKE_TAG, newAddress: spoke});
  }

  /// @inheritdoc IV4AddressesProvider
  function getAddressEntry(bytes32 id) external view returns (AddressEntry memory) {
    return _addressEntries[id];
  }

  /// @inheritdoc IV4AddressesProvider
  function getIds(string memory tag) external view returns (bytes32[] memory) {
    return _taggedIds[tag].values();
  }

  /// @inheritdoc IV4AddressesProvider
  function getTags() external view returns (string[] memory) {
    return _tags.values();
  }

  /// @inheritdoc IV4AddressesProvider
  function getCanonicalHub(string memory name) external view returns (address) {
    return getAddress({name: name, tag: CANONICAL_HUB_TAG});
  }

  /// @inheritdoc IV4AddressesProvider
  function getCanonicalHubs() external view returns (address[] memory) {
    return getAddresses(CANONICAL_HUB_TAG);
  }

  /// @inheritdoc IV4AddressesProvider
  function getCanonicalSpoke(string memory name) external view returns (address) {
    return getAddress({name: name, tag: CANONICAL_SPOKE_TAG});
  }

  /// @inheritdoc IV4AddressesProvider
  function getCanonicalSpokes() external view returns (address[] memory) {
    return getAddresses(CANONICAL_SPOKE_TAG);
  }

  /// @inheritdoc IV4AddressesProvider
  function getTokenizationSpoke(string memory name) external view returns (address) {
    return getAddress({name: name, tag: TOKENIZATION_SPOKE_TAG});
  }

  /// @inheritdoc IV4AddressesProvider
  function getTokenizationSpokes() external view returns (address[] memory) {
    return getAddresses(TOKENIZATION_SPOKE_TAG);
  }

  /// @inheritdoc IV4AddressesProvider
  function getTreasurySpoke(string memory name) external view returns (address) {
    return getAddress({name: name, tag: TREASURY_SPOKE_TAG});
  }

  /// @inheritdoc IV4AddressesProvider
  function getTreasurySpokes() external view returns (address[] memory) {
    return getAddresses(TREASURY_SPOKE_TAG);
  }

  /// @inheritdoc IV4AddressesProvider
  function getAddress(bytes32 id) public view returns (address) {
    return _addressEntries[id].addr;
  }

  /// @inheritdoc IV4AddressesProvider
  function getAddress(string memory name, string memory tag) public view returns (address) {
    return getAddress(getId({name: name, tag: tag}));
  }

  /// @inheritdoc IV4AddressesProvider
  function getAddresses(string memory tag) public view returns (address[] memory) {
    bytes32[] memory ids = _taggedIds[tag].values();
    address[] memory addresses = new address[](ids.length);
    for (uint256 i = 0; i < ids.length; i++) {
      addresses[i] = _addressEntries[ids[i]].addr;
    }
    return addresses;
  }

  /// @inheritdoc IV4AddressesProvider
  function getId(string memory name, string memory tag) public pure returns (bytes32) {
    return keccak256(bytes(string.concat(name, '_', tag)));
  }

  function _setAddress(string memory name, string memory tag, address newAddress) internal {
    require(bytes(name).length > 0, InvalidName());
    require(bytes(tag).length > 0, InvalidTag());

    bytes32 id = getId({name: name, tag: tag});
    AddressEntry memory oldEntry = _addressEntries[id];

    if (newAddress == address(0)) {
      require(oldEntry.addr != address(0), AddressNotSet(id));
      _taggedIds[oldEntry.tag].remove(id);
      if (_taggedIds[oldEntry.tag].length() == 0) {
        _tags.remove(oldEntry.tag);
      }
      delete _addressEntries[id];
    } else {
      require(oldEntry.addr == address(0), AddressAlreadySet(id));
      _addressEntries[id] = AddressEntry({addr: newAddress, tag: tag});
      _taggedIds[tag].add(id);
      _tags.add(tag);
    }

    emit AddressSet(id, name, tag, oldEntry.addr, newAddress);
  }
}
