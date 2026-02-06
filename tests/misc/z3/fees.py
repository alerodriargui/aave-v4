from commons import *


def premiumDebtRay(realizedPremiumRay, premiumShares, drawnIndex, premiumOffsetRay):
    return realizedPremiumRay + premiumShares * drawnIndex - premiumOffsetRay


def totalDebt(
    drawnShares,
    drawnIndex,
    realizedPremiumRay,
    premiumShares,
    premiumOffsetRay,
    deficitRay,
):
    return fromRayUp(
        drawnShares * drawnIndex
        + premiumDebtRay(
            realizedPremiumRay, premiumShares, drawnIndex, premiumOffsetRay
        )
        + deficitRay
    )


def interestForFees(fees, totalGrowthWithoutFees, TOTAL_ASSETS):
    return mulDivDown(fees, totalGrowthWithoutFees, TOTAL_ASSETS)


s = Solver()

liquidityFee = Int("liquidityFee")
s.add(0 <= liquidityFee, liquidityFee <= PERCENTAGE_FACTOR)

drawnIndex0 = Int("drawnIndex0")
s.add(RAY <= drawnIndex0, drawnIndex0 < 100 * RAY)
drawnIndex1 = Int("drawnIndex1")
s.add(drawnIndex0 <= drawnIndex1, drawnIndex1 < 100 * RAY)
drawnIndex2 = Int("drawnIndex2")
s.add(drawnIndex1 <= drawnIndex2, drawnIndex2 < 100 * RAY)
drawnIndex3 = Int("drawnIndex3")
s.add(drawnIndex2 <= drawnIndex3, drawnIndex3 < 100 * RAY)

drawnShares = Int("drawnShares")
s.add(1 <= drawnShares, drawnShares <= 10**30)
premiumShares = Int("premiumShares")
s.add(0 <= premiumShares, premiumShares <= 10**30)
premiumOffsetRay = premiumShares * drawnIndex0
realizedPremiumRay = Int("realizedPremiumRay")
s.add(0 <= realizedPremiumRay, realizedPremiumRay <= 10**30)
liquiditySwept = Int("liquiditySwept")
s.add(0 <= liquiditySwept, liquiditySwept <= 10**30)
deficitRay = Int("deficitRay")
s.add(0 <= deficitRay, deficitRay <= 10**30)

# T0: start
totalDebt0 = totalDebt(
    drawnShares,
    drawnIndex0,
    realizedPremiumRay,
    premiumShares,
    premiumOffsetRay,
    deficitRay,
)
TOTAL_ASSETS0 = liquiditySwept + totalDebt0 + VIRTUAL_ASSETS
totalAddedAssets0 = liquiditySwept + totalDebt0

# T1: accrue
# premium offset and realized premium are not updated, since premium is tracked with full precision
totalDebt1 = totalDebt(
    drawnShares,
    drawnIndex1,
    realizedPremiumRay,
    premiumShares,
    premiumOffsetRay,
    deficitRay,
)
totalRawFees1 = percentMulDown(totalDebt1 - totalDebt0, liquidityFee)
totalGrowthWithoutFees1 = totalDebt1 - totalDebt0 - totalRawFees1
ghostFees1 = interestForFees(
    percentMulDown(totalDebt1 - totalDebt0, liquidityFee),
    totalGrowthWithoutFees1,
    TOTAL_ASSETS0,
)
feeAmount1 = (
    totalRawFees1
    # + interestForFees(
    #     totalRawFees1,
    #     totalGrowthWithoutFees1,
    #     TOTAL_ASSETS0,
    # )
    # - ghostFees1
)
totalAddedAssets1 = liquiditySwept + totalDebt1 - feeAmount1


proveValid(
    s,
    "share price does not decrease from T0 to T1",
    totalAddedAssets1 >= totalAddedAssets0,
)

# T2: preview
totalDebt2 = totalDebt(
    drawnShares,
    drawnIndex2,
    realizedPremiumRay,
    premiumShares,
    premiumOffsetRay,
    deficitRay,
)
totalRawFees2 = percentMulDown(totalDebt2 - totalDebt0, liquidityFee)
totalGrowthWithoutFees2 = totalDebt2 - totalDebt0 - totalRawFees2
ghostFees2 = ghostFees1 + interestForFees(
    percentMulDown(totalDebt2 - totalDebt1, liquidityFee),
    totalGrowthWithoutFees2,
    TOTAL_ASSETS0,
)
feeAmount2 = (
    totalRawFees2
    + interestForFees(
        totalRawFees2,
        totalGrowthWithoutFees2,
        TOTAL_ASSETS0,
    )
    - ghostFees2
)
totalAddedAssets2 = liquiditySwept + totalDebt2 - feeAmount2
proveValid(
    s,
    "share price does not decrease from T1 to T2",
    totalAddedAssets2 >= totalAddedAssets1,
)

# T3: preview
totalDebt3 = totalDebt(
    drawnShares,
    drawnIndex3,
    realizedPremiumRay,
    premiumShares,
    premiumOffsetRay,
    deficitRay,
)
totalRawFees3 = percentMulDown(totalDebt3 - totalDebt0, liquidityFee)
totalGrowthWithoutFees3 = totalDebt3 - totalDebt0 - totalRawFees3
ghostFees3 = ghostFees2 + interestForFees(
    percentMulDown(totalDebt3 - totalDebt2, liquidityFee),
    totalGrowthWithoutFees3,
    TOTAL_ASSETS0,
)
feeAmount3 = (
    totalRawFees3
    + interestForFees(
        totalRawFees3,
        totalGrowthWithoutFees3,
        TOTAL_ASSETS0,
    )
    - ghostFees3
)
totalAddedAssets3 = liquiditySwept + totalDebt3 - feeAmount3
proveValid(
    s,
    "share price does not decrease from T2 to T3",
    totalAddedAssets3 >= totalAddedAssets2,
)
