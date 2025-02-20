// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Arrays} from 'src/dependencies/openzeppelin/Arrays.sol';

type LiquidityPremiumWithId is bytes32;

function add(uint256 reserveId, uint256 liquidityPremium) returns (LiquidityPremiumWithId) {
  return LiquidityPremiumWithId.wrap(bytes32((uint256(reserveId) << 128) | liquidityPremium));
}

function _castToUint256Array(
  LiquidityPremiumWithId[] memory input
) returns (uint256[] memory output) {
  assembly {
    output := input
  }
}

library LiquidityPremiumWithIdHelper {}
