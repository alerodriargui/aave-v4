// SPDX-License-Identifier: LicenseRef-BUSL
pragma solidity ^0.8.0;

/// @title IV4AddressesProvider
/// @author Aave Labs
/// @notice Main registry of the Hub and Spoke addresses of an Aave V4 instance.
interface IV4AddressesProvider {
  /// @notice Address entry registered under an identifier.
  /// @param addr The registered address.
  /// @param tag The tag grouping the entry.
  struct AddressEntry {
    address addr;
    string tag;
  }

  /// @notice Emitted when the address associated with a name and tag is updated.
  /// @param id The identifier of the entry.
  /// @param name The name of the entry.
  /// @param tag The tag grouping the entry.
  /// @param oldAddress The previous address of the entry.
  /// @param newAddress The new address of the entry.
  event AddressSet(
    bytes32 indexed id,
    string name,
    string tag,
    address indexed oldAddress,
    address indexed newAddress
  );

  /// @notice Thrown when an empty tag is supplied.
  error InvalidTag();

  /// @notice Thrown when an empty name is supplied.
  error InvalidName();

  /// @notice Thrown when an address is already registered under the identifier.
  error AddressAlreadySet(bytes32 id);

  /// @notice Thrown when no address is registered under the identifier.
  error AddressNotSet(bytes32 id);

  /// @notice Returns the tag grouping all canonical Hubs.
  function CANONICAL_HUB_TAG() external view returns (string memory);

  /// @notice Returns the tag grouping all canonical Spokes.
  function CANONICAL_SPOKE_TAG() external view returns (string memory);

  /// @notice Returns the tag grouping all tokenization Spokes.
  function TOKENIZATION_SPOKE_TAG() external view returns (string memory);

  /// @notice Returns the tag grouping all treasury Spokes.
  function TREASURY_SPOKE_TAG() external view returns (string memory);

  /// @notice Associates an address with a name, grouped under a tag.
  /// @dev Associating the zero address removes the entry and its identifier from enumeration, it reverts if no address is registered.
  /// @dev Reverts if an address is already registered under the identifier, it must be removed first.
  /// @param name The name of the entry.
  /// @param tag The tag grouping the entry.
  /// @param newAddress The address to associate with the name and tag.
  function setAddress(string memory name, string memory tag, address newAddress) external;

  /// @notice Registers the canonical Hub associated with a name.
  /// @dev Registering the zero address removes the entry and its identifier from enumeration, it reverts if no address is registered.
  /// @dev Reverts if an address is already registered under the identifier, it must be removed first.
  /// @param name The name of the Hub.
  /// @param hub The address of the Hub.
  function setCanonicalHub(string memory name, address hub) external;

  /// @notice Registers the canonical Spoke associated with a name.
  /// @dev Registering the zero address removes the entry and its identifier from enumeration, it reverts if no address is registered.
  /// @dev Reverts if an address is already registered under the identifier, it must be removed first.
  /// @param name The name of the Spoke.
  /// @param spoke The address of the Spoke.
  function setCanonicalSpoke(string memory name, address spoke) external;

  /// @notice Registers the tokenization Spoke associated with a name.
  /// @dev Registering the zero address removes the entry and its identifier from enumeration, it reverts if no address is registered.
  /// @dev Reverts if an address is already registered under the identifier, it must be removed first.
  /// @param name The name of the Spoke.
  /// @param spoke The address of the Spoke.
  function setTokenizationSpoke(string memory name, address spoke) external;

  /// @notice Registers the treasury Spoke associated with a name.
  /// @dev Registering the zero address removes the entry and its identifier from enumeration, it reverts if no address is registered.
  /// @dev Reverts if an address is already registered under the identifier, it must be removed first.
  /// @param name The name of the Spoke.
  /// @param spoke The address of the Spoke.
  function setTreasurySpoke(string memory name, address spoke) external;

  /// @notice Returns the address associated with an identifier.
  /// @param id The identifier of the entry.
  /// @return The address of the entry, the zero address if none is registered.
  function getAddress(bytes32 id) external view returns (address);

  /// @notice Returns the address associated with a name and tag.
  /// @param name The name of the entry.
  /// @param tag The tag grouping the entry.
  /// @return The address of the entry, the zero address if none is registered.
  function getAddress(string memory name, string memory tag) external view returns (address);

  /// @notice Returns the address entry associated with an identifier.
  /// @param id The identifier of the entry.
  /// @return The address entry associated with the identifier.
  function getAddressEntry(bytes32 id) external view returns (AddressEntry memory);

  /// @notice Returns the identifiers of all entries grouped under a tag.
  /// @param tag The tag grouping the entries.
  /// @return The list of identifiers.
  function getIds(string memory tag) external view returns (bytes32[] memory);

  /// @notice Returns the addresses of all entries grouped under a tag.
  /// @param tag The tag grouping the entries.
  /// @return The list of addresses.
  function getAddresses(string memory tag) external view returns (address[] memory);

  /// @notice Returns all tags with at least one registered entry.
  /// @return The list of tags.
  function getTags() external view returns (string[] memory);

  /// @notice Returns the canonical Hub associated with a name.
  /// @param name The name of the Hub.
  /// @return The address of the Hub, the zero address if none is registered.
  function getCanonicalHub(string memory name) external view returns (address);

  /// @notice Returns the addresses of all registered canonical Hubs.
  /// @return The list of canonical Hub addresses.
  function getCanonicalHubs() external view returns (address[] memory);

  /// @notice Returns the canonical Spoke associated with a name.
  /// @param name The name of the Spoke.
  /// @return The address of the Spoke, the zero address if none is registered.
  function getCanonicalSpoke(string memory name) external view returns (address);

  /// @notice Returns the addresses of all registered canonical Spokes.
  /// @return The list of canonical Spoke addresses.
  function getCanonicalSpokes() external view returns (address[] memory);

  /// @notice Returns the tokenization Spoke associated with a name.
  /// @param name The name of the Spoke.
  /// @return The address of the Spoke, the zero address if none is registered.
  function getTokenizationSpoke(string memory name) external view returns (address);

  /// @notice Returns the addresses of all registered tokenization Spokes.
  /// @return The list of tokenization Spoke addresses.
  function getTokenizationSpokes() external view returns (address[] memory);

  /// @notice Returns the treasury Spoke associated with a name.
  /// @param name The name of the Spoke.
  /// @return The address of the Spoke, the zero address if none is registered.
  function getTreasurySpoke(string memory name) external view returns (address);

  /// @notice Returns the addresses of all registered treasury Spokes.
  /// @return The list of treasury Spoke addresses.
  function getTreasurySpokes() external view returns (address[] memory);

  /// @notice Returns the identifier of the entry associated with a name and tag.
  /// @dev The identifier is the hash of `<name>_<tag>` (e.g. `CORE_CANONICAL_HUB`).
  /// @param name The name of the entry.
  /// @param tag The tag grouping the entry.
  /// @return The identifier of the entry.
  function getId(string memory name, string memory tag) external pure returns (bytes32);
}
