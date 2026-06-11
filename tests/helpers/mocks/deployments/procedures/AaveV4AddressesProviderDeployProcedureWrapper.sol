// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AaveV4AddressesProviderDeployProcedure} from 'src/deployments/procedures/deploy/addresses-provider/AaveV4AddressesProviderDeployProcedure.sol';

contract AaveV4AddressesProviderDeployProcedureWrapper is AaveV4AddressesProviderDeployProcedure {
  bool public IS_TEST = true;

  function deployAddressesProvider(
    address owner,
    bytes32 salt
  ) external returns (address, address) {
    return _deployAddressesProvider(owner, salt);
  }
}
