// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {IAccessManager} from 'src/dependencies/openzeppelin/IAccessManager.sol';

contract MockAccessManager is IAccessManager {
  mapping(bytes4 => bool) public shouldRevert;

  event GrantRoleCalled(uint64 roleId, address account, uint32 executionDelay);
  event RevokeRoleCalled(uint64 roleId, address account);
  event SetRoleAdminCalled(uint64 roleId, uint64 admin);
  event SetRoleGuardianCalled(uint64 roleId, uint64 guardian);
  event SetTargetFunctionRoleCalled(address target, bytes4[] selectors, uint64 roleId);
  event SetTargetClosedCalled(address target, bool closed);
  event LabelRoleCalled(uint64 roleId, string label);
  event SetGrantDelayCalled(uint64 roleId, uint32 newDelay);
  event SetTargetAdminDelayCalled(address target, uint32 newDelay);

  error GrantRoleReverted();
  error RevokeRoleReverted();
  error SetRoleAdminReverted();
  error SetRoleGuardianReverted();
  error SetTargetFunctionRoleReverted();
  error SetTargetClosedReverted();
  error LabelRoleReverted();
  error SetGrantDelayReverted();
  error SetTargetAdminDelayReverted();

  function setShouldRevert(bytes4 selector, bool revert_) external {
    shouldRevert[selector] = revert_;
  }

  function grantRole(uint64 roleId, address account, uint32 executionDelay) external {
    if (shouldRevert[msg.sig]) revert GrantRoleReverted();
    emit GrantRoleCalled(roleId, account, executionDelay);
  }

  function revokeRole(uint64 roleId, address account) external {
    if (shouldRevert[msg.sig]) revert RevokeRoleReverted();
    emit RevokeRoleCalled(roleId, account);
  }

  function setRoleAdmin(uint64 roleId, uint64 admin) external {
    if (shouldRevert[msg.sig]) revert SetRoleAdminReverted();
    emit SetRoleAdminCalled(roleId, admin);
  }

  function setRoleGuardian(uint64 roleId, uint64 guardian) external {
    if (shouldRevert[msg.sig]) revert SetRoleGuardianReverted();
    emit SetRoleGuardianCalled(roleId, guardian);
  }

  function setTargetFunctionRole(
    address target,
    bytes4[] calldata selectors,
    uint64 roleId
  ) external {
    if (shouldRevert[msg.sig]) revert SetTargetFunctionRoleReverted();
    emit SetTargetFunctionRoleCalled(target, selectors, roleId);
  }

  function setTargetClosed(address target, bool closed) external {
    if (shouldRevert[msg.sig]) revert SetTargetClosedReverted();
    emit SetTargetClosedCalled(target, closed);
  }

  function labelRole(uint64 roleId, string calldata label) external {
    if (shouldRevert[msg.sig]) revert LabelRoleReverted();
    emit LabelRoleCalled(roleId, label);
  }

  function setGrantDelay(uint64 roleId, uint32 newDelay) external {
    if (shouldRevert[msg.sig]) revert SetGrantDelayReverted();
    emit SetGrantDelayCalled(roleId, newDelay);
  }

  function setTargetAdminDelay(address target, uint32 newDelay) external {
    if (shouldRevert[msg.sig]) revert SetTargetAdminDelayReverted();
    emit SetTargetAdminDelayCalled(target, newDelay);
  }

  function canCall(address, address, bytes4) external pure returns (bool, uint32) {
    return (false, 0);
  }

  function expiration() external pure returns (uint32) {
    return 0;
  }

  function minSetback() external pure returns (uint32) {
    return 0;
  }

  function isTargetClosed(address) external pure returns (bool) {
    return false;
  }

  function getTargetFunctionRole(address, bytes4) external pure returns (uint64) {
    return 0;
  }

  function getTargetAdminDelay(address) external pure returns (uint32) {
    return 0;
  }

  function getRoleAdmin(uint64) external pure returns (uint64) {
    return 0;
  }

  function getRoleGuardian(uint64) external pure returns (uint64) {
    return 0;
  }

  function getRoleGrantDelay(uint64) external pure returns (uint32) {
    return 0;
  }

  function getAccess(uint64, address) external pure returns (uint48, uint32, uint32, uint48) {
    return (0, 0, 0, 0);
  }

  function hasRole(uint64, address) external pure returns (bool, uint32) {
    return (false, 0);
  }

  function renounceRole(uint64, address) external {}

  function getSchedule(bytes32) external pure returns (uint48) {
    return 0;
  }

  function getNonce(bytes32) external pure returns (uint32) {
    return 0;
  }

  function schedule(address, bytes calldata, uint48) external pure returns (bytes32, uint32) {
    return (bytes32(0), 0);
  }

  function execute(address, bytes calldata) external payable returns (uint32) {
    return 0;
  }

  function cancel(address, address, bytes calldata) external pure returns (uint32) {
    return 0;
  }

  function consumeScheduledOp(address, bytes calldata) external {}

  function hashOperation(address, address, bytes calldata) external pure returns (bytes32) {
    return bytes32(0);
  }

  function updateAuthority(address, address) external {}
}
