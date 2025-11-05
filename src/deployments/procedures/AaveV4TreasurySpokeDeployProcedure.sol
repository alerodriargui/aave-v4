// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {TreasurySpoke} from 'src/spoke/TreasurySpoke.sol';

contract AaveV4TreasurySpokeDeployProcedure {
  function _deployTreasurySpoke(address owner_, address hub_) internal returns (address) {
    address treasurySpoke = address(new TreasurySpoke(owner_, hub_));

    return treasurySpoke;
  }
}
