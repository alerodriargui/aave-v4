// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {BatchReports} from 'src/deployments/libraries/BatchReports.sol';
import {AaveV4TokenizationSpokeDeployProcedure} from 'src/deployments/procedures/deploy/spoke/AaveV4TokenizationSpokeDeployProcedure.sol';
import {ITokenizationSpoke} from 'src/spoke/interfaces/ITokenizationSpoke.sol';

contract AaveV4TokenizationSpokeBatch is AaveV4TokenizationSpokeDeployProcedure {
  BatchReports.TokenizationSpokeBatchReport internal _report;

  constructor(
    address hub_,
    uint256 assetId_,
    address spokeProxyAdminOwner_,
    string memory shareName_,
    string memory shareSymbol_,
    bytes32 salt_
  ) {
    (
      address tokenizationSpokeProxy,
      address tokenizationSpokeImplementation
    ) = _deployUpgradeableTokenizationSpokeInstance({
        hub: hub_,
        assetId: assetId_,
        spokeProxyAdminOwner: spokeProxyAdminOwner_,
        shareName: shareName_,
        shareSymbol: shareSymbol_,
        salt: salt_
      });

    require(
      ITokenizationSpoke(tokenizationSpokeProxy).hub() == hub_,
      'tokenization spoke hub mismatch'
    );
    require(
      ITokenizationSpoke(tokenizationSpokeProxy).assetId() == assetId_,
      'tokenization spoke assetId mismatch'
    );

    _report = BatchReports.TokenizationSpokeBatchReport({
      tokenizationSpokeImplementation: tokenizationSpokeImplementation,
      tokenizationSpokeProxy: tokenizationSpokeProxy
    });
  }

  function getReport() external view returns (BatchReports.TokenizationSpokeBatchReport memory) {
    return _report;
  }
}
