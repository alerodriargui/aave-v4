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

    function test_replay_1_updateUserRiskPremium() public {
        _setUpActor(USER3);
        Tester.setUsingAsCollateral(true, 1, 26);
        Tester.supply(8548, 251, 14, 14);
        Tester.borrow(716, 227, 46, 18);
        _setUpActor(USER1);
        _delay(483724);
        Tester.updateUserRiskPremium(0);
        // Invalid: 54653460198616960432589820!=5465941435645494nah 5997582564, reason: GPOST_HUB_C: Borrow rate should always match the calculated amount right after any hub non-view operation in the same block
    }

    function test_replay_1_invariant_INV_HUB_E() public {
        _setUpActor(USER1);
        _delay(7335);
        Tester.setUsingAsCollateral(true, 0, 0);
        _delay(33390);
        Tester.supply(203156, 36, 0, 86);
        _delay(895);
        Tester.borrow(736, 0, 0, 38);
        _delay(12354444);
        invariant_INV_HUB(); // Invalid: 203179!=203159, reason: INV_HUB_E: hub.getTotalSuppliedAssets and hub.getAssetSuppliedAmount should match at any time
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
