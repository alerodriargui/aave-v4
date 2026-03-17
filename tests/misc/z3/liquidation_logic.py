# Z3 proofs for liquidation logic invariants.
#
# Usage: python liquidation_logic.py <collateralDecimals> <debtDecimals>
#
# Checks:
#   1. Liquidation bonus monotonicity: the recalculated drawn shares cannot increase as the
#      liquidation bonus increases.
#   2. Collateral equivalence: the inline collateral-shares-to-liquidate calculation
#      produces the same result as the partial inline form (see _calculateCollateralToLiquidate).
#   3. Bounded recalculation: when debt is recalculated (with no liquidation bonus),
#      the recalculated drawn shares cannot exceed the user's total drawn shares.
from commons import *

s = Solver()

# Arguments
collateralAssetDecimals = int(sys.argv[1])
debtAssetDecimals = int(sys.argv[2])

# Constants
collateralAssetUnit = int(10**collateralAssetDecimals)
debtAssetUnit = int(10**debtAssetDecimals)

# Pricing of collateral asset
addedShares = Int("addedShares")
totalAddedAssets = Int("totalAddedAssets")
collateralAssetPrice = Int("collateralAssetPrice")
s.add(0 <= addedShares, addedShares <= MAX_SUPPLY_AMOUNT)
s.add(
    (addedShares + VIRTUAL_SHARES) <= (totalAddedAssets + VIRTUAL_ASSETS),
    (totalAddedAssets + VIRTUAL_ASSETS)
    <= MAX_SUPPLY_PRICE * (addedShares + VIRTUAL_SHARES),
)
s.add(MIN_PRICE <= collateralAssetPrice, collateralAssetPrice <= MAX_PRICE)

# Pricing of debt asset
drawnIndex = Int("drawnIndex")
debtAssetPrice = Int("debtAssetPrice")
s.add(MIN_DRAWN_INDEX <= drawnIndex, drawnIndex <= MAX_DRAWN_INDEX)
s.add(MIN_PRICE <= debtAssetPrice, debtAssetPrice <= MAX_PRICE)

# Liquidatable user position
suppliedShares = Int("suppliedShares")
drawnShares = Int("drawnShares")
premiumDebtRay = Int("premiumDebtRay")
s.add(1 <= suppliedShares, suppliedShares <= addedShares)
s.add(1 <= drawnShares, drawnShares <= MAX_SUPPLY_AMOUNT)
s.add(0 <= premiumDebtRay, premiumDebtRay <= MAX_SUPPLY_AMOUNT)

# Liquidation parameters
liquidationBonus = Int("liquidationBonus")
liquidationBonus2 = Int("liquidationBonus2")
s.add(
    MIN_LIQUIDATION_BONUS <= liquidationBonus,
    liquidationBonus <= MAX_LIQUIDATION_BONUS,
)
s.add(
    MIN_LIQUIDATION_BONUS <= liquidationBonus2,
    liquidationBonus2 <= MAX_LIQUIDATION_BONUS,
)

# Liquidation debt amounts
rawPremiumDebtRayToLiquidate = Int("rawPremiumDebtRayToLiquidate")
rawDrawnSharesToLiquidate = Int("rawDrawnSharesToLiquidate")
drawnSharesToLiquidate = Int("drawnSharesToLiquidate")
premiumDebtRayToLiquidate = Int("premiumDebtRayToLiquidate")
s.add(
    0 <= rawPremiumDebtRayToLiquidate,
    rawPremiumDebtRayToLiquidate <= premiumDebtRay,
)
s.add(0 <= rawDrawnSharesToLiquidate, rawDrawnSharesToLiquidate <= drawnShares)
s.add(
    Or(
        rawDrawnSharesToLiquidate == 0,
        rawPremiumDebtRayToLiquidate == premiumDebtRay,
    )
)
s.add(Or(rawDrawnSharesToLiquidate > 0, rawPremiumDebtRayToLiquidate > 0))

# Enforce debt dust condition
debtRayRemaining = (
    (drawnShares - rawDrawnSharesToLiquidate) * drawnIndex
    + premiumDebtRay
    - rawPremiumDebtRayToLiquidate
)
leavesDebtDust = And(
    rawDrawnSharesToLiquidate < drawnShares,
    toValue(
        debtRayRemaining,
        debtAssetDecimals,
        debtAssetPrice,
    )
    < DEBT_DUST_LIQUIDATION_THRESHOLD * RAY,
)
s.add(
    Or(
        And(
            Not(leavesDebtDust),
            drawnSharesToLiquidate == rawDrawnSharesToLiquidate,
            premiumDebtRayToLiquidate == rawPremiumDebtRayToLiquidate,
        ),
        And(
            leavesDebtDust,
            drawnSharesToLiquidate == drawnShares,
            premiumDebtRayToLiquidate == premiumDebtRay,
        ),
    )
)

