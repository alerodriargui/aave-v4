// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'forge-std/Test.sol';
import 'forge-std/console2.sol';

import 'src/contracts/FuzzyLogicEngine.sol';

contract FuzzyLogicEngineTest is Test {
  FuzzyLogicEngine fle = new FuzzyLogicEngine();

  /*
  function testFuzzyLogicEngine() public {
    // NOTE: Keeping these arrays as uint256 because it makes the input declarations easier

    // Define the variables used for input
    uint256[3] memory crisp_input = [uint256(150), uint256(10), uint256(10)];

    // Intermediate step to build sets
    uint256[4] memory targetSetA = [uint256(0), uint256(0), uint256(25), uint256(150)];
    uint256[4] memory targetSetB = [uint256(25), uint256(150), uint256(150), uint256(300)];
    uint256[4] memory targetSetC = [uint256(150), uint256(300), uint256(400), uint256(400)];
    uint256[4][3] memory targetSets = [
      uint256[4](targetSetA),
      uint256[4](targetSetB),
      uint256[4](targetSetC)
    ];

    uint256[4] memory ammoSetA = [uint256(0), uint256(0), uint256(10), uint256(10)];
    uint256[4] memory ammoSetB = [uint256(0), uint256(10), uint256(30), uint256(30)];

    uint256[4] memory ammoSetC = [uint256(10), uint256(30), uint256(40), uint256(40)];
    uint256[4][3] memory ammoSets = [
      uint256[4](ammoSetA),
      uint256[4](ammoSetB),
      uint256[4](ammoSetC)
    ];

    uint256[4] memory defenseSetA = [uint256(0), uint256(0), uint256(10), uint256(10)];
    uint256[4] memory defenseSetB = [uint256(0), uint256(10), uint256(30), uint256(30)];
    uint256[4] memory defenseSetC = [uint256(10), uint256(30), uint256(40), uint256(40)];
    uint256[4][3] memory defenseSets = [
      uint256[4](defenseSetA),
      uint256[4](defenseSetB),
      uint256[4](defenseSetC)
    ];

    uint256[4] memory desirabilitySetA = [uint256(0), uint256(0), uint256(25), uint256(50)];
    uint256[4] memory desirabilitySetB = [uint256(25), uint256(50), uint256(50), uint256(75)];
    uint256[4] memory desirabilitySetC = [uint256(50), uint256(75), uint256(100), uint256(100)];
    uint256[4][3] memory desirabilitySets = [
      uint256[4](desirabilitySetA),
      uint256[4](desirabilitySetB),
      uint256[4](desirabilitySetC)
    ];

    string[3] memory targetNames = ['Close', 'Medium', 'Far'];
    string[3] memory ammoNames = ['Low', 'Okay', 'Loads'];
    string[3] memory defenseNames = ['Light', 'Medium', 'Heavy'];
    string[3] memory desirabilityNames = ['Undesirable', 'Desirable', 'Very Desirable'];

    // Can't do this: Variable[] variables_input = [variable_inputA, variable_inputB, variable_inputC];
    // So...

    FuzzyLogicEngine.Variable memory variable_inputA = FuzzyLogicEngine.Variable({
      name: 'Distance to Target',
      setsName: targetNames,
      sets: targetSets
    });
    FuzzyLogicEngine.Variable memory variable_inputB = FuzzyLogicEngine.Variable({
      name: 'Ammo Status',
      setsName: ammoNames,
      sets: ammoSets
    });
    FuzzyLogicEngine.Variable memory variable_inputC = FuzzyLogicEngine.Variable({
      name: 'Defense',
      setsName: defenseNames,
      sets: defenseSets
    });

    FuzzyLogicEngine.Variable memory variable_output = FuzzyLogicEngine.Variable({
      name: 'Desirability',
      setsName: desirabilityNames,
      sets: desirabilitySets
    });

    uint256[3][3] memory inferences = [
      [uint256(0), uint256(2), uint256(0)],
      [uint256(0), uint256(1), uint256(2)],
      [uint256(2), uint256(1), uint256(0)]
    ];
  }
  */
}
