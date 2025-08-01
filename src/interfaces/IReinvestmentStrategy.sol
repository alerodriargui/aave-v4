// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.10;

/**
 * @title IReinvestmentStrategy
 * @author Aave Labs
 * @notice Basic interface for any reinvestment strategy.
 */
interface IReinvestmentStrategy {

  /**
   * @notice  notifies the reinvestment strategy that a sweep action happened. 
   * @param amount The amount sweeped.
   */
  function notifySweep(
    uint256 amount
  ) external;

  /**
   * @notice Reclaim an invested amount through the sweep() function. 
   * @param amount The amount to be reclaimed.
   * @return the amount that was returned to the Liquidity Hub.
   */
  function reclaim(
    uint256 amount
  ) external view returns (uint256);
}
