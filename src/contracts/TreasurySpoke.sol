// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Ownable} from 'src/dependencies/openzeppelin/Ownable.sol';
import {ITreasurySpoke} from 'src/interfaces/ITreasurySpoke.sol';
import {ILiquidityHub} from 'src/interfaces/ILiquidityHub.sol';

contract TreasurySpoke is Ownable, ITreasurySpoke {
  ILiquidityHub public immutable HUB;

  constructor(address owner, address hubAddress) Ownable(owner) {
    require(hubAddress != address(0), InvalidHubAddress());

    HUB = ILiquidityHub(hubAddress);
  }

  function supply(uint256 assetId, uint256 amount) external onlyOwner {
    HUB.add(assetId, amount, msg.sender);
  }

  function withdraw(uint256 assetId, uint256 amount, address to) external onlyOwner {
    // If uint256.max is passed, withdraw all supplied assets
    if (amount == type(uint256).max) {
      amount = HUB.getSpokeSuppliedAmount(assetId, address(this));
    }

    HUB.remove(assetId, amount, to);
  }

  function getSuppliedAmount(uint256 assetId) external view returns (uint256) {
    return HUB.getSpokeSuppliedAmount(assetId, address(this));
  }

  function gerSuppliedShares(uint256 assetId) external view returns (uint256) {
    return HUB.getSpokeSuppliedShares(assetId, address(this));
  }
}
