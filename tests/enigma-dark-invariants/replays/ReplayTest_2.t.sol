// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Contracts
import {Invariants} from "../Invariants.t.sol";
import {Setup} from "../Setup.t.sol";

// Utils
import {Actor} from "../utils/Actor.sol";

contract ReplayTest2 is Invariants, Setup {
    // Generated from Echidna reproducers

    // Target contract instance (you may need to adjust this)
    ReplayTest2 Tester = this;

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
    
    
    function test_replay_2_withdraw() public {
        _setUpActor(USER3);
        Tester.supply(1, 23, 0, 2);
        Tester.withdraw(3105157079507136411131272320472170162160557515874316681599825263298447597, 2, 0, 0);
        
    }
    
    function test_replay_2_supply() public {
        _setUpActor(USER2);
        Tester.setUsingAsCollateral(true, 25, 3);
        Tester.supply(855, 7, 0, 3);
        Tester.borrow(1, 1, 11, 0);
        _setUpActor(USER1);
        _delay(5032074);
        Tester.supply(1768, 0, 0, 0);
        
    }
    
    function test_replay_2_setUsingAsCollateral() public {
        _setUpActor(USER2);
        Tester.supply(119335, 1, 0, 0);
        Tester.setUsingAsCollateral(true, 0, 0);
        Tester.borrow(1, 1, 1, 0);
        _setUpActor(USER1);
        _delay(2);
        Tester.setUsingAsCollateral(false, 0, 0);
        
    }
    
    function test_replay_2_liquidationCall() public {
        _setUpActor(USER1);
        _delay(716);
        Tester.supply(431999, 84, 27, 125);
        _setUpActor(USER2);
        _delay(577108);
        Tester.supply(80962052803112294330194839042, 16, 45, 125);
        _setUpActor(USER3);
        _delay(7578);
        Tester.setUsingAsCollateral(true, 1, 254);
        Tester.supply(10092, 38, 37, 223);
        Tester.borrow(7800, 227, 62, 51);
        _setUpActor(USER1);
        _delay(2138596);
        _delay(194640);
        Tester.withdraw(115792089237316195423570985008687907853269984665640564039457584007913129585001, 15, 131, 247);
        _delay(322334);
        Tester.setUsingAsCollateral(true, 31, 244);
        _setUpActor(USER2);
        _delay(827249);
        _setUpActor(USER1);
        _delay(405856);
        Tester.liquidationCall(61422963954080211324642765950298638470789887452796784425666156856462101843613, 53, 251, 56, 20);
        
    }
    
    function test_replay_2_updateUserDynamicConfig() public {
        _setUpActor(USER3);
        Tester.supply(7123984353, 2, 126, 4);
        Tester.setUsingAsCollateral(true, 6, 8);
        Tester.borrow(1468, 2, 0, 0);
        _setUpActor(USER1);
        _delay(12809);
        Tester.updateUserDynamicConfig(0);
        
    }
    
    function test_replay_2_repay() public {
        _setUpActor(USER2);
        Tester.supply(16, 25, 2, 7);
        Tester.setUsingAsCollateral(true, 81, 2);
        Tester.borrow(2, 16, 5, 4);
        _delay(61);
        Tester.repay(1, 19, 0, 248);
        
    }
    
    function test_replay_2_updateUserRiskPremium() public {
        _setUpActor(USER3);
        Tester.setUsingAsCollateral(true, 0, 22);
        Tester.supply(2786, 251, 0, 14);
        Tester.borrow(71, 77, 5, 3);
        _setUpActor(USER1);
        _delay(53617);
        Tester.updateUserRiskPremium(0);
        
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