/**
 * @title Spoke Health Factor Specification
 * @notice Verify that the health factor is above threshold after any operation
 * @dev Symbolic representation of the total collateral value and total debt value.
 * The health factor is calculated as the total collateral value divided by the total debt value.
 *
 * To run this spec:
 * certoraRun certora/conf/SpokeHealthCheck_take2.conf
 */

import "./SpokeBaseSummaries.spec";
import "./symbolicRepresentation/SymbolicHub.spec";

using SpokeInstance as spoke;

////////////////////////////////////////////////////////////////////////////
//                                METHODS                                 //
////////////////////////////////////////////////////////////////////////////

methods {
    // Position status methods are imported from SymbolicPositionStatus.spec
    function Spoke._processUserAccountData(address user, bool refreshConfig) internal returns (ISpoke.UserAccountData memory) => processUserAccountDataCVL(user, refreshConfig);

    function _.setBorrowing(ISpoke.PositionStatus storage positionStatus, uint256 reserveId, bool borrowing) internal => NONDET;

    function _.setUsingAsCollateral(ISpoke.PositionStatus storage positionStatus, uint256 reserveId, bool usingAsCollateral) internal => setUsingAsCollateralCVL_updateTotals(reserveId, usingAsCollateral) expect void;

    function _.isUsingAsCollateralOrBorrowing(ISpoke.PositionStatus storage positionStatus, uint256 reserveId) internal => NONDET;

    function _.isBorrowing(ISpoke.PositionStatus storage positionStatus, uint256 reserveId) internal => NONDET;

    function _.isUsingAsCollateral(ISpoke.PositionStatus storage positionStatus, uint256 reserveId) internal => isUsingAsCollateralCVL(reserveId) expect bool;

    function _.collateralCount(ISpoke.PositionStatus storage positionStatus, uint256 reserveCount) internal => NONDET;

    function _.next(ISpoke.PositionStatus storage positionStatus, uint256 startReserveId) internal => NONDET;

    function _.nextBorrowing(ISpoke.PositionStatus storage positionStatus, uint256 startReserveId) internal => nextBorrowingCVL(startReserveId) expect uint256;

    function _.nextCollateral(ISpoke.PositionStatus storage positionStatus, uint256 startReserveId) internal => NONDET;

    // proved in Spoke.spec : updateUserRiskPremium_preservesPremiumDebt that this function preserves debt
    function _.notifyRiskPremiumUpdate(address user, uint256 newRiskPremium) internal => NONDET;
}

////////////////////////////////////////////////////////////////////////////
//                                 GHOSTS                                 //
////////////////////////////////////////////////////////////////////////////

persistent ghost mapping(mathint /* totalCollateralValue */ => mapping(mathint /* totalDebtValue */ => uint256 /* healthFactor */)) ghostHealthFactor {
    init_state axiom forall mathint totalCollateralValue. forall mathint totalDebtValue. ghostHealthFactor[totalCollateralValue][totalDebtValue] == 0;
    axiom forall mathint totalCollateralValue. forall mathint totalDebtValue. totalDebtValue > 0 ? ghostHealthFactor[totalCollateralValue][totalDebtValue] == totalCollateralValue / totalDebtValue : ghostHealthFactor[totalCollateralValue][totalDebtValue] == max_uint256;
}

ghost mathint totalCollateralValueGhost;

ghost mathint totalDebtValueGhost;

ghost uint256 currentTime;

ghost address currentUser;

ghost uint256 debtReserveId_1;

ghost uint256 debtReserveId_2;

ghost uint256 debtReserveId_3;

ghost uint256 collateralReserveId_1;

ghost uint256 collateralReserveId_2;

ghost uint256 collateralReserveId_3;

ghost mapping(uint256 /*reserveId*/ => bool /*usingAsCollateral*/) isUsingAsCollateral {
    init_state axiom forall uint256 reserveId. !isUsingAsCollateral[reserveId];
}

ghost mathint activeCollateralCountGhost;

////////////////////////////////////////////////////////////////////////////
//                              DEFINITIONS                               //
////////////////////////////////////////////////////////////////////////////

