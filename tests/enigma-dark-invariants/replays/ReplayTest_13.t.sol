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

contract ReplayTest13 is Invariants, Setup {
    // Generated from Echidna reproducers

    // Target contract instance (you may need to adjust this)
    ReplayTest13 Tester = this;

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

    function test_replay_13_setUsingAsCollateral() public {
        _setUpActor(USER2);
        Tester.setUsingAsCollateral(true, 167, 2);
        Tester.supply(230, 1, 1, 2);
        Tester.borrow(103, 7, 23, 0);
        _setUpActor(USER1);
        _delay(1441);
        Tester.setUsingAsCollateral(false, 0, 0);
        // GPOST_HUB_C: Borrow rate should always match the calculated amount right after any hub non-view operation in the same block.
    }

    function test_replay_13_updateUserRiskPremium() public {
        _setUpActor(USER2);
        Tester.supply(3650894, 46, 43, 2);
        Tester.setUsingAsCollateral(true, 13, 4);
        Tester.borrow(7, 100, 5, 0);
        _setUpActor(USER1);
        _delay(1);
        Tester.updateUserRiskPremium(0);
        // Invalid: 50000106518811252501137774!=50000121735750944479215219, reason: GPOST_HUB_C: Borrow rate should always match the calculated amount right after any hub non-view operation in the same block.
    }

    function test_replay_13_liquidationCall() public {
        _setUpActor(USER3);
        Tester.setUsingAsCollateral(true, 172, 50);
        Tester.supply(10092, 251, 30, 128);
        Tester.borrow(7800, 227, 62, 25);
        _setUpActor(USER1);
        _delay(1425689);
        _delay(314372);
        Tester.setPrice(0, 0);
        _delay(344203);
        Tester.setPrice(188046916927661423584726156556474354281793089627848617698006899495150566800, 73);
        Tester.liquidationCall(
            16786243780545468416195016839226359136549161709334054148083726855218179176262, false, 197, 130, 42, 58
        );
        // Invalid: 16786243780545468416195016839226359136549161709334054148083726855218179176262>=7871 failed, reason: HSPOST_SP_LIQ_A: Liquidation cannot result in an amount of liquidated debt > user's total debt position
    }

    function test_replay_13_supply() public {
        _setUpActor(USER3);
        Tester.setUsingAsCollateral(true, 198, 50);
        Tester.supply(10092, 251, 16, 135);
        Tester.borrow(5584, 17, 18, 5);
        _setUpActor(USER1);
        _delay(100171);
        Tester.supply(4303, 72, 0, 28);
        // Invalid: 1000277893566763929<1000297265160523186 failed, reason: GPOST_HUB_B: Add exchange rate (total assets / total shares) cannot decrease (remains constant or increases). If no time passes, it stays constant. it increases due to interest accumulation, premium debt settlement and donations (from actions' rounding).
    }

    function test_replay_13_updateUserDynamicConfig() public {
        _setUpActor(USER2);
        Tester.supply(25427, 37, 13, 9);
        Tester.setUsingAsCollateral(true, 1, 4);
        Tester.borrow(1, 1, 183, 0);
        _setUpActor(USER1);
        _delay(3741);
        Tester.updateUserDynamicConfig(0);
        // Invalid: 50002184904060862687519392!=50004369636271476762274309, reason: GPOST_HUB_C: Borrow rate should always match the calculated amount right after any hub non-view operation in the same block.
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
