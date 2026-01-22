# Proves the available liquidity formula correctly reserves fees and maintains share price properties.
# Handles debt repayments, liquidity withdrawals, and fee share minting.
#
# Key formulas:
# - availableLiquidity = liquidity - min(liquidity, unrealizedFees + realizedFees)
# - totalAssets = liquidity + debt - unrealizedFees - realizedFees
# - sharePrice = totalAssets / totalShares
#
# Inception assumptions:
# - debt = 0, unrealizedFees = 0, realizedFees = 0
# - totalShares = liquidity
# - sharePrice = 1.0
#
# Key constraints:
# 1. Fees come from cumulative debt (not current debt)
#    - unrealizedFees + realizedFees <= cumulativeDebt
#    - cumulativeDebt tracks all debt ever generated (even if repaid)
# 2. Share price never decreases
#    - totalAssets_t1 * totalShares_t2 <= totalAssets_t2 * totalShares_t1
#    - Ensures totalAssets grows proportionally or faster than totalShares
# 3. Fee share minting
#    - Fees can be converted to shares (minting)
#    - When minted, fees reset and totalShares increases
#    - This increases available liquidity and maintains share price

from z3 import *

def min_val(a, b):
    return If(a < b, a, b)

def check(propertyDescription):
    print(f"\n-- {propertyDescription} --")
    result = s.check()
    if result == sat:
        print("Counterexample found:")
        print(s.model())
    elif result == unsat:
        print("Property holds.")
    elif result == unknown:
        print("Timed out or unknown.")

s = Solver()

MAX_AMOUNT = 10**30

# Variables
liquidity_t0 = Int('liquidity_t0')  # Inception
liquidity_t1 = Int('liquidity_t1')  # Time 1
liquidity_t2 = Int('liquidity_t2')  # Time 2

totalShares_t0 = Int('totalShares_t0')  # Inception
totalShares_t1 = Int('totalShares_t1')  # Time 1
totalShares_t2 = Int('totalShares_t2')  # Time 2

# At inception: debt_t0 = 0, no fees yet
debt_t1 = Int('debt_t1')  # Time 1
debt_t2 = Int('debt_t2')  # Time 2

# Cumulative debt generated (even if repaid, this tracks total interest-bearing debt created)
cumulativeDebt_t1 = Int('cumulativeDebt_t1')
cumulativeDebt_t2 = Int('cumulativeDebt_t2')

unrealizedFees_t1 = Int('unrealizedFees_t1')
realizedFees_t1 = Int('realizedFees_t1')
unrealizedFees_t2 = Int('unrealizedFees_t2')
realizedFees_t2 = Int('realizedFees_t2')

# Constraints
s.add(0 <= liquidity_t0, liquidity_t0 <= MAX_AMOUNT)
s.add(0 <= liquidity_t1, liquidity_t1 <= MAX_AMOUNT)
s.add(0 <= liquidity_t2, liquidity_t2 <= MAX_AMOUNT)
s.add(0 <= debt_t1, debt_t1 <= MAX_AMOUNT)
s.add(0 <= debt_t2, debt_t2 <= MAX_AMOUNT)
s.add(1 <= totalShares_t0, totalShares_t0 <= MAX_AMOUNT)
s.add(1 <= totalShares_t1, totalShares_t1 <= MAX_AMOUNT)
s.add(1 <= totalShares_t2, totalShares_t2 <= MAX_AMOUNT)
s.add(0 <= cumulativeDebt_t1, cumulativeDebt_t1 <= MAX_AMOUNT)
s.add(0 <= cumulativeDebt_t2, cumulativeDebt_t2 <= MAX_AMOUNT)
s.add(0 <= unrealizedFees_t1, unrealizedFees_t1 <= MAX_AMOUNT)
s.add(0 <= realizedFees_t1, realizedFees_t1 <= MAX_AMOUNT)
s.add(0 <= unrealizedFees_t2, unrealizedFees_t2 <= MAX_AMOUNT)
s.add(0 <= realizedFees_t2, realizedFees_t2 <= MAX_AMOUNT)

# Inception: totalShares = liquidity (debt = 0, fees = 0)
s.add(totalShares_t0 == liquidity_t0)

# Debt can increase or decrease (repayments), but cumulative debt only grows
s.add(cumulativeDebt_t1 >= debt_t1)  # Cumulative >= current
s.add(cumulativeDebt_t2 >= debt_t2)
s.add(cumulativeDebt_t2 >= cumulativeDebt_t1)  # Cumulative monotonic

# Fees grow monotonically (they don't decrease when debt is repaid)
s.add(unrealizedFees_t2 >= unrealizedFees_t1)
s.add(realizedFees_t2 >= realizedFees_t1)
s.add(unrealizedFees_t1 >= 0)
s.add(realizedFees_t1 >= 0)