definition knownDebtReserveIds(uint256 reserveId) returns bool =
    reserveId == debtReserveId_1 || reserveId == debtReserveId_2 || reserveId == debtReserveId_3;

definition knownCollateralReserveIds(uint256 reserveId) returns bool =
    reserveId == collateralReserveId_1 || reserveId == collateralReserveId_2 || reserveId == collateralReserveId_3;

definition HEALTH_FACTOR_LIQUIDATION_THRESHOLD() returns uint256 = 10 ^ 18;

// definition of function that should revert if the health factor is below the threshold
definition belowThresholdRevertingFunctions(method f) returns bool =
    f.selector == sig:updateUserDynamicConfig(address).selector ||
    f.selector == sig:borrow(uint256, uint256, address).selector;

////////////////////////////////////////////////////////////////////////////
//                              FUNCTIONS                                 //
////////////////////////////////////////////////////////////////////////////

function setUsingAsCollateralCVL_updateTotals(uint256 reserveId, bool usingAsCollateral) {
    uint256 assetId = spoke._reserves[reserveId].assetId;
    require knownCollateralReserveIds(reserveId);
    mathint currValue = collateralIDValue(reserveId);
    if (isUsingAsCollateral[reserveId] && !usingAsCollateral) {
        totalCollateralValueGhost = totalCollateralValueGhost - currValue;
    } else if (!isUsingAsCollateral[reserveId] && usingAsCollateral) {
        totalCollateralValueGhost = totalCollateralValueGhost + currValue;
    }
    isUsingAsCollateral[reserveId] = usingAsCollateral;
}

function isUsingAsCollateralCVL(uint256 reserveId) returns (bool) {
    return isUsingAsCollateral[reserveId];
}

function processUserAccountDataCVL(address user, bool refreshConfig) returns (ISpoke.UserAccountData) {
    ISpoke.UserAccountData userAccountData;
    require userAccountData.healthFactor == ghostHealthFactor[totalCollateralValueGhost][totalDebtValueGhost];
    activeCollateralCountGhost = 0;
    if (collateralIDValue(collateralReserveId_1) > 0) {
        activeCollateralCountGhost = activeCollateralCountGhost + 1;
    }
    if (collateralIDValue(collateralReserveId_2) > 0) {
        activeCollateralCountGhost = activeCollateralCountGhost + 1;
    }
    if (collateralIDValue(collateralReserveId_3) > 0) {
        activeCollateralCountGhost = activeCollateralCountGhost + 1;
    }
    require userAccountData.activeCollateralCount == activeCollateralCountGhost;
    return userAccountData;
}

function collateralIDValue(uint256 reserveId) returns (mathint) {
    uint256 assetId = spoke._reserves[reserveId].assetId;
    return spoke._userPositions[currentUser][reserveId].suppliedShares * shareToAssetsRatio[assetId][currentTime] * symbolicPrice(reserveId, currentTime);
}

function nextBorrowingCVL(uint256 startReserveId) returns (uint256) {
    if (startReserveId > collateralReserveId_1 && collateralIDValue(collateralReserveId_1) > 0) {
        return collateralReserveId_1;
    }
    if (startReserveId > collateralReserveId_2 && collateralIDValue(collateralReserveId_2) > 0) {
        return collateralReserveId_2;
    }
    if (startReserveId > collateralReserveId_3 && collateralIDValue(collateralReserveId_3) > 0) {
        return collateralReserveId_3;
    }
    return max_uint256;
}

function validReserveId_singleUser(uint256 reserveId) {
    require
    (reserveId < spoke._reserveCount =>
    // has underlying and hub
    (spoke._reserves[reserveId].underlying != 0 && spoke._reserves[reserveId].hub != 0 && spoke._hubAssetIdToReserveId[spoke._reserves[reserveId].hub][spoke._reserves[reserveId].assetId] != 0))
    &&
    // not exists
    (reserveId >= spoke._reserveCount =>
    // has no underlying, hub, assetId
    spoke._reserves[reserveId].underlying == 0 && spoke._reserves[reserveId].assetId == 0 && spoke._reserves[reserveId].hub == 0 && spoke._reserves[reserveId].dynamicConfigKey == 0 && spoke._reserves[reserveId].flags == 0 && spoke._reserves[reserveId].collateralRisk == 0 &&
    spoke._dynamicConfig[reserveId][0].collateralFactor == 0 &&
    // not used as collateral
    !isUsingAsCollateral[reserveId] &&
    // no supplied or drawn shares
    spoke._userPositions[currentUser][reserveId].suppliedShares == 0 && spoke._userPositions[currentUser][reserveId].drawnShares == 0 &&
    // no premium shares or offset
    spoke._userPositions[currentUser][reserveId].premiumShares == 0 && spoke._userPositions[currentUser][reserveId].premiumOffsetRay == 0);
}

