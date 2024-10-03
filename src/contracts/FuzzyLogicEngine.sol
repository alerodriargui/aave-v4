// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract FuzzyLogicEngine {
  struct Variable {
    string name;
    string[] setsName;
    uint256[][] sets;
  }

  // Define the variables used for input
  uint256[] crisp_input = [150, 10, 10];

  // Intermediate step to build sets
  uint256[] targetSetA = [0, 0, 25, 150];
  uint256[] targetSetB = [25, 150, 150, 300];
  uint256[] targetSetC = [150, 300, 400, 400];
  uint256[][] targetSets = [targetSetA, targetSetB, targetSetC];

  uint256[] ammoSetA = [0, 0, 10, 10];
  uint256[] ammoSetB = [0, 10, 30, 30];
  uint256[] ammoSetC = [10, 30, 40, 40];
  uint256[][] ammoSets = [ammoSetA, ammoSetB, ammoSetC];

  uint256[] defenseSetA = [0, 0, 10, 10];
  uint256[] defenseSetB = [0, 10, 30, 30];
  uint256[] defenseSetC = [10, 30, 40, 40];
  uint256[][] defenseSets = [defenseSetA, defenseSetB, defenseSetC];

  uint256[] desirabilitySetA = [0, 0, 25, 50];
  uint256[] desirabilitySetB = [25, 50, 50, 75];
  uint256[] desirabilitySetC = [50, 75, 100, 100];
  uint256[][] desirabilitySets = [desirabilitySetA, desirabilitySetB, desirabilitySetC];

  string[] targetNames = ['Close', 'Medium', 'Far'];
  string[] ammoNames = ['Low', 'Okay', 'Loads'];
  string[] defenseNames = ['Light', 'Medium', 'Heavy'];
  string[] desirabilityNames = ['Undesirable', 'Desirable', 'Very Desirable'];

  // Can't do this: Variable[] variables_input = [variable_inputA, variable_inputB, variable_inputC];
  // So...

  Variable variable_inputA =
    Variable({name: 'Distance to Target', setsName: targetNames, sets: targetSets});
  Variable variable_inputB = Variable({name: 'Ammo Status', setsName: ammoNames, sets: ammoSets});
  Variable variable_inputC = Variable({name: 'Defense', setsName: defenseNames, sets: defenseSets});

  Variable variable_output =
    Variable({name: 'Desirability', setsName: desirabilityNames, sets: desirabilitySets});

  uint256[][] inferences = [[0, 2, 0], [0, 1, 2], [2, 1, 0]];
}