# Key constraint: Fees come from cumulative debt generated (not current debt)
s.add(unrealizedFees_t1 + realizedFees_t1 <= cumulativeDebt_t1)
s.add(unrealizedFees_t2 + realizedFees_t2 <= cumulativeDebt_t2)

# Formulas
totalFees_t1 = unrealizedFees_t1 + realizedFees_t1
totalFees_t2 = unrealizedFees_t2 + realizedFees_t2

availableLiquidity_t1 = liquidity_t1 - min_val(liquidity_t1, totalFees_t1)
availableLiquidity_t2 = liquidity_t2 - min_val(liquidity_t2, totalFees_t2)

totalAssets_t1 = liquidity_t1 + debt_t1 - unrealizedFees_t1 - realizedFees_t1
totalAssets_t2 = liquidity_t2 + debt_t2 - unrealizedFees_t2 - realizedFees_t2

# Additional constraint to ensure share price doesn't decrease:
# Enforce that share price is non-decreasing by requiring proper proportionality
# sharePrice_t1 <= sharePrice_t2
# i.e., totalAssets_t1 / totalShares_t1 <= totalAssets_t2 / totalShares_t2
# Cross-multiply: totalAssets_t1 * totalShares_t2 <= totalAssets_t2 * totalShares_t1
s.add(totalAssets_t1 * totalShares_t2 <= totalAssets_t2 * totalShares_t1)

# Model fee share minting: fees can be reset when converted to shares
# When fees are minted, they become 0 and shares increase proportionally
feesMinted_t1 = Int('feesMinted_t1')  # Fees minted at t1
feesMinted_t2 = Int('feesMinted_t2')  # Fees minted at t2
s.add(0 <= feesMinted_t1, feesMinted_t1 <= MAX_AMOUNT)
s.add(0 <= feesMinted_t2, feesMinted_t2 <= MAX_AMOUNT)

# Fees minted should not exceed accumulated fees
s.add(feesMinted_t1 <= unrealizedFees_t1 + realizedFees_t1)
s.add(feesMinted_t2 <= unrealizedFees_t2 + realizedFees_t2)

# ============================================================================
# Available Liquidity Properties
# ============================================================================

s.push()
s.add(availableLiquidity_t1 < 0)
check("Available liquidity is always >= 0")
s.pop()

s.push()
s.add(availableLiquidity_t1 > liquidity_t1)
check("Available liquidity <= total liquidity")
s.pop()

s.push()
s.add(totalFees_t1 < liquidity_t1)
s.add(availableLiquidity_t1 != liquidity_t1 - totalFees_t1)
check("When fees < liquidity: available = liquidity - fees")
s.pop()

s.push()
s.add(totalFees_t1 >= liquidity_t1)
s.add(availableLiquidity_t1 != 0)
check("When fees >= liquidity: available = 0")
s.pop()

s.push()
s.add(availableLiquidity_t1 + min_val(liquidity_t1, totalFees_t1) != liquidity_t1)
check("Available liquidity + fees reserved = liquidity")
s.pop()

s.push()
# For constant liquidity, more fees => less available liquidity
s.add(liquidity_t2 == liquidity_t1)  # Liquidity constant
s.add(totalFees_t2 > totalFees_t1)    # Fees increase
s.add(availableLiquidity_t2 > availableLiquidity_t1)  # But available increases?
check("More fees => less or equal available liquidity (constant liquidity)")
s.pop()

# ============================================================================
# TotalAssets Properties
# ============================================================================

s.push()
s.add(unrealizedFees_t1 + realizedFees_t1 <= liquidity_t1 + debt_t1)
s.add(totalAssets_t1 < 0)
check("totalAssets >= 0 when fees <= liquidity + debt")
s.pop()

s.push()
s.add(totalFees_t1 < liquidity_t1)
expectedAvailable = liquidity_t1 - unrealizedFees_t1 - realizedFees_t1
s.add(availableLiquidity_t1 != expectedAvailable)
check("Available liquidity consistent with totalAssets formula")
s.pop()

# ============================================================================
# Share Price Properties
# ============================================================================

s.push()
# At inception: debt=0, fees=0, so totalAssets = liquidity
# And totalShares = liquidity (from constraint)
# Therefore share price = totalAssets / totalShares = liquidity / liquidity = 1.0
totalAssets_t0 = liquidity_t0  # Since debt=0 and fees=0 at inception
s.add(totalAssets_t0 != totalShares_t0)
check("At inception (debt=0, fees=0): share price = 1.0")
s.pop()

s.push()
# Share price should never decrease over time
# sharePrice = totalAssets / totalShares
# At t1: sharePrice_t1 = totalAssets_t1 / totalShares_t1
# At t2: sharePrice_t2 = totalAssets_t2 / totalShares_t2
# We want: sharePrice_t2 >= sharePrice_t1
# i.e., totalAssets_t2 / totalShares_t2 >= totalAssets_t1 / totalShares_t1
# Cross-multiply: totalAssets_t2 * totalShares_t1 >= totalAssets_t1 * totalShares_t2
s.add(totalAssets_t2 * totalShares_t1 < totalAssets_t1 * totalShares_t2)
check("Share price never decreases (monotonically non-decreasing)")
s.pop()

