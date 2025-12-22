// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

abstract contract PropertiesConstants {
    // Echidna constants
    address constant USER1 = address(0x10000);
    address constant USER2 = address(0x20000);
    address constant USER3 = address(0x30000);
    uint256 constant INITIAL_BALANCE = 1e12;

    // Suite constants
    uint256 constant CHECK_ALL_RESERVES = type(uint256).max;
    string constant GPOST_CHECK_FAILED = "GPOST_CHECK_FAILED: checkPostConditions reverted";
    int256 constant PRICE_MIN = 0.0001e8;
    int256 constant PRICE_MAX = 1e14;

    // Protocol constants
    uint256 constant SPOKE_COUNT = 3;
    uint40 constant MAX_ALLOWED_SPOKE_CAP = type(uint40).max;

    // Interest rate 1 data
    uint16 constant OPTIMAL_USAGE_RATIO_IR1 = 85_00; // 85.00%
    uint16 constant BASE_VARIABLE_BORROW_RATE_IR1 = 1_00; // 1.00%
    uint16 constant VARIABLE_RATE_SLOPE_1_IR1 = 4_00; // 4.00%
    uint16 constant VARIABLE_RATE_SLOPE_2_IR1 = 55_00; // 55.00%

    // Interest rate 2 data
    uint16 constant OPTIMAL_USAGE_RATIO_IR2 = 65_00; // 65.00%
    uint16 constant BASE_VARIABLE_BORROW_RATE_IR2 = 2_00; // 2.00%
    uint16 constant VARIABLE_RATE_SLOPE_1_IR2 = 7_00; // 7.00%
    uint16 constant VARIABLE_RATE_SLOPE_2_IR2 = 75_00; // 75.00%

    // Spoke 1 liquidation config
    uint128 constant TARGET_HEALTH_FACTOR_SPOKE1 = 1.05e18;

    // Spoke 2 liquidation config
    uint128 constant TARGET_HEALTH_FACTOR_SPOKE2 = 1.02e18;
}
