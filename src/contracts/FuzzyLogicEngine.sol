// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// TODO: Appropriately handle infinity
// TODO: Try and simplify types where possible e.g. deciding on uint265 vs int256
// TODO: Write the input as in javascript while debugging for comparison
contract FuzzyLogicEngine {
  struct Variable {
    string name;
    string[] setsName;
    uint256[][] sets;
  }

  // Holds the output of construct variable
  struct Construct {
    uint256[] a;
    uint256 firstPoint;
    uint256 lastPoint;
    int256 mUp;
    int256 mDown;
  }

  int256 public constant INF = type(int256).max;
  int256 public constant NEG_INF = INF - 1;

  // NOTE: Keeping these arrays as uint256 because it makes the input declarations easier

  // Define the variables used for input
  uint256[3] crispInput = [150, 10, 10];

  // Intermediate step to build sets
  uint256[] targetSetA = [0, 0, 25, 150];
  uint256[] targetSetB = [25, 150, 150, 300];
  uint256[] targetSetC = [150, 300, 400, 400];
  uint256[][] targetSets = [targetSetA, targetSetB, targetSetC];

  uint256[] ammoSetA = [0, 0, 0, 10];
  uint256[] ammoSetB = [0, 10, 10, 30];
  uint256[] ammoSetC = [10, 30, 40, 40];
  uint256[][] ammoSets = [ammoSetA, ammoSetB, ammoSetC];

  uint256[] defenseSetA = [0, 0, 0, 10];
  uint256[] defenseSetB = [0, 10, 10, 30];
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

  uint256[] testArrayA = [4, 5, 6];
  uint256[] testArrayB = [18];
  uint256[] testArrayC = [1, 2];

  uint256[][] a;

  // TODO: Determine better way to fetch these inputs / interact with system w/out getting stack too deep
  function getCrispInput() public view returns (uint256[3] memory) {
    return crispInput;
  }

  function getTargetSetA() public view returns (uint256[] memory) {
    return targetSetA;
  }

  function getTargetSetB() public view returns (uint256[] memory) {
    return targetSetB;
  }

  function getTargetSetC() public view returns (uint256[] memory) {
    return targetSetC;
  }

  function getAmmoSetA() public view returns (uint256[] memory) {
    return ammoSetA;
  }

  function getAmmoSetB() public view returns (uint256[] memory) {
    return ammoSetB;
  }

  function getAmmoSetC() public view returns (uint256[] memory) {
    return ammoSetC;
  }

  function getDefenseSetA() public view returns (uint256[] memory) {
    return defenseSetA;
  }

  function getDefenseSetB() public view returns (uint256[] memory) {
    return defenseSetB;
  }

  function getDefenseSetC() public view returns (uint256[] memory) {
    return defenseSetC;
  }

  function getInferences() public view returns (uint256[][] memory) {
    return inferences;
  }

  function getDesirabilitySets() public view returns (uint256[][] memory) {
    return desirabilitySets;
  }

  function getOneOutput() public view returns (uint256[] memory) {
    return testArrayA;
  }

  function getTwoOutput() public view returns (uint256[] memory) {
    return testArrayB;
  }

  function getThreeOutput() public view returns (uint256[] memory) {
    return testArrayC;
  }

  // TODO: Natspec
  // TODO: This original javascript function just hardcodes the trapezoid pattern, but we could extend it to have `n` points
  // This function fixes i, so could just do this function for one set and call it multiple times
  // obv[i] is our Construct struct for each array of uint256s
  // Input: One uint256 array, corresponding to e.g. targetSetA
  // Output: obv[i] (our Construct struct)
  function constructVariableSingular(
    uint256[] memory input
  ) public pure returns (Construct memory c) {
    c.a = input;
    c.firstPoint = input[0] == input[1] ? 1 : 0;
    c.lastPoint = input[2] == input[3] ? 1 : 0;
    if (input[1] - input[0] == 0) {
      c.mUp = INF;
    } else {
      c.mUp = int256(1e18 / (input[1] - input[0])); // Note: Inputs defined in ascending order to not make this negative
    }
    if (input[3] - input[2] == 0) {
      c.mDown = INF;
    } else {
      c.mDown = int256(1e18 / (input[3] - input[2])); // TODO: Consider changing to something higher like 10e18 or 100e18 - that will be our "1"
    }
  }

  function fuzzification(
    uint256[3] memory crispInput,
    FuzzyLogicEngine.Construct[3][3] memory variables
  ) public pure returns (int256[3][3] memory) {
    int256[3][3] memory value;
    for (uint256 i = 0; i < variables.length; i++) {
      value[i] = fuzzification_variable(crispInput[i], variables[i]);
    }

    return value;
  }

  function fuzzification_variable(
    uint256 x,
    FuzzyLogicEngine.Construct[3] memory sets
  ) public pure returns (int256[3] memory) {
    int256[3] memory valori;
    for (uint256 i = 0; i < sets.length; i++) {
      valori[i] = fuzzification_function(x, sets[i]);
    }

    return valori;
  }

  function fuzzification_function(uint256 x, Construct memory set) public pure returns (int256 f) {
    f = 0;
    if (x <= set.a[0]) {
      f = int256(set.firstPoint);
    } else if (x < set.a[1]) {
      if (set.mUp == INF) {
        f = INF;
      } else {
        f = set.mUp * int256(x - set.a[0]);
      }
    } else if (x <= set.a[2]) {
      f = 1;
    } else if (x < set.a[3]) {
      if (set.mDown == INF) {
        f = NEG_INF;
      } else {
        f = 1e18 - (set.mDown * int256(x - set.a[2]));
      }
    } else if (x >= set.a[3]) {
      f = int256(set.lastPoint);
    }
  }

  // TODO: Natspec
  // TODO: Input is fuzzy input (result of fuzzification), inferences (our array), and variable output, which is our
  // Variable struct, but we only need the 'sets' from that struct (double array)
  function outputCombination(
    int256[3][3] memory fuzzyInput,
    uint256[][] memory inferences,
    uint256[][] memory variableOutputSets
  ) public returns (uint256[][] memory) {
    a = [[0], [0], [0]];

    bool firstAddToRow1 = true;
    bool firstAddToRow2 = true;
    bool firstAddToRow3 = true;

    for (uint256 i = inferences.length; i >= 1; i--) {
      for (uint256 j = inferences.length; j >= 1; j--) {
        if (inferences[i - 1][j - 1] >= 0) {
          if (inferences[i - 1][j - 1] == 0 && firstAddToRow1) {
            a[inferences[i - 1][j - 1]] = [uint256(fuzzyInput[i - 1][j - 1])];
            firstAddToRow1 = false;
          } else if (inferences[i - 1][j - 1] == 1 && firstAddToRow2) {
            a[inferences[i - 1][j - 1]] = [uint256(fuzzyInput[i - 1][j - 1])];
            firstAddToRow2 = false;
          } else if (inferences[i - 1][j - 1] == 2 && firstAddToRow3) {
            a[inferences[i - 1][j - 1]] = [uint256(fuzzyInput[i - 1][j - 1])];
            firstAddToRow3 = false;
          } else {
            a[inferences[i - 1][j - 1]].push(uint256(fuzzyInput[i - 1][j - 1]));
          }
        }
      }
    }

    return a;
  }

  // TODO: Appropriately handle infinity
  // TODO: Ensure the added multiples for math don't interrupt the math itself
  // TODO: Implement
  // Concern is that it takes multiple inputs, so need to handle carefully
  // I think my types are correct
  // TODO: See if I can recreate these input types so I can use these functions in the same way as the js code
  // TODO: I'm concerned that multiple multiplications before divisions (e.g. if multiple if conidtions are met)
  // Might lead to incorrect results, so double check the math there
  function defuzzification(
    uint256[] memory outputSet,
    Construct[] memory variable
  ) public pure returns (int256) {
    int256 num = 0;
    int256 den = 0;
    int256 a1 = 0;
    int256 a2 = 0;
    int256 area = 0;
    int256 y_baricentro = 0;
    int256 x_baricentro = 0;
    int256 bmezzi = 0;
    int256 mmezzi = 0;

    for (uint256 i = outputSet.length - 1; i >= 0; i--) {
      a1 = int256(variable[i].a[0]);
      if (variable[i].a[0] != variable[i].a[1]) {
        a1 += int256(int256(outputSet[i]) * 1e18) / variable[i].mUp; // Anything divided by inf is 0
      }
      a2 = int256(variable[i].a[3]);
      if (variable[i].a[2] != variable[i].a[3]) {
        a2 -= int256(int256(outputSet[i]) * 1e18) / variable[i].mDown; // Anything divided by inf is 0
      }
      area = 0;
      if (int256(variable[i].a[0]) != a1) {
        area += (((a1 - int256(variable[i].a[0])) * int256(outputSet[i])) * 1e18) / 2; // Revisit extra multiplication
      }
      if (a1 != a2) {
        area += (a2 - a1) * int256(outputSet[i]);
      }
      if (a2 != int256(variable[i].a[3])) {
        area += (((int256(variable[i].a[3]) - a2) * int256(outputSet[i])) * 1e18) / 2; // Revisit extra multiplication
      }
      y_baricentro =
        ((((int256(outputSet[i]) * 1e18) / 3) *
          (int256(variable[i].a[3] - variable[i].a[0]) + 2 * (a2 - a1))) * 1e18) / // Revisit extra multiplication
        ((a2 - a1) + int256(variable[i].a[3] - variable[i].a[0]));
      bmezzi = int256(variable[i].a[0] + ((variable[i].a[3] - variable[i].a[0]) * 1e18) / 2); // Revisit extra multiplication
      mmezzi = 0;
      if ((((a1 + (a2 - a1)) * 1e18) / 2) - bmezzi != 0) {
        // Revisit extra multiplication
        mmezzi = (int256(outputSet[i]) * 1e18) / ((((a1 + (a2 - a1)) * 1e18) / 2) - bmezzi);
      }
      x_baricentro = bmezzi;
      if (mmezzi != 0) {
        x_baricentro += (y_baricentro * 1e18) / mmezzi;
      }
      num += area * x_baricentro;
      den += area;
    }

    return den == 0 ? int256(0) : int256((num * 1e18) / den);
  }

  function takeMaxOfArraySet(uint256[][] memory set) public pure returns (uint256[] memory max) {
    max = new uint256[](set[0].length);
    for (uint256 i = 0; i < set[0].length; i++) {
      max[i] = takeMaxOfArray(set[i]);
    }
  }

  function takeMaxOfArray(uint256[] memory arr) public pure returns (uint256 max) {
    max = arr[0];
    for (uint256 i = 1; i < arr.length; i++) {
      if (arr[i] > max) {
        max = arr[i];
      }
    }
  }
}
