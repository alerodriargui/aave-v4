// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// Libraries
import "forge-std/Test.sol";
import "forge-std/console.sol";

// Contracts
import {Invariants} from "../Invariants.t.sol";
import {Setup} from "../Setup.t.sol";

// Utils
import {Actor} from "../../shared/utils/Actor.sol";

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

    function test_replay_7_updateUserRiskPremium() public {
        _setUpActor(USER3);
        Tester.supply(790, 128, 71, 201);
        Tester.setUsingAsCollateral(true, 111, 253);
        Tester.borrow(527, 68, 203, 9);
        _setUpActor(USER1);
        _delay(1812425);
        _delay(320876);
        Tester.updateFrozen(false, 59, 85);
        _setUpActor(USER2);
        _delay(343393);
        Tester.updateHealthFactorForMaxBonus(105, 146);
        _setUpActor(USER1);
        _delay(2272303);
        _setUpActor(USER2);
        _delay(62189);
        Tester.updateUserRiskPremium(101);
        _setUpActor(USER3);
        _delay(590687);
        Tester.setUsingAsCollateral(true, 111, 253);
        _delay(323286);
        Tester.donateUnderlyingToHub(194, 231, 231);
        _delay(505810);
        Tester.borrow(56, 77, 155, 21);
        _setUpActor(USER2);
        _delay(112744);
        Tester.updateBorrowable(false, 223, 157);
        _setUpActor(USER1);
        _delay(1632525);
        _setUpActor(USER2);
        _delay(128066);
        Tester.updateFrozen(false, 52, 208);
        _delay(180364);
        Tester.setPrice(44015031536544474472307730349212877645270025151054012889336165188860863984788, 87);
        _setUpActor(USER3);
        _delay(460111);
        Tester.updateBorrowable(true, 160, 11);
        _setUpActor(USER1);
        _delay(898801);
        _setUpActor(USER3);
        _delay(271962);
        Tester.pauseAllReserves(251);
        _setUpActor(USER2);
        _delay(928317);
        _setUpActor(USER1);
        _delay(23908);
        Tester.updateBorrowable(true, 217, 53);
        _setUpActor(USER3);
        _delay(582766);
        Tester.updateUserRiskPremium(25);
    }

    function test_replay_7_repay() public {
        _setUpActor(USER3);
        _delay(321376);
        Tester.supply(790, 197, 87, 201);
        Tester.supply(100000000000000000000000002, 50, 228, 214);
        Tester.setUsingAsCollateral(true, 197, 253);
        _delay(20833);
        Tester.borrow(2973933138, 65, 107, 14);
        _setUpActor(USER1);
        Tester.updateSpokeSupplyCap(172, 180, 253, 253);
        _setUpActor(USER3);
        _delay(997);
        Tester.repay(1209722426464509529070304541882533570806727645123886685504166337177518312, 62, 253, 254);
    }

    function test_replay_7_withdraw() public {
        _setUpActor(USER1);
        Tester.withdraw(1, 0, 0, 0);
    }

    function test_replay_7_setUsingAsCollateral() public {
        _setUpActor(USER3);
        Tester.supply(790, 128, 71, 201);
        Tester.setUsingAsCollateral(true, 111, 253);
        Tester.borrow(527, 68, 203, 9);
        _setUpActor(USER1);
        _delay(338347);
        Tester.freezeAllReserves(32);
        _delay(322337);
        Tester.updatePaused(false, 67, 125);
        _delay(572077);
        Tester.updateBorrowable(true, 243, 99);
        _delay(588832);
        _setUpActor(USER2);
        _delay(322214);
        Tester.donateUnderlyingToHub(3285266288, 36, 25);
        _setUpActor(USER1);
        _delay(186977);
        _delay(427128);
        Tester.updateFrozen(false, 82, 38);
        _delay(320876);
        Tester.updateFrozen(false, 59, 81);
        _delay(119298);
        Tester.updateFrozen(false, 232, 62);
        _delay(472666);
        _delay(256656);
        Tester.updatePaused(false, 228, 146);
        _delay(322373);
        _delay(590687);
        Tester.setUsingAsCollateral(true, 111, 253);
        _delay(510341);
        _setUpActor(USER2);
        _delay(440321);
        Tester.freezeAllReserves(102);
        _setUpActor(USER3);
        _delay(572099);
        Tester.pauseAllReserves(16);
        _setUpActor(USER1);
        _delay(323286);
        Tester.donateUnderlyingToHub(194, 231, 231);
        _setUpActor(USER2);
        _delay(222666);
        Tester.updatePaused(false, 55, 68);
        _delay(1570291);
        _delay(66387);
        Tester.updatePaused(true, 51, 192);
        _delay(232282);
        Tester.freezeAllReserves(63);
        _setUpActor(USER1);
        _delay(634311);
        _delay(329177);
        Tester.donateUnderlyingToSpoke(
            8482560104382015275375946442131157991925236995011038634869166413646018956770, 192, 19
        );
        _setUpActor(USER2);
        _delay(235558);
        Tester.updateBorrowable(true, 251, 0);
        _setUpActor(USER1);
        _delay(759555);
        _delay(181708);
        Tester.updateLiquidationBonusFactor(779, 210);
        _delay(186473);
        Tester.updateBorrowable(false, 49, 5);
        _delay(442967);
        Tester.updateBorrowable(false, 60, 7);
        _delay(1282001);
        _delay(34027);
        Tester.updateBorrowable(false, 12, 185);
        _delay(542285);
        _setUpActor(USER2);
        _delay(112744);
        Tester.updateBorrowable(false, 223, 157);
        _delay(223839);
        _setUpActor(USER3);
        _delay(598111);
        Tester.freezeAllReserves(22);
        _setUpActor(USER1);
        _delay(1518691);
        _delay(125389);
        Tester.pauseAllReserves(202);
        _setUpActor(USER3);
        _delay(145762);
        Tester.updateFrozen(true, 34, 251);
        _setUpActor(USER1);
        _delay(274181);
        Tester.updateSpokeSupplyCap(557, 21, 5, 251);
        _setUpActor(USER2);
        _delay(146364);
        Tester.updatePaused(true, 153, 153);
        _setUpActor(USER1);
        _delay(448413);
        Tester.updatePaused(false, 37, 158);
        _setUpActor(USER3);
        _delay(888942);
        _setUpActor(USER2);
        _delay(423178);
        Tester.updateSpokePaused(true, 204, 232, 13);
        _setUpActor(USER1);
        _delay(332581);
        Tester.updateSpokePaused(true, 27, 135, 207);
        _delay(901860);
        _setUpActor(USER2);
        _delay(213701);
        Tester.updateUserDynamicConfig(196);
        _setUpActor(USER1);
        _delay(180364);
        Tester.setPrice(44015031536544474472307730349212877645270025151054012889336165188860863984788, 87);
        _delay(460111);
        Tester.updateBorrowable(true, 160, 11);
        _setUpActor(USER2);
        _delay(464489);
        Tester.updateFrozen(true, 108, 29);
        _setUpActor(USER1);
        _delay(491000);
        _delay(251970);
        Tester.freezeAllReserves(3);
        _setUpActor(USER2);
        _delay(554942);
        Tester.updateLiquidationTargetHealthFactor(1066876585488452360309478396, 181);
        _setUpActor(USER1);
        _delay(271962);
        Tester.pauseAllReserves(251);
        _setUpActor(USER2);
        _delay(1178040);
        _setUpActor(USER1);
        _delay(322327);
        Tester.setPrice(10091973037445179265966792088849362926006764080479895945907781515590410660983, 0);
        _delay(334870);
        Tester.updateSpokeDrawCap(282, 16, 27, 233);
        _delay(181962);
        Tester.updateUserRiskPremium(159);
        _delay(4103101);
        _delay(23908);
        Tester.updateBorrowable(true, 217, 53);
        _delay(1164972);
        _setUpActor(USER3);
        _delay(425952);
        Tester.setPrice(49, 253);
        _setUpActor(USER1);
        _delay(115964);
        Tester.updateUserRiskPremium(25);
        _setUpActor(USER3);
        _delay(322335);
        _setUpActor(USER1);
        _delay(116982);
        Tester.updateBorrowable(false, 5, 162);
        _delay(197173);
        Tester.pauseAllReserves(165);
        _setUpActor(USER3);
        _delay(1603416);
        _setUpActor(USER1);
        _delay(373335);
        Tester.donateUnderlyingToSpoke(251509, 90, 117);
        _setUpActor(USER3);
        _delay(209895);
        Tester.updateFrozen(false, 59, 52);
        _setUpActor(USER1);
        _delay(1531689);
        _delay(31623);
        Tester.pauseAllReserves(78);
        _delay(351918);
        _delay(246382);
        Tester.updateBorrowable(true, 0, 36);
        _delay(81953);
        Tester.donateUnderlyingToSpoke(1145407145531574156784556985, 233, 70);
        _delay(361136);
        _delay(70382);
        Tester.setPrice(13722671120008796056116167155935139741016600691512816323271681734783393234974, 44);
        _setUpActor(USER2);
        _delay(158734);
        _delay(252594);
        Tester.setPrice(-10497, 28);
        _setUpActor(USER3);
        _delay(210182);
        Tester.pauseAllReserves(157);
        _setUpActor(USER1);
        _delay(509009);
        _setUpActor(USER3);
        _delay(322329);
        Tester.updateUserRiskPremium(158);
        _setUpActor(USER1);
        _delay(2400553);
        _delay(595514);
        Tester.setPrice(41373793859755415169263012240629611521716694833500847797235110793826563352795, 25);
        _delay(565575);
        _setUpActor(USER3);
        _delay(457363);
        Tester.freezeAllReserves(124);
        _setUpActor(USER1);
        _delay(293193);
        _setUpActor(USER2);
        Tester.updatePaused(false, 59, 104);
        _setUpActor(USER1);
        _delay(391851);
        Tester.updateSpokePaused(false, 89, 161, 128);
        _setUpActor(USER3);
        _delay(546825);
        Tester.updateSpokePaused(false, 247, 171, 126);
        _delay(523414);
        Tester.setUsingAsCollateral(false, 27, 0);
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
