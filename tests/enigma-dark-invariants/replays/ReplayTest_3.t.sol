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

contract ReplayTest3 is Invariants, Setup {
    // Generated from Echidna reproducers

    // Target contract instance (you may need to adjust this)
    ReplayTest3 Tester = this;

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

    function test_replay_supply_5() public {
        _setUpActor(USER1);
        _delay(586107);
        Tester.setUsingAsCollateral(true, 154, 0);
        _delay(296474);
        Tester.supply(149948, 15, 0, 0);
        _delay(360624);
        Tester.borrow(17, 0, 0, 73);
        _setUpActor(USER2);
        _delay(360465);
        Tester.supply(1455122803355410, 7, 0, 0);
    }

    function test_replay_liquidationCall_11() public {
        _setUpActor(USER1);
        _delay(228361);
        Tester.setUsingAsCollateral(true, 0, 61);
        _delay(296474);
        Tester.supply(9, 171, 0, 6);
        _delay(360624);
        Tester.borrow(1, 0, 0, 5);
        _delay(101782);
        Tester.withdraw(1, 3, 140, 47);
        _delay(328981);
        Tester.updateUserRiskPremium(44);
        _delay(282613);
        Tester.updateUserRiskPremium(174);
        _delay(364130);
        Tester.updateUserRiskPremium(144);
        _setUpActor(USER2);
        _delay(413227);
        Tester.liquidationCall(
            365099547169460107260444213992413627501745220129685401309505294672367581748, false, 0, 246, 3, 5
        );
    }

    function test_replay_updateUserDynamicConfig_7() public {
        _setUpActor(USER1);
        _delay(228361);
        Tester.setUsingAsCollateral(true, 0, 2);
        _delay(296474);
        Tester.supply(95249040, 21, 0, 6);
        _delay(360624);
        Tester.borrow(2918, 0, 0, 0);
        _setUpActor(USER2);
        _delay(282613);
        Tester.updateUserDynamicConfig(0);
    }

    function test_replay_repay_10() public {
        _setUpActor(USER1);
        _delay(228361);
        Tester.setUsingAsCollateral(true, 0, 101);
        _delay(296474);
        Tester.supply(22774255985, 0, 0, 0);
        _delay(360624);
        Tester.borrow(204954930, 0, 0, 234);
        _delay(533426);
        Tester.repay(1, 15, 54, 0);
    }

    function test_replay_withdraw_2() public {
        _setUpActor(USER1);
        _delay(228361);
        Tester.setUsingAsCollateral(true, 0, 43);
        _delay(296474);
        Tester.supply(47683715958142044857, 105, 0, 9);
        _delay(360624);
        Tester.borrow(51355, 0, 0, 5);
        _delay(426559);
        Tester.repay(684742840631310434884539857599449768327155454254541969729420468406827, 0, 158, 88);
        _delay(9096);
        Tester.withdraw(57966352054216140970237172336532564104220339507694885035496782237, 213, 0, 120);
        _setUpActor(USER2);
        _delay(349477);
        Tester.withdraw(51236477730500247308223064742179045624643677222313070801276200340260439695, 0, 0);
    }

    function test_replay_updateUserRiskPremium_4() public {
        _setUpActor(USER1);
        _delay(228361);
        Tester.setUsingAsCollateral(true, 0, 0);
        _delay(296474);
        Tester.supply(174, 243, 0, 7);
        _delay(360624);
        Tester.borrow(1, 0, 0, 26);
        _setUpActor(USER3);
        _delay(584023);
        Tester.updateUserRiskPremium(0);
    }

    function test_replay_setUsingAsCollateral_5() public {
        _setUpActor(USER1);
        _delay(228361);
        Tester.setUsingAsCollateral(true, 0, 19);
        _delay(296474);
        Tester.supply(98423, 249, 0, 133);
        _delay(360624);
        Tester.borrow(2453, 0, 0, 2);
        _setUpActor(USER2);
        _delay(322362);
        Tester.setUsingAsCollateral(true, 0, 0);
    }

    function test_replay_setPrice_5() public {
        _setUpActor(USER1);
        _delay(586107);
        Tester.setUsingAsCollateral(true, 0, 58);
        _delay(296474);
        Tester.supply(416, 0, 0, 5);
        _setUpActor(USER2);
        _delay(305693);
        Tester.setPrice(258657099142048003581115496186011548248157129485377727959920274374993509, 10);
    }

    function test_replay_transfer() public {
        _setUpActor(USER1);
        _delay(360520);
        Tester.supply(1100316557268, 0, 0, 0);
        _delay(111007);
        Tester.setUsingAsCollateral(true, 0, 110);
        _delay(360624);
        Tester.borrow(96719, 0, 0, 61);
        _delay(124260);
        Tester.transfer(0, 0, 0, 0);
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
