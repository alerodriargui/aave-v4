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

contract ReplayTest7 is Invariants, Setup {
    // Generated from Echidna reproducers

    // Target contract instance (you may need to adjust this)
    ReplayTest7 Tester = this;

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

    function test_replay_7_withdraw() public {
        _setUpActor(USER3);
        Tester.supply(10070862, 2, 0, 0);
        Tester.withdraw(63970967942622104945159534037176262183333096787346814336171336533994484054, 32, 4, 2);
        // GPOST_HUB_B: Add exchange rate (total assets / total shares) cannot decrease (remains constant or increases). If no time passes, it stays constant. it increases due to interest accumulation, premium debt settlement and donations (from actions' rounding).
    }

    function test_replay_7_transfer() public {
        _setUpActor(USER1);
        Tester.supply(2, 0, 0, 0);
        Tester.setUsingAsCollateral(true, 0, 0);
        Tester.borrow(1, 0, 0, 0);
        _delay(1);
        Tester.transfer(0, 0, 0, 0);
        // Invalid: 77777777777777777777777778!=87037037037037037037037038, reason: GPOST_HUB_C: Borrow rate should always match the calculated amount right after any hub non-view operation in the same block
    }

    function test_replay_7_liquidationCall() public {
        _setUpActor(USER3);
        Tester.setUsingAsCollateral(true, 172, 50);
        Tester.supply(10092, 251, 48, 141);
        Tester.borrow(7800, 227, 62, 25);
        _setUpActor(USER1);
        _delay(2711741);
        Tester.setPrice(929774615256615712219717710056, 0);
        Tester.liquidationCall(8492579161489, 203, 220, 184, 37);
        // Invalid: 8492579161489>=7790 failed, reason: HSPOST_SP_LIQ_A: Liquidation cannot result in an amount of liquidated debt > user's total debt position
    }

    function test_replay_7_updateUserDynamicConfig() public {
        _setUpActor(USER2);
        Tester.setUsingAsCollateral(true, 1, 7);
        Tester.supply(718, 1, 1, 0);
        Tester.borrow(4, 1, 1, 0);
        _setUpActor(USER1);
        _delay(990809);
        Tester.updateUserDynamicConfig(0);
        // 50309501702259362426493347!=50386339051151290372430846, reason: GPOST_HUB_C: Borrow rate should always match the calculated amount right after any hub non-view operation in the same block
    }

    function test_replay_7_setUsingAsCollateral() public {
        _setUpActor(USER2);
        Tester.setUsingAsCollateral(true, 1, 4);
        Tester.supply(597, 4, 15, 0);
        Tester.borrow(14, 4, 11, 0);
        _setUpActor(USER1);
        _delay(35069);
        Tester.setUsingAsCollateral(false, 0, 0);
        // Invalid: 51302810348036478689745023!=51393534002229654403567448, reason: GPOST_HUB_C: Borrow rate should always match the calculated amount right after any hub non-view operation in the same block
    }

    function test_replay_7_updateUserRiskPremium() public {
        _setUpActor(USER2);
        Tester.setUsingAsCollateral(true, 105, 11);
        Tester.supply(4143760, 10, 13, 2);
        Tester.borrow(7, 13, 67, 3);
        _setUpActor(USER1);
        _delay(322348);
        Tester.updateUserRiskPremium(0);
        // Invalid: 50000093849279130279960445!=50000107256293122225061834, reason: GPOST_HUB_C: Borrow rate should always match the calculated amount right after any hub non-view operation in the same block
    }

    function test_replay_7_supply() public {
        _setUpActor(USER3);
        Tester.setUsingAsCollateral(true, 198, 4);
        _delay(655);
        Tester.supply(10092, 92, 54, 223);
        Tester.borrow(4418, 227, 62, 51);
        _setUpActor(USER1);
        _delay(116902);
        Tester.supply(4439446668599936570, 21, 0, 45);
        // Invalid: 1000002970026492637<1000297265160523186 failed, reason: GPOST_HUB_B: Add exchange rate (total assets / total shares) cannot decrease (remains constant or increases). If no time passes, it stays constant. it increases due to interest accumulation, premium debt settlement and donations (from actions' rounding)
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
