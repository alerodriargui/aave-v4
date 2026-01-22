# Proves the available liquidity formula correctly reserves fees and maintains share price >= 1.0
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
# Key constraint: Fees come from debt growth
# - unrealizedFees + realizedFees <= debt

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
liquidity = Int('liquidity')
totalShares = Int('totalShares')

# At inception: debt_t0 = 0, no fees yet
debt_t1 = Int('debt_t1')  # Time 1
debt_t2 = Int('debt_t2')  # Time 2

unrealizedFees_t1 = Int('unrealizedFees_t1')
realizedFees_t1 = Int('realizedFees_t1')
unrealizedFees_t2 = Int('unrealizedFees_t2')
realizedFees_t2 = Int('realizedFees_t2')

# Constraints
s.add(0 <= liquidity, liquidity <= MAX_AMOUNT)
s.add(0 <= debt_t1, debt_t1 <= MAX_AMOUNT)
s.add(0 <= debt_t2, debt_t2 <= MAX_AMOUNT)
s.add(1 <= totalShares, totalShares <= MAX_AMOUNT)
s.add(0 <= unrealizedFees_t1, unrealizedFees_t1 <= MAX_AMOUNT)
s.add(0 <= realizedFees_t1, realizedFees_t1 <= MAX_AMOUNT)
s.add(0 <= unrealizedFees_t2, unrealizedFees_t2 <= MAX_AMOUNT)
s.add(0 <= realizedFees_t2, realizedFees_t2 <= MAX_AMOUNT)

# Inception: totalShares = liquidity (debt = 0, fees = 0)
s.add(totalShares == liquidity)

# Debt grows monotonically from 0
s.add(debt_t2 >= debt_t1)
s.add(debt_t1 >= 0)

# Fees grow monotonically from 0
s.add(unrealizedFees_t2 >= unrealizedFees_t1)
s.add(realizedFees_t2 >= realizedFees_t1)
s.add(unrealizedFees_t1 >= 0)
s.add(realizedFees_t1 >= 0)

# Key constraint: Fees come from debt growth (from inception with debt=0)
s.add(unrealizedFees_t1 + realizedFees_t1 <= debt_t1)
s.add(unrealizedFees_t2 + realizedFees_t2 <= debt_t2)

# Formulas
totalFees_t1 = unrealizedFees_t1 + realizedFees_t1
totalFees_t2 = unrealizedFees_t2 + realizedFees_t2

availableLiquidity_t1 = liquidity - min_val(liquidity, totalFees_t1)
availableLiquidity_t2 = liquidity - min_val(liquidity, totalFees_t2)

totalAssets_t1 = liquidity + debt_t1 - unrealizedFees_t1 - realizedFees_t1
totalAssets_t2 = liquidity + debt_t2 - unrealizedFees_t2 - realizedFees_t2

# ============================================================================
# Available Liquidity Properties
# ============================================================================

s.push()
s.add(availableLiquidity_t1 < 0)
check("Available liquidity is always >= 0")
s.pop()

s.push()
s.add(availableLiquidity_t1 > liquidity)
check("Available liquidity <= total liquidity")
s.pop()

s.push()
s.add(totalFees_t1 < liquidity)
s.add(availableLiquidity_t1 != liquidity - totalFees_t1)
check("When fees < liquidity: available = liquidity - fees")
s.pop()

s.push()
s.add(totalFees_t1 >= liquidity)
s.add(availableLiquidity_t1 != 0)
check("When fees >= liquidity: available = 0")
s.pop()

s.push()
s.add(availableLiquidity_t1 + min_val(liquidity, totalFees_t1) != liquidity)
check("Available liquidity + fees reserved = liquidity")
s.pop()

s.push()
s.add(totalFees_t2 > totalFees_t1)
s.add(availableLiquidity_t2 > availableLiquidity_t1)
check("More fees => less or equal available liquidity")
s.pop()

# ============================================================================
# TotalAssets Properties
# ============================================================================

s.push()
s.add(unrealizedFees_t1 + realizedFees_t1 <= liquidity + debt_t1)
s.add(totalAssets_t1 < 0)
check("totalAssets >= 0 when fees <= liquidity + debt")
s.pop()

s.push()
s.add(totalFees_t1 < liquidity)
expectedAvailable = liquidity - unrealizedFees_t1 - realizedFees_t1
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
totalAssets_t0 = liquidity  # Since debt=0 and fees=0 at inception
s.add(totalAssets_t0 != totalShares)
check("At inception (debt=0, fees=0): share price = 1.0")
s.pop()

s.push()
s.add(totalAssets_t1 < totalShares)
check("Share price at time 1 is always >= 1.0 (fees <= debt growth)")
s.pop()

s.push()
s.add(totalAssets_t2 < totalShares)
check("Share price at time 2 is always >= 1.0 (fees <= debt growth)")
s.pop()

s.push()
s.add(unrealizedFees_t2 > unrealizedFees_t1)
s.add(realizedFees_t2 > realizedFees_t1)
s.add(debt_t2 == debt_t1)  # Debt constant
s.add(totalAssets_t2 > totalAssets_t1)
check("Share price cannot increase without debt growth")
s.pop()

s.push()
debtGrowth = debt_t2 - debt_t1
feeGrowth = totalFees_t2 - totalFees_t1
s.add(debtGrowth > feeGrowth)
s.add(feeGrowth > 0)
s.add(totalAssets_t2 <= totalAssets_t1)
check("Share price increases when debt growth > fee growth")
s.pop()
