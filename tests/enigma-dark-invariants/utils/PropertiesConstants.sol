// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

abstract contract PropertiesConstants {
    // Echidna constants
    address constant USER1 = address(0x10000);
    address constant USER2 = address(0x20000);
    address constant USER3 = address(0x30000);
    uint256 constant INITIAL_BALANCE = 1000e30;

    // Suite constants
    uint256 constant CHECK_ALL_RESERVES = type(uint256).max;
    string constant GPOST_CHECK_FAILED = "GPOST_CHECK_FAILED: checkPostConditions reverted";

    // Protocol constants
}
