// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/BaseTest.t.sol';
import {Asset, SpokeData} from 'src/contracts/LiquidityHub.sol';

type Stage is uint8;
function eq(Stage a, Stage b) pure returns (bool) {
  return Stage.unwrap(a) == Stage.unwrap(b);
}
using {eq as ==} for Stage global;

abstract contract LiquidityHubScenarioBaseTest is BaseTest {
  using SharesMath for uint256;
  using WadRayMath for uint256;
  using PercentageMath for uint256;

  uint256 internal constant NUM_TIMESTAMPS = 10;
  uint256 internal constant NUM_SPOKES = 4;
  uint256 internal constant NUM_ASSETS = 4;
  bool internal isPrintLogs = false;
  uint256 internal t; // internal stage index

  struct TestState {
    uint256 assetId;
    uint256 baseBorrowRate;
    uint256[NUM_TIMESTAMPS] skipTime;
    SpokeActions[NUM_SPOKES] actions;
  }

  TestState internal state;
  DataTypes.SpokeConfig internal spokeConfig;
  Spoke internal spoke4;

  // _i: initial, prior to action at a given time
  // _f: final, after action at a given time
  struct Timestamps {
    uint256[NUM_TIMESTAMPS] t_i;
    uint256[NUM_TIMESTAMPS] t_f;
  }

  struct SpokeDatas {
    SpokeData[NUM_TIMESTAMPS] t_i;
    SpokeData[NUM_TIMESTAMPS] t_f;
    address addr;
    SpokeActions actions;
  }

  struct AssetDatas {
    Asset[NUM_TIMESTAMPS] t_i;
    Asset[NUM_TIMESTAMPS] t_f;
  }

  struct CalculatedStates {
    Timestamps cumulatedBaseInterest;
    Timestamps cumulatedBaseDebt;
    Timestamps[NUM_SPOKES] cumulatedSpokeBaseDebt;
  }

  struct SpokeActions {
    SupplyAction[NUM_TIMESTAMPS] supply;
    WithdrawAction[NUM_TIMESTAMPS] withdraw;
    DrawAction[NUM_TIMESTAMPS] draw;
    RestoreAction[NUM_TIMESTAMPS] restore;
  }

  struct SupplyAction {
    uint256 amount;
    uint256 assetId;
  }

  struct WithdrawAction {
    uint256 amount;
    uint256 assetId;
  }

  struct DrawAction {
    uint256 amount;
    uint256 assetId;
  }

  struct RestoreAction {
    uint256 amount;
    uint256 assetId;
  }

  uint256[] internal timestamps;
  AssetDatas[NUM_ASSETS] internal assets;
  SpokeDatas[NUM_SPOKES] internal spokes;
  Stage[NUM_TIMESTAMPS] internal stages;
  CalculatedStates internal states;

  function setUp() public virtual override {
    super.setUp();

    spokes[0].addr = address(spoke1);
    spokes[1].addr = address(spoke2);
    spokes[2].addr = address(spoke3);

    // init stages
    for (uint8 i = 0; i < NUM_TIMESTAMPS; i++) {
      stages[i] = Stage.wrap(i);
    }
    timestamps.push(vm.getBlockTimestamp());
  }

  // invoked once before the test scenario
  function preTestSetup() internal virtual {}

  // invoked on each time step
  function precondition(Stage stage) internal virtual {}
  function initialAssertions(Stage stage) internal virtual {}

  function printInitialLog(Stage stage) internal virtual {
    console.log(string.concat('----- t', vm.toString(t), '_i -----'));
  }
  function exec(Stage stage) internal virtual {}
  function finalAssertions(Stage stage) internal virtual {}
  function skipTime(Stage stage) internal virtual {}
  function postcondition(Stage stage) internal virtual {
    timestamps.push(vm.getBlockTimestamp());
  }
  function printFinalLog(Stage stage) internal virtual {
    console.log(string.concat('----- t', vm.toString(t), '_f -----'));
  }

  function _testScenario() internal virtual {
    Stage stage;

    preTestSetup();
    for (t = 0; t < NUM_TIMESTAMPS; t++) {
      stage = stages[t];
      precondition(stage);
      initialAssertions(stage);
      if (isPrintLogs) {
        printInitialLog(stage);
      }
      exec(stage);
      finalAssertions(stage);
      if (isPrintLogs) {
        printFinalLog(stage);
      }
      skipTime(stage);
      postcondition(stage);
    }
  }

  function timeAt(Stage stage) internal view returns (uint40) {
    return uint40(timestamps[uint256(Stage.unwrap(stage))]);
  }

  /// @param baseBorrowRate base borrow rate in bps
  function mockBaseBorrowRate(uint256 baseBorrowRate) internal {
    vm.mockCall(
      address(irStrategy),
      IReserveInterestRateStrategy.calculateInterestRates.selector,
      abi.encode(baseBorrowRate.bpsToRay())
    );
  }

  function fillSkipTime(uint256[NUM_TIMESTAMPS] storage skipTime, uint256 time) internal {
    for (uint256 i = 0; i < NUM_TIMESTAMPS; i++) {
      skipTime[i] = time;
    }
  }
}
