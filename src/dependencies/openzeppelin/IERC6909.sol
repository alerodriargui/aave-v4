// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts (last updated v5.5.0) (token/ERC6909/IERC6909.sol)
pragma solidity ^0.8.20;

/// @title IERC6909
/// @notice Interface for the ERC6909 multi-token standard
/// @dev See https://eips.ethereum.org/EIPS/eip-6909
interface IERC6909 {
  /// @notice Emitted when tokens are transferred, including zero value transfers
  /// @param caller The address that initiated the transfer
  /// @param from The address tokens are transferred from
  /// @param to The address tokens are transferred to
  /// @param id The token identifier
  /// @param amount The amount of tokens transferred
  event Transfer(
    address indexed caller,
    address indexed from,
    address indexed to,
    uint256 id,
    uint256 amount
  );

  /// @notice Emitted when an operator is set or unset
  /// @param owner The address that owns the tokens
  /// @param operator The address that is allowed to operate on the tokens
  /// @param approved True if the operator is approved, false otherwise
  event OperatorSet(address indexed owner, address indexed operator, bool approved);

  /// @notice Emitted when the allowance of a spender is set or changed
  /// @param owner The address that owns the tokens
  /// @param spender The address that is allowed to spend the tokens
  /// @param id The token identifier
  /// @param amount The amount of tokens the spender is allowed to spend
  event Approval(address indexed owner, address indexed spender, uint256 id, uint256 amount);

  /// @notice Returns the balance of tokens for a given owner and token id
  /// @param owner The address that owns the tokens
  /// @param id The token identifier
  /// @return The balance of tokens
  function balanceOf(address owner, uint256 id) external view returns (uint256);

  /// @notice Returns the allowance of a spender for a given owner and token id
  /// @param owner The address that owns the tokens
  /// @param spender The address that is allowed to spend the tokens
  /// @param id The token identifier
  /// @return The amount of tokens the spender is allowed to spend
  function allowance(address owner, address spender, uint256 id) external view returns (uint256);

  /// @notice Returns whether an operator is approved for all tokens of an owner
  /// @param owner The address that owns the tokens
  /// @param operator The address that is allowed to operate on the tokens
  /// @return True if the operator is approved, false otherwise
  function isOperator(address owner, address operator) external view returns (bool);

  /// @notice Transfers tokens from the caller to another address
  /// @param to The address to transfer tokens to
  /// @param id The token identifier
  /// @param amount The amount of tokens to transfer
  /// @return True if the transfer was successful
  function transfer(address to, uint256 id, uint256 amount) external returns (bool);

  /// @notice Transfers tokens from one address to another
  /// @param from The address to transfer tokens from
  /// @param to The address to transfer tokens to
  /// @param id The token identifier
  /// @param amount The amount of tokens to transfer
  /// @return True if the transfer was successful
  function transferFrom(
    address from,
    address to,
    uint256 id,
    uint256 amount
  ) external returns (bool);

  /// @notice Approves a spender to spend a specific amount of tokens
  /// @param spender The address that is allowed to spend the tokens
  /// @param id The token identifier
  /// @param amount The amount of tokens the spender is allowed to spend
  /// @return True if the approval was successful
  function approve(address spender, uint256 id, uint256 amount) external returns (bool);

  /// @notice Sets or unsets an operator for the caller
  /// @param operator The address that is allowed to operate on the tokens
  /// @param approved True to approve the operator, false to revoke approval
  /// @return True if the operation was successful
  function setOperator(address operator, bool approved) external returns (bool);

  /// @notice Returns whether this contract implements a given interface
  /// @param interfaceId The interface identifier
  /// @return True if the interface is supported
  function supportsInterface(bytes4 interfaceId) external view returns (bool);
}
