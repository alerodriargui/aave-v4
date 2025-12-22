// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {HubInvariants} from "./invariants/HubInvariants.t.sol";
import {Setup} from "./Setup.t.sol";

/// @title Tester
/// @notice Entry point for hub invariant testing
contract Tester is HubInvariants, Setup {
    constructor() payable {
        setUp();
    }

    function setUp() internal {
        _setUp();
    }
}
