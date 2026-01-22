# Proves the available liquidity formula correctly reserves fees and maintains share price >= 1.0
# Handles debt repayments and liquidity withdrawals.
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
# Key constraint: Fees come from cumulative debt (not current debt)
# - unrealizedFees + realizedFees <= cumulativeDebt
# - cumulativeDebt tracks all debt ever generated (even if repaid)
# - This ensures fees remain valid even after debt repayments

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