function drawnSharesRiskLEPremiumShares(uint256 reserveId) {
    require (spoke._userPositions[currentUser][reserveId].drawnShares * spoke._positionStatus[currentUser].riskPremium + PERCENTAGE_FACTOR - 1) / PERCENTAGE_FACTOR == spoke._userPositions[currentUser][reserveId].premiumShares;
}

function drawnSharesZero(uint256 reserveId) {
    require spoke._userPositions[currentUser][reserveId].drawnShares == 0 => (spoke._userPositions[currentUser][reserveId].premiumShares == 0 && spoke._userPositions[currentUser][reserveId].premiumOffsetRay == 0);
}

function setUpForOne(uint256 reserveID) {
    drawnSharesRiskLEPremiumShares(reserveID);
    drawnSharesZero(reserveID);
    validReserveId_singleUser(reserveID);
}

function setup() {
    setUpForOne(debtReserveId_1);
    setUpForOne(debtReserveId_2);
    setUpForOne(debtReserveId_3);
}

////////////////////////////////////////////////////////////////////////////
//                                 HOOKS                                  //
////////////////////////////////////////////////////////////////////////////

hook Sstore _userPositions[KEY address user][KEY uint256 reserveId].drawnShares uint120 newValue (uint120 oldValue) {
    require knownDebtReserveIds(reserveId);
    uint256 assetId = spoke._reserves[reserveId].assetId;
    totalDebtValueGhost = totalDebtValueGhost + (
        (newValue - oldValue) * indexOfAssetPerBlock[assetId][currentTime] * symbolicPrice(reserveId, currentTime));
}

hook Sload uint120 value _userPositions[KEY address user][KEY uint256 reserveId].drawnShares {
    require knownDebtReserveIds(reserveId);
    uint256 assetId = spoke._reserves[reserveId].assetId;
    require totalDebtValueGhost >=
        value * indexOfAssetPerBlock[assetId][currentTime] * symbolicPrice(reserveId, currentTime);
}

hook Sstore _userPositions[KEY address user][KEY uint256 reserveId].suppliedShares uint120 newValue (uint120 oldValue) {
    require knownCollateralReserveIds(reserveId);
    if (isUsingAsCollateral[reserveId]) {
        uint256 assetId = spoke._reserves[reserveId].assetId;
        totalCollateralValueGhost = totalCollateralValueGhost + (
            (newValue - oldValue) * shareToAssetsRatio[assetId][currentTime] * symbolicPrice(reserveId, currentTime));
    }
}

hook Sload uint120 value _userPositions[KEY address user][KEY uint256 reserveId].suppliedShares {
    require knownCollateralReserveIds(reserveId);
    if (isUsingAsCollateral[reserveId]) {
        uint256 assetId = spoke._reserves[reserveId].assetId;
        require totalCollateralValueGhost >=
            value * shareToAssetsRatio[assetId][currentTime] * symbolicPrice(reserveId, currentTime);
    }
}

hook Sstore _userPositions[KEY address user][KEY uint256 reserveId].premiumShares uint120 newValue (uint120 oldValue) {
    require knownDebtReserveIds(reserveId);
    uint256 assetId = spoke._reserves[reserveId].assetId;
    totalDebtValueGhost = totalDebtValueGhost + (
        (newValue - oldValue) * indexOfAssetPerBlock[assetId][currentTime] * symbolicPrice(reserveId, currentTime));
}

