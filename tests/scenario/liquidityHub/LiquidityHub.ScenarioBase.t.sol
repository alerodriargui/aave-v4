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
  uint256 internal constant NUM_TIMESTAMPS = 10;
  uint256 internal constant NUM_SPOKES = 4;
  uint256 internal constant NUM_ASSETS = 4;
  bool internal isPrintLogs = false;

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

  struct SpokeAmounts {
    Timestamps supply;
    Timestamps withdraw;
    Timestamps draw;
    Timestamps restore;
  }

  struct SpokeActionAssetIds {
    Timestamps supplyAssetId;
    Timestamps withdrawAssetId;
    Timestamps drawAssetId;
    Timestamps restoreAssetId;
  }

  uint256[] internal timestamps;
  AssetDatas[NUM_ASSETS] internal assets;
  SpokeDatas[NUM_SPOKES] internal spokes;
  SpokeActionAssetIds[NUM_SPOKES] internal spokeActions;
  SpokeAmounts[NUM_SPOKES] internal spokeAmounts;
  Stage[NUM_TIMESTAMPS] internal stages;
  CalculatedStates internal states;

  function setUp() public virtual override {
    super.setUp();

    spokes[0].addr = address(spoke1);
    spokes[1].addr = address(spoke2);
    spokes[2].addr = address(spoke3);

    // init stages
    for (uint8 t = 0; t < NUM_TIMESTAMPS; t++) {
      stages[t] = Stage.wrap(t);
    }
    timestamps.push(vm.getBlockTimestamp());
  }
  function precondition(Stage stage) internal virtual {}
  function initialAssertions(Stage stage) internal virtual {}

  function printInitialLog(Stage stage) internal virtual {}
  function exec(Stage stage) internal virtual {}
  function finalAssertions(Stage stage) internal virtual {}
  function skipTime(Stage stage) internal virtual {}
  function postcondition(Stage stage) internal virtual {
    timestamps.push(vm.getBlockTimestamp());
  }
  function printFinalLog(Stage stage) internal virtual {}

  function _testScenario() internal virtual {
    Stage stage;

    for (uint256 t = 0; t < NUM_TIMESTAMPS; t++) {
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
}
