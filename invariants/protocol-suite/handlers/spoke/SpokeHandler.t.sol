// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Interfaces
import {ISpoke, ISpokeBase} from 'src/spoke/interfaces/ISpoke.sol';
import {ISpokeHandler} from '../interfaces/ISpokeHandler.sol';
import {IERC20} from 'src/dependencies/openzeppelin/IERC20.sol';

// Libraries
import {WadRayMath} from 'src/libraries/math/WadRayMath.sol';
import {MathUtils} from 'src/libraries/math/MathUtils.sol';
import {Constants} from 'tests/Constants.sol';

// Test Contracts
import {Actor} from '../../../shared/utils/Actor.sol';
import {BaseHandler} from '../../base/BaseHandler.t.sol';

/// @title SpokeHandler
/// @notice Handler test contract for a set of actions
contract SpokeHandler is BaseHandler, ISpokeHandler {
  using WadRayMath for uint256;
  using MathUtils for uint256;

  ///////////////////////////////////////////////////////////////////////////////////////////////
  //                                      STATE VARIABLES                                      //
  ///////////////////////////////////////////////////////////////////////////////////////////////

  struct LiquidationVars {
    // Spoke
    address violator;
    address liquidator;
    address spoke;
    address underlying;
    // Debt reserve
    uint256 debtReserveId;
    uint256 collateralReserveId;
    // Liquidation
    uint256 debtToCover;
    uint256 debtLiquidated;
    uint256 totalDebtValueBefore;
    // Liquidator
    uint256 liquidatorCollateralBalanceBefore;
    uint256 liquidatorCollateralBalanceAfter;
  }

  ///////////////////////////////////////////////////////////////////////////////////////////////
  //                                          ACTIONS                                          //
  ///////////////////////////////////////////////////////////////////////////////////////////////

  function supply(uint256 amount, uint8 i, uint8 j, uint8 k) external setup {
    bool success;
    bytes memory returnData;

    // Get one of the three actors randomly
    address onBehalfOf = _getRandomActor(i);

    address spoke = _getRandomSpoke(j);

    // Get one of the reserves IDs randomly
    uint256 reserveId = _getRandomReserveId(spoke, k);

    // Register user to check postconditions
    _registerUserToCheck(spoke, reserveId, onBehalfOf);

    _before();
    (success, returnData) = actor.proxy(
      spoke,
      abi.encodeCall(ISpokeBase.supply, (reserveId, amount, onBehalfOf))
    );

    if (success) {
      _after();
    } else {
      revert('SpokeHandler: supply failed');
    }
  }

  function withdraw(uint256 amount, uint8 i, uint8 j, uint8 k) external setup {
    bool success;
    bytes memory returnData;

    // Get one of the three actors randomly
    address onBehalfOf = _getRandomActor(i);

    address spoke = _getRandomSpoke(j);

    // Get one of the reserves IDs randomly
    uint256 reserveId = _getRandomReserveId(spoke, k);

    uint256 userAmount = ISpoke(spoke).getUserSuppliedAssets(reserveId, onBehalfOf);

    // Register user to check postconditions
    _registerUserToCheck(spoke, reserveId, onBehalfOf);

    _before();
    (success, returnData) = actor.proxy(
      spoke,
      abi.encodeCall(ISpokeBase.withdraw, (reserveId, amount, onBehalfOf))
    );

    // GPOST_SP_H: debt-free user with valid auth and unblocked reserve must be able to withdraw
    // todo make this "position healthy" after withdraw, add similar check on borrow
    if (
      _isAuthorized(spoke, onBehalfOf) &&
      !_isReserveActionBlocked(spoke, reserveId, false, false) &&
      _userVarsBefore(spoke, reserveId, onBehalfOf).debt.owed == 0 &&
      amount > 0 &&
      userAmount != 0
    ) {
      assertTrue(success, GPOST_SP_H);
    }

    if (success) {
      _after();
    } else {
      revert('SpokeHandler: withdraw failed');
    }
  }

  function borrow(uint256 amount, uint8 i, uint8 j, uint8 k) external setup {
    bool success;
    bytes memory returnData;

    // Get one of the three actors randomly
    address onBehalfOf = _getRandomActor(i);

    address spoke = _getRandomSpoke(j);

    // Get one of the reserves IDs randomly
    uint256 reserveId = _getRandomReserveId(spoke, k);

    // Register user to check postconditions
    _registerUserToCheck(spoke, reserveId, onBehalfOf);

    // Check if user is healthy
    bool isHealthy = _isHealthy(spoke, onBehalfOf);

    _before();
    (success, returnData) = actor.proxy(
      spoke,
      abi.encodeCall(ISpokeBase.borrow, (reserveId, amount, onBehalfOf))
    );

    if (success) {
      _after();

      ///// HSPOST /////

      assertTrue(isHealthy, HSPOST_SP_D);
    } else {
      revert('SpokeHandler: borrow failed');
    }
  }

  function repay(uint256 amount, uint8 i, uint8 j, uint8 k) external setup {
    bool success;
    bytes memory returnData;

    // Get one of the three actors randomly
    address onBehalfOf = _getRandomActor(i);

    address spoke = _getRandomSpoke(j);

    // Get one of the reserves IDs randomly
    uint256 reserveId = _getRandomReserveId(spoke, k);

    // Register user to check postconditions
    _registerUserToCheck(spoke, reserveId, onBehalfOf);

    _before();
    (success, returnData) = actor.proxy(
      spoke,
      abi.encodeCall(ISpokeBase.repay, (reserveId, amount, onBehalfOf))
    );

    if (success) {
      _after();

      ///// HSPOST /////

      assertLe(
        _userVarsAfter(spoke, reserveId, onBehalfOf).debt.owed,
        _userVarsBefore(spoke, reserveId, onBehalfOf).debt.owed,
        HSPOST_SP_C
      );
    } else {
      revert('SpokeHandler: repay failed');
    }
  }

  function liquidationCall(
    uint256 debtToCover,
    bool receiveShares,
    uint8 i,
    uint8 j,
    uint8 k,
    uint8 l
  ) external setup {
    bool success;
    bytes memory returnData;

    LiquidationVars memory liquidationVars;

    // Get one of the three actors randomly
    liquidationVars.spoke = _getRandomSpoke(j);
    liquidationVars.debtToCover = debtToCover;

    liquidationVars.violator = _getRandomActor(i);
    liquidationVars.liquidator = address(actor);

    // Get both reserves IDs randomly and the collateral underlying asset
    liquidationVars.collateralReserveId = _getRandomReserveId(liquidationVars.spoke, k);
    liquidationVars.debtReserveId = _getRandomReserveId(liquidationVars.spoke, l);
    liquidationVars.underlying = ISpoke(liquidationVars.spoke)
      .getReserve(liquidationVars.collateralReserveId)
      .underlying;

    uint256 violatorCollateralBalanceBefore = ISpoke(liquidationVars.spoke).getUserSuppliedAssets(
      liquidationVars.collateralReserveId,
      liquidationVars.violator
    );

    liquidationVars.totalDebtValueBefore = ISpoke(liquidationVars.spoke)
      .getUserAccountData(liquidationVars.violator)
      .totalDebtValueRay
      .fromRayUp();

    if (receiveShares) {
      liquidationVars.liquidatorCollateralBalanceBefore = ISpoke(liquidationVars.spoke)
        .getUserSuppliedAssets(liquidationVars.collateralReserveId, address(actor));
    } else {
      liquidationVars.liquidatorCollateralBalanceBefore = IERC20(liquidationVars.underlying)
        .balanceOf(address(actor));
    }

    // Register users to check postconditions: liquidated user and liquidator for both reserves
    _registerUserToCheck(
      liquidationVars.spoke,
      liquidationVars.debtReserveId,
      liquidationVars.violator
    );
    _registerUserToCheck(
      liquidationVars.spoke,
      liquidationVars.collateralReserveId,
      liquidationVars.violator
    );
    _registerUserToCheck(
      liquidationVars.spoke,
      liquidationVars.debtReserveId,
      liquidationVars.liquidator
    );
    _registerUserToCheck(
      liquidationVars.spoke,
      liquidationVars.collateralReserveId,
      liquidationVars.liquidator
    );

    _before();
    (success, returnData) = actor.proxy(
      liquidationVars.spoke,
      abi.encodeCall(
        ISpokeBase.liquidationCall,
        (
          liquidationVars.collateralReserveId,
          liquidationVars.debtReserveId,
          liquidationVars.violator,
          liquidationVars.debtToCover,
          receiveShares
        )
      )
    );

    if (success) {
      _after();

      // Calculate the debt liquidated from user-level snapshots (not reserve-level, which
      // includes interest accrual on other users' debt and would be inaccurate)
      UserVars memory violatorDebtVarsBefore = _userVarsBefore(
        liquidationVars.spoke,
        liquidationVars.debtReserveId,
        liquidationVars.violator
      );
      UserVars memory violatorDebtVarsAfter = _userVarsAfter(
        liquidationVars.spoke,
        liquidationVars.debtReserveId,
        liquidationVars.violator
      );
      liquidationVars.debtLiquidated = violatorDebtVarsBefore.debt.owed.zeroFloorSub(
        violatorDebtVarsAfter.debt.owed
      );

      if (receiveShares) {
        liquidationVars.liquidatorCollateralBalanceAfter = ISpoke(liquidationVars.spoke)
          .getUserSuppliedAssets(liquidationVars.collateralReserveId, address(actor));
      } else {
        liquidationVars.liquidatorCollateralBalanceAfter = IERC20(liquidationVars.underlying)
          .balanceOf(address(actor));
      }

      ///// HSPOST /////
      assertLe(liquidationVars.debtLiquidated, violatorDebtVarsBefore.debt.owed, HSPOST_SP_LIQ_A);

      if (
        liquidationVars.liquidatorCollateralBalanceAfter >
        liquidationVars.liquidatorCollateralBalanceBefore
      ) {
        assertLe(
          liquidationVars.liquidatorCollateralBalanceAfter -
            liquidationVars.liquidatorCollateralBalanceBefore,
          violatorCollateralBalanceBefore,
          HSPOST_SP_LIQ_B
        );
      }

      if (liquidationVars.totalDebtValueBefore < Constants.DUST_LIQUIDATION_THRESHOLD) {
        assertEq(violatorDebtVarsAfter.debt.owed, 0, HSPOST_SP_LIQ_C);
      }

      assertGe(liquidationVars.debtToCover, liquidationVars.debtLiquidated, HSPOST_SP_LIQ_D);

      assertLt(
        _userAccountDataVarsBefore(liquidationVars.spoke, liquidationVars.violator)
          .data
          .healthFactor,
        Constants.HEALTH_FACTOR_LIQUIDATION_THRESHOLD,
        HSPOST_SP_LIQ_E
      );

      if (violatorDebtVarsAfter.debt.owed > 0) {
        assertGt(
          _userAccountDataVarsAfter(liquidationVars.spoke, liquidationVars.violator)
            .data
            .healthFactor,
          _userAccountDataVarsBefore(liquidationVars.spoke, liquidationVars.violator)
            .data
            .healthFactor,
          HSPOST_SP_LIQ_G
        );
      }
    } else {
      revert('SpokeHandler: liquidationCall failed');
    }
  }

  function setUsingAsCollateral(bool usingAsCollateral, uint8 i, uint8 j) external setup {
    bool success;
    bytes memory returnData;

    address onBehalfOf = address(actor);

    address spoke = _getRandomSpoke(i);

    uint256 reserveId = _getRandomReserveId(spoke, j);

    (bool isUsingAsCollateral, ) = ISpoke(spoke).getUserReserveStatus(reserveId, onBehalfOf);
    // !todo remove this
    require(
      usingAsCollateral != isUsingAsCollateral,
      'SpokeHandler: usingAsCollateral already set'
    );

    // Register user to check postconditions
    /// @dev setUsingAsCollateral(reserveId, FALSE) all reserves in user position should be refreshed,
    ///      so we check all reserves in user position
    ///      setUsingAsCollateral(reserveId, TRUE) only reserveId in user position should be refreshed,
    ///      so we check only the reserveId in user position
    _registerUserToCheck(spoke, (usingAsCollateral ? reserveId : CHECK_ALL_RESERVES), onBehalfOf);

    _before();
    (success, returnData) = actor.proxy(
      spoke,
      abi.encodeCall(ISpoke.setUsingAsCollateral, (reserveId, usingAsCollateral, onBehalfOf))
    );

    if (success) {
      _after();
    } else {
      revert('SpokeHandler: setUsingAsCollateral failed');
    }
  }

  function updateUserRiskPremium(uint8 i) external setup {
    bool success;
    bytes memory returnData;

    address onBehalfOf = address(actor);

    address spoke = _getRandomSpoke(i);

    // Register user to check postconditions
    _registerUserToCheck(spoke, CHECK_ALL_RESERVES, onBehalfOf);

    _before();
    (success, returnData) = actor.proxy(
      spoke,
      abi.encodeCall(ISpoke.updateUserRiskPremium, (onBehalfOf))
    );

    if (success) {
      _after();
      ///// HSPOST /////
      uint256 reserveCount = ISpoke(spoke).getReserveCount();
      for (uint256 j; j < reserveCount; j++) {
        UserVars memory varsBefore = _userVarsBefore(spoke, j, onBehalfOf);
        UserVars memory varsAfter = _userVarsAfter(spoke, j, onBehalfOf);
        assertEq(varsBefore.debt.premium, varsAfter.debt.premium, HSPOST_HUB_M); // !todo add premium ray in those getters and check that here?
        assertEq(varsBefore.debt.owed, varsAfter.debt.owed, HSPOST_SP_F);
      }
    } else {
      revert('SpokeHandler: updateUserRiskPremium failed');
    }
  }

  function updateUserDynamicConfig(uint8 i) external setup {
    bool success;
    bytes memory returnData;

    address onBehalfOf = address(actor);

    address spoke = _getRandomSpoke(i);

    _registerUserToCheck(spoke, CHECK_ALL_RESERVES, onBehalfOf);

    _before();
    (success, returnData) = actor.proxy(
      spoke,
      abi.encodeCall(ISpoke.updateUserDynamicConfig, (onBehalfOf))
    );

    if (success) {
      _after();
    } else {
      revert('SpokeHandler: updateUserDynamicConfig failed');
    }
  }

  // todo add updateUserPositionManager
  // todo check decoded returnData

  ///////////////////////////////////////////////////////////////////////////////////////////////
  //                                         OWNER ACTIONS                                     //
  ///////////////////////////////////////////////////////////////////////////////////////////////

  ///////////////////////////////////////////////////////////////////////////////////////////////
  //                                           HELPERS                                         //
  ///////////////////////////////////////////////////////////////////////////////////////////////
}