hook Sload uint120 value _userPositions[KEY address user][KEY uint256 reserveId].premiumShares {
    require knownDebtReserveIds(reserveId);
    uint256 assetId = spoke._reserves[reserveId].assetId;
    require totalDebtValueGhost >=
        (value * indexOfAssetPerBlock[assetId][currentTime] - spoke._userPositions[currentUser][reserveId].premiumOffsetRay) * symbolicPrice(reserveId, currentTime);
}

hook Sstore _userPositions[KEY address user][KEY uint256 reserveId].premiumOffsetRay int200 newValue (int200 oldValue) {
    require knownDebtReserveIds(reserveId);
    totalDebtValueGhost = totalDebtValueGhost - ((newValue - oldValue) * symbolicPrice(reserveId, currentTime));
}

hook Sload int200 value _userPositions[KEY address user][KEY uint256 reserveId].premiumOffsetRay {
    require knownDebtReserveIds(reserveId);
    uint256 assetId = spoke._reserves[reserveId].assetId;
    require totalDebtValueGhost >=
        (value * indexOfAssetPerBlock[assetId][currentTime] - value) * symbolicPrice(reserveId, currentTime);
}

////////////////////////////////////////////////////////////////////////////
//                                 RULES                                  //
////////////////////////////////////////////////////////////////////////////

/**
 * @title Functions revert when health factor is below threshold
 * @link_property Health check validity
 */
rule belowThresholdReverting(method f) filtered {f -> belowThresholdRevertingFunctions(f)} {
    env e;
    calldataarg args;
    setup();
    require currentTime == e.block.timestamp;
    require totalCollateralValueGhost >= 0 && totalDebtValueGhost >= 0;
    require ghostHealthFactor[totalCollateralValueGhost][totalDebtValueGhost] < HEALTH_FACTOR_LIQUIDATION_THRESHOLD();
    f@withrevert(e, args);
    assert lastReverted;
}

/**
 * @title Verify that the health factor can only increase if the health factor is below the threshold
 * @link_property Health check validity
 */
rule userHealthBelowThresholdCanOnlyIncreaseHealthFactor(method f) filtered {f -> !f.isView && !outOfScopeFunctions(f) && !belowThresholdRevertingFunctions(f)} {
    env e;
    setup();
    require currentTime == e.block.timestamp;
    require totalCollateralValueGhost >= 0 && totalDebtValueGhost >= 0;
    uint256 healthFactorBefore = ghostHealthFactor[totalCollateralValueGhost][totalDebtValueGhost];
    require ghostHealthFactor[totalCollateralValueGhost][totalDebtValueGhost] < HEALTH_FACTOR_LIQUIDATION_THRESHOLD();

    calldataarg args;
    if (f.selector == sig:setUsingAsCollateral(uint256, bool, address).selector) {
        uint256 reserveId;
        bool usingAsCollateral;
        setUsingAsCollateral(e, reserveId, usingAsCollateral, currentUser);
    }
    f(e, args);

    require totalCollateralValueGhost >= 0 && totalDebtValueGhost >= 0;
    assert healthFactorBefore <= ghostHealthFactor[totalCollateralValueGhost][totalDebtValueGhost];
}

/**
 * @title Verify that the health factor is above the threshold after any operation
 * @notice Excludes setUsingAsCollateral and borrow functions due to timeouts 
 * @link_property Health check validity
 */
rule userHealthAboveThreshold(method f) filtered {f -> !f.isView && !outOfScopeFunctions(f) && f.selector != sig:setUsingAsCollateral(uint256, bool, address).selector && f.selector != sig:borrow(uint256, uint256, address).selector} {
    env e;
    setup();
    require currentTime == e.block.timestamp;
    require totalCollateralValueGhost >= 0 && totalDebtValueGhost >= 0;
    require ghostHealthFactor[totalCollateralValueGhost][totalDebtValueGhost] >= HEALTH_FACTOR_LIQUIDATION_THRESHOLD();

    calldataarg args;
    f(e, args);

    require totalCollateralValueGhost >= 0 && totalDebtValueGhost >= 0;
    assert ghostHealthFactor[totalCollateralValueGhost][totalDebtValueGhost] >= HEALTH_FACTOR_LIQUIDATION_THRESHOLD();
}