# Calculate collateral shares to liquidate (inline calculation)
#  with liquidationBonus
collateralSharesToLiquidate = mulDivDown(
    drawnSharesToLiquidate * drawnIndex + premiumDebtRayToLiquidate,
    debtAssetPrice
    * collateralAssetUnit
    * liquidationBonus
    * (addedShares + VIRTUAL_SHARES),
    debtAssetUnit
    * collateralAssetPrice
    * PERCENTAGE_FACTOR
    * RAY
    * (totalAddedAssets + VIRTUAL_ASSETS),
)
#  with liquidationBonus2
collateralSharesToLiquidate2 = mulDivDown(
    drawnSharesToLiquidate * drawnIndex + premiumDebtRayToLiquidate,
    debtAssetPrice
    * collateralAssetUnit
    * liquidationBonus2
    * (addedShares + VIRTUAL_SHARES),
    debtAssetUnit
    * collateralAssetPrice
    * PERCENTAGE_FACTOR
    * RAY
    * (totalAddedAssets + VIRTUAL_ASSETS),
)
#  with 0 liquidation bonus
collateralSharesToLiquidate0 = mulDivDown(
    drawnSharesToLiquidate * drawnIndex + premiumDebtRayToLiquidate,
    debtAssetPrice * collateralAssetUnit * (addedShares + VIRTUAL_SHARES),
    debtAssetUnit * collateralAssetPrice * RAY * (totalAddedAssets + VIRTUAL_ASSETS),
)


# Recalculate debt to liquidate (conditions to trigger this will follow below)
#  with liquidationBonus
recalculatedDebtRayToLiquidated = mulDivUp(
    suppliedShares,
    collateralAssetPrice
    * debtAssetUnit
    * PERCENTAGE_FACTOR
    * RAY
    * (totalAddedAssets + VIRTUAL_ASSETS),
    debtAssetPrice
    * collateralAssetUnit
    * liquidationBonus
    * (addedShares + VIRTUAL_SHARES),
)
recalculatedDrawnSharesToLiquidate = divUp(
    recalculatedDebtRayToLiquidated - premiumDebtRay, drawnIndex
)
#  with liquidationBonus2
recalculatedDebtRayToLiquidated2 = mulDivUp(
    suppliedShares,
    collateralAssetPrice
    * debtAssetUnit
    * PERCENTAGE_FACTOR
    * RAY
    * (totalAddedAssets + VIRTUAL_ASSETS),
    debtAssetPrice
    * collateralAssetUnit
    * liquidationBonus2
    * (addedShares + VIRTUAL_SHARES),
)
recalculatedDrawnSharesToLiquidate2 = divUp(
    recalculatedDebtRayToLiquidated2 - premiumDebtRay, drawnIndex
)
#  with 0 liquidation bonus
recalculatedDebtRayToLiquidated0 = mulDivUp(
    suppliedShares,
    collateralAssetPrice * debtAssetUnit * RAY * (totalAddedAssets + VIRTUAL_ASSETS),
    debtAssetPrice * collateralAssetUnit * (addedShares + VIRTUAL_SHARES),
)
recalculatedDrawnSharesToLiquidate0 = divUp(
    recalculatedDebtRayToLiquidated0 - premiumDebtRay, drawnIndex
)

# Leaves collateral dust
#  with liquidationBonus
leavesCollateralDust = And(
    collateralSharesToLiquidate < suppliedShares,
    toValue(
        previewRemoveByShares(
            suppliedShares - collateralSharesToLiquidate,
            totalAddedAssets,
            addedShares,
        ),
        collateralAssetDecimals,
        collateralAssetPrice,
    )
    < COLLATERAL_DUST_LIQUIDATION_THRESHOLD,
)
#  with liquidationBonus2
leavesCollateralDust2 = And(
    collateralSharesToLiquidate2 < suppliedShares,
    toValue(
        previewRemoveByShares(
            suppliedShares - collateralSharesToLiquidate2,
            totalAddedAssets,
            addedShares,
        ),
        collateralAssetDecimals,
        collateralAssetPrice,
    )
    < COLLATERAL_DUST_LIQUIDATION_THRESHOLD,
)
#  with 0 liquidation bonus
leavesCollateralDust0 = And(
    collateralSharesToLiquidate0 < suppliedShares,
    toValue(
        previewRemoveByShares(
            suppliedShares - collateralSharesToLiquidate0,
            totalAddedAssets,
            addedShares,
        ),
        collateralAssetDecimals,
        collateralAssetPrice,
    )
    < COLLATERAL_DUST_LIQUIDATION_THRESHOLD,
)

# Conditions to recalculate debt are not enforced here, to make the proof more general
proveValid(
    s,
    "Recalculated drawn shares cannot increase when liquidation bonus increases",
    recalculatedDrawnSharesToLiquidate2 <= recalculatedDrawnSharesToLiquidate,
    [liquidationBonus < liquidationBonus2],
)


proveValid(
    s,
    "Collateral shares to liquidate: inline calculation is equivalent to partial inline calculation",
    collateralSharesToLiquidate
    == divDown(
        mulDivDown(
            drawnSharesToLiquidate * drawnIndex + premiumDebtRayToLiquidate,
            debtAssetPrice * liquidationBonus * (addedShares + VIRTUAL_SHARES),
            debtAssetUnit
            * collateralAssetPrice
            * PERCENTAGE_FACTOR
            * (totalAddedAssets + VIRTUAL_ASSETS),
        ),
        RAY // collateralAssetUnit,
    ),
)

proveValid(
    s,
    "If drawn shares are recalculated, their value cannot exceed user's drawn shares",
    recalculatedDrawnSharesToLiquidate0 <= drawnShares,
    [
        premiumDebtRay < recalculatedDebtRayToLiquidated0,
        Or(
            And(
                leavesCollateralDust0,
                drawnSharesToLiquidate < drawnShares,
            ),
            collateralSharesToLiquidate0 > suppliedShares,
        ),
    ],
)
