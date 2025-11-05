// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'forge-std/StdJson.sol';
import 'forge-std/Vm.sol';

contract DeployUtils {
  using stdJson for string;

  Vm private constant vm = Vm(address(bytes20(uint160(uint256(keccak256('hevm cheat code'))))));
}
