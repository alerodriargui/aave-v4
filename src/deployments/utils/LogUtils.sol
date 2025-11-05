// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'forge-std/StdJson.sol';
import 'forge-std/Vm.sol';
import {console} from 'forge-std/console.sol';

contract LogUtils {
  using stdJson for string;

  struct AddressEntry {
    string label;
    address value;
  }

  struct ValueEntry {
    string label;
    uint256 value;
  }

  Vm private constant vm = Vm(address(bytes20(uint160(uint256(keccak256('hevm cheat code'))))));

  string internal _outputPath;
  string internal _root;

  constructor(string memory outputPath_) {
    _root = 'root';
    _outputPath = outputPath_;
  }

  function log(string memory label, address value) public view {
    _log(label, value);
  }

  function log(string memory label, uint256 value) public view {
    _log(label, value);
  }

  function log(string memory value) public view {
    _log(value);
  }

  function write(string memory label, address value) public {
    _write(label, value);
  }

  function write(string memory label, uint256 value) public {
    _write(label, value);
  }

  function write(string memory value) public {
    _write(value);
  }

  function writeGroup(string memory groupLabel, AddressEntry[] memory entries) public {
    _writeGroup(groupLabel, entries);
  }

  function writeGroup(string memory groupLabel, ValueEntry[] memory entries) public {
    _writeGroup(groupLabel, entries);
  }

  function save() public {
    console.log();
    console.log('Saving log to %s', _outputPath);
    console.log(_root);
    vm.writeJson(_root, _outputPath);
  }

  function _log(string memory label, address value) internal view {
    console.log('%s: %s', label, value);
  }

  function _log(string memory label, uint256 value) internal view {
    console.log('%s: %s', label, value);
  }

  function _log(string memory value) internal view {
    console.log(value);
  }

  function _write(string memory label, address value) internal {
    _log(label, value);
    _root = vm.serializeAddress(_root, label, value);
  }

  function _write(string memory label, uint256 value) internal {
    _log(label, value);
    _root = vm.serializeString(_root, label, vm.toString(value));
  }

  function _write(string memory value) internal {
    _log(value);
    _root = vm.serializeString(_root, 'message', value);
  }

  function _writeGroup(string memory groupLabel, AddressEntry[] memory entries) internal {
    string memory group;
    _log(groupLabel);
    for (uint256 i = 0; i < entries.length; i++) {
      _log(entries[i].label, entries[i].value);
      group = vm.serializeAddress(group, entries[i].label, entries[i].value);
    }
    _root = vm.serializeString(_root, groupLabel, group);
    console.log();
  }

  function _writeGroup(string memory groupLabel, ValueEntry[] memory entries) internal {
    string memory group;
    _log(groupLabel);
    for (uint256 i = 0; i < entries.length; i++) {
      _log(entries[i].label, entries[i].value);
      group = vm.serializeString(group, entries[i].label, vm.toString(entries[i].value));
    }
    _root = vm.serializeString(_root, groupLabel, group);
    console.log();
  }
}