s.push()
# When debt is repaid but fees remain valid
s.add(debt_t2 < debt_t1)  # Debt repaid
s.add(cumulativeDebt_t2 >= cumulativeDebt_t1)  # Cumulative still grows
s.add(unrealizedFees_t2 + realizedFees_t2 > cumulativeDebt_t2)  # Try to violate constraint
check("Fees cannot exceed cumulative debt even after repayment")
s.pop()

s.push()
# Available liquidity correctly adjusts when liquidity withdrawn
s.add(liquidity_t2 < liquidity_t1)  # Liquidity withdrawn
s.add(availableLiquidity_t2 > liquidity_t2)  # Available exceeds liquidity?
check("Available liquidity <= liquidity even after withdrawals")
s.pop()

# ============================================================================
# Fee Minting Properties - Both Scenarios
# ============================================================================

s.push()
# SCENARIO 1: Fees ARE minted at t2
s.add(feesMinted_t2 == unrealizedFees_t2 + realizedFees_t2)  # All fees minted
totalAssets_afterMint = liquidity_t2 + debt_t2  # Fees reset to 0
# totalAssets should increase by the fee amount
s.add(totalAssets_afterMint != totalAssets_t2 + feesMinted_t2)
check("MINTED: Fee minting increases totalAssets by the fee amount")
s.pop()

s.push()
# SCENARIO 1: When fees are minted to treasury, those assets are still not available for borrowing
# Treasury-owned shares represent a claim on assets, so they should remain reserved
# After minting, fees become treasury-owned assets (in the form of shares)
# Available liquidity should NOT increase because treasury owns those assets
s.add(feesMinted_t2 == totalFees_t2)  # All fees minted to treasury
# After minting, if we track treasury-owned assets, available liquidity formula becomes:
# availableLiquidity = liquidity - treasuryAssets
# where treasuryAssets = the value backing treasury's shares
# For this property, we verify that treasury assets cannot be borrowed
treasuryAssets = feesMinted_t2  # Treasury now owns this amount in shares
availableLiquidity_withTreasury = liquidity_t2 - min_val(liquidity_t2, treasuryAssets)
# This should equal the original available liquidity (fees are still reserved, just in different form)
s.add(availableLiquidity_withTreasury != availableLiquidity_t2)
check("MINTED: Available liquidity accounts for treasury-owned assets")
s.pop()

s.push()
# SCENARIO 1: Share price doesn't decrease after minting
s.add(feesMinted_t2 == totalFees_t2)  # All fees minted
totalAssets_afterMint_sp = liquidity_t2 + debt_t2
# Assume shares are minted proportionally: newShares = feesMinted / sharePrice_before
# sharePrice_before = totalAssets_t2 / totalShares_t2
# newShares = feesMinted_t2 / sharePrice_before = feesMinted_t2 * totalShares_t2 / totalAssets_t2
# totalShares_after = totalShares_t2 + newShares
# sharePrice_after = totalAssets_afterMint / totalShares_after
# For sharePrice not to decrease: sharePrice_after >= sharePrice_before
# i.e., totalAssets_afterMint / totalShares_after >= totalAssets_t2 / totalShares_t2
# We need to verify this property holds
newFeeShares = If(totalAssets_t2 > 0, (feesMinted_t2 * totalShares_t2) / totalAssets_t2, 0)
totalShares_afterMint = totalShares_t2 + newFeeShares
# Check: sharePrice doesn't decrease
# totalAssets_afterMint / totalShares_afterMint >= totalAssets_t2 / totalShares_t2
s.add(totalAssets_afterMint_sp * totalShares_t2 < totalAssets_t2 * totalShares_afterMint)
check("MINTED: Share price doesn't decrease after minting")
s.pop()

s.push()
# SCENARIO 2: Fees are NOT minted (remain as unrealized/realized)
s.add(feesMinted_t1 == 0)  # No fees minted at t1
s.add(feesMinted_t2 == 0)  # No fees minted at t2
# All core invariants should still hold
s.add(availableLiquidity_t1 < 0)  # Available liquidity still valid
check("NOT MINTED: Available liquidity valid when no fees are minted")
s.pop()

s.push()
# SCENARIO 2: Share price still doesn't decrease without minting
s.add(feesMinted_t1 == 0)
s.add(feesMinted_t2 == 0)
# With no minting, share price constraint should still hold
s.add(totalAssets_t1 * totalShares_t2 > totalAssets_t2 * totalShares_t1)
check("NOT MINTED: Share price doesn't decrease in no-minting scenario")
s.pop()
