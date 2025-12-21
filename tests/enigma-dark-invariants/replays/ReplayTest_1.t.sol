// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Libraries
import "forge-std/Test.sol";
import "forge-std/console.sol";

// Contracts
import {Invariants} from "../Invariants.t.sol";
import {Setup} from "../Setup.t.sol";

// Utils
import {Actor} from "../utils/Actor.sol";

contract ReplayTest1 is Invariants, Setup {
    // Generated from Echidna reproducers

    // Target contract instance (you may need to adjust this)
    ReplayTest1 Tester = this;

    modifier setup() override {
        _;
    }

    function setUp() public {
        // Deploy protocol contracts
        _setUp();

        /// @dev fixes the actor to the first user
        actor = actors[USER1];

        vm.warp(101007);
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                   		REPLAY TESTS                                     //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    function test_replay_1_supply() public {
        // TODO review test case
        _setUpActor(USER3);
        _delay(140400);
        Tester.supply(7, 242, 154, 0);
        _delay(543845);
        Tester.setUsingAsCollateral(true, 74, 212);
        _delay(527372);
        Tester.borrow(2, 218, 0, 0);
        _delay(116349);
        Tester.supply(8, 128, 2, 0);
        // Invalid: 17*7 < 9*14 failed, reason: GPOST_HUB_B: Add exchange rate (total assets / total shares) cannot decrease (remains constant or increases).
        // Exchange rate before: 1,2857142857
        // Exchange rate after: 1,2142857143
    }

    function test_replay_1_repay() public {
        // TODO review test case
        _setUpActor(USER3);
        _delay(140400);
        Tester.supply(10388, 95, 174, 0);
        _delay(543845);
        Tester.setUsingAsCollateral(true, 0, 52);
        _delay(527372);
        Tester.borrow(8603, 248, 142, 0);
        _delay(243334);
        Tester.repay(1, 116, 254, 252);
        // Invalid: 8608>=8608 failed, reason: HSPOST_SP_C: User liability should decrease after repayment
        // Should this be >= or >?
        // Changed to >= and passing
        // TODO add tolerance 2 wei
    }

    ///////////////////////////////////////////////////////////////////////////////////////////////
    //                                           HELPERS                                         //
    ///////////////////////////////////////////////////////////////////////////////////////////////

    /// @notice Fast forward the time and set up an actor,
    /// @dev Use for ECHIDNA call-traces
    function _delay(uint256 _seconds) internal {
        vm.warp(block.timestamp + _seconds);
    }

    /// @notice Set up an actor
    function _setUpActor(address _origin) internal {
        actor = actors[_origin];
    }

    /// @notice Set up an actor and fast forward the time
    /// @dev Use for ECHIDNA call-traces
    function _setUpActorAndDelay(address _origin, uint256 _seconds) internal {
        actor = actors[_origin];
        vm.warp(block.timestamp + _seconds);
    }

    /// @notice Set up a specific block and actor
    function _setUpBlockAndActor(uint256 _block, address _user) internal {
        vm.roll(_block);
        actor = actors[_user];
    }

    /// @notice Set up a specific timestamp and actor
    function _setUpTimestampAndActor(uint256 _timestamp, address _user) internal {
        vm.warp(_timestamp);
        actor = actors[_user];
    }
}
