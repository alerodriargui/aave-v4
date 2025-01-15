// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test, stdJson, Vm, console2 as console} from 'forge-std/Test.sol';
import {LiquidityHubHandler} from '../invariant/LiquidityHubHandler.t.sol';

contract ScenarioEngine is Test {
  using stdJson for string;
  LiquidityHubHandler internal handler;

  // constructor is equivalent is setUp()
  // todo: handlers should separate base deployment and handler setup in
  // constructor such that all handler's re-use the same base deployment
  constructor() {
    _initHandlers(); // and override base deployment
  }

  function test_hello() public {
    ScenarioData[] memory scenarios = _readScenarios();

    uint256 snapshot = vm.snapshotState();
    for (uint256 i; i < scenarios.length; ++i) {
      console.log(scenarios[i].title);
      console.log(scenarios[i].description);
      for (uint256 j; j < scenarios[i].stories.length; ++j) {
        _executeStory(scenarios[i].stories[j]);
      }
      vm.revertToState(snapshot);
    }
  }

  function _executeStory(Story memory story) internal {
    console.log(story.description);
    for (uint256 i; i < story.actions.length; ++i) {
      _executeAction(story.actions[i]);
    }
  }

  function _executeAction(Action memory action) internal {
    if (_isAction(action.name, ActionType.Mint)) {
      // handler.supply(action.userId, action.args[0], action.args[1]);
      console.log('Minting');
    } else if (_isAction(action.name, ActionType.Deposit)) {
      console.log('Depositing');
    } else if (_isAction(action.name, ActionType.Approve)) {
      console.log('Approving');
    }
  }

  function _isAction(string memory name, ActionType expected) internal view returns (bool) {
    if (expected == ActionType.Mint) {
      return keccak256(abi.encodePacked(name)) == keccak256(abi.encodePacked('mint'));
    } else if (expected == ActionType.Deposit) {
      return keccak256(abi.encodePacked(name)) == keccak256(abi.encodePacked('deposit'));
    } else if (expected == ActionType.Approve) {
      return keccak256(abi.encodePacked(name)) == keccak256(abi.encodePacked('approve'));
    }
  }

  function _initHandlers() internal {
    handler = new LiquidityHubHandler();
  }

  enum ActionType {
    Mint,
    Deposit,
    Approve
  }
  // keys need to be in alphabetical order
  struct Action {
    string[] args;
    string expected;
    string name;
    uint256 userId;
  }
  struct Story {
    Action[] actions;
    string description;
  }
  struct ScenarioData {
    string description;
    Story[] stories;
    string title;
  }
  function _readScenarios() internal view returns (ScenarioData[] memory scenarios) {
    Vm.DirEntry[] memory scenarioFiles = vm.readDir('tests/scenario/stories/');
    scenarios = new ScenarioData[](scenarioFiles.length);
    for (uint256 i; i < scenarioFiles.length; ++i) {
      if (bytes(scenarioFiles[i].errorMessage).length > 0) {
        revert(
          string.concat(
            'Failed to read file: ',
            scenarioFiles[i].path,
            ', with error: ',
            scenarioFiles[i].errorMessage
          )
        );
      }
      scenarios[i] = _readScenario(scenarioFiles[i].path);
    }
  }

  function _readScenario(string memory file) internal view returns (ScenarioData memory) {
    return abi.decode(vm.parseJson(vm.readFile(file)), (ScenarioData));
  }

  function whatItLooksLike(ScenarioData memory d) external {}
}
