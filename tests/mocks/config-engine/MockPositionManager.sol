// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

contract MockPositionManager {
  mapping(bytes4 => bool) public shouldRevert;

  event RegisterSpokeCalled(address spoke, bool registered);
  event RescueTokenCalled(address token, address to, uint256 amount);
  event RescueNativeCalled(address to, uint256 amount);
  event RenouncePositionManagerRoleCalled(address spoke, address user);

  error RegisterSpokeReverted();
  error RescueTokenReverted();
  error RescueNativeReverted();
  error RenouncePositionManagerRoleReverted();

  function setShouldRevert(bytes4 selector, bool revert_) external {
    shouldRevert[selector] = revert_;
  }

  function registerSpoke(address spoke, bool registered) external {
    if (shouldRevert[msg.sig]) revert RegisterSpokeReverted();
    emit RegisterSpokeCalled(spoke, registered);
  }

  function rescueToken(address token, address to, uint256 amount) external {
    if (shouldRevert[msg.sig]) revert RescueTokenReverted();
    emit RescueTokenCalled(token, to, amount);
  }

  function rescueNative(address to, uint256 amount) external {
    if (shouldRevert[msg.sig]) revert RescueNativeReverted();
    emit RescueNativeCalled(to, amount);
  }

  function renouncePositionManagerRole(address spoke, address user) external {
    if (shouldRevert[msg.sig]) revert RenouncePositionManagerRoleReverted();
    emit RenouncePositionManagerRoleCalled(spoke, user);
  }
}
