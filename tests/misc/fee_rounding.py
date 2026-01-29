# Analyzes conditions where fees round to 0 despite non-zero growth and non-zero
# liquidityFee configured.
#
# Key insight: The base fee calculation is `fees = (delta * liquidityFee) / PERCENTAGE_FACTOR`
# This rounds to 0 when `delta * liquidityFee < PERCENTAGE_FACTOR` (i.e., delta < 10000 / liquidityFee)
#
# The interestForFees calculation can also round to 0 independently.
from z3 import *

RAY = IntVal(10**27)
PERCENTAGE_FACTOR = IntVal(10**4)
VIRTUAL_SHARES = IntVal(10**6)
VIRTUAL_ASSETS = IntVal(10**6)

def percentMulDown(a, b):
    return (a * b) / PERCENTAGE_FACTOR

def mulDivDown(a, num, den):
    return (a * num) / den

def divUp(a, b):
    return (a + b - 1) / b

def fromRayUp(a):
    return divUp(a, RAY)

def rayMulUp(a, b):
    return divUp(a * b, RAY)

def check(propertyDescription, show_model=True):
    print(f"\n-- {propertyDescription} --")
    result = s.check()
    if result == sat:
        print("Example found:")
        if show_model:
            m = s.model()
            # Print key variables in a readable format
            vars_to_show = ['liquidityFee', 'drawnShares', 'addedShares', 'realizedFees', 
                           'liquidity', 'swept', 'previousIndex', 'drawnIndex']
            for name in vars_to_show:
                for d in m.decls():
                    if d.name() == name:
                        val = m[d]
                        if 'Index' in name:
                            print(f"  {name} = {val} ({float(val.as_long()) / 10**27:.9f} RAY)")
                        elif name == 'liquidityFee':
                            print(f"  {name} = {val} bps ({float(val.as_long()) / 100:.2f}%)")
                        else:
                            print(f"  {name} = {val}")
        return True
    elif result == unsat:
        print(f"No example exists (fees cannot round to 0 under these constraints).")
        return False
    elif result == unknown:
        print("Timed out or unknown.")
        return None

print("=" * 70)
print("FEE ROUNDING ANALYSIS")
print("=" * 70)
print("\nThis script finds conditions where fees round to 0 despite non-zero")
print("growth and non-zero liquidityFee configured.")

s = Solver()

# liquidityFee is in basis points (0-10000), must be < 100% so interest > 0
# Minimum 1% (100 bps) as a realistic floor
liquidityFee = Int('liquidityFee')
s.add(100 <= liquidityFee, liquidityFee < PERCENTAGE_FACTOR)

# Drawn index (starts at 1 RAY, grows over time)
previousIndex = Int('previousIndex')
s.add(RAY <= previousIndex, previousIndex <= 100 * RAY)
drawnIndex = Int('drawnIndex')
s.add(previousIndex < drawnIndex, drawnIndex <= 100 * RAY)

# Shares state (just drawn for simplicity)
drawnShares = Int('drawnShares')
s.add(1 <= drawnShares, drawnShares <= 10**30)

# Fee state - realizedFees, liquidity, swept, and addedShares
realizedFees = Int('realizedFees')
s.add(0 <= realizedFees, realizedFees <= 10**30)
liquidity = Int('liquidity')
s.add(0 <= liquidity, liquidity <= 10**30)
swept = Int('swept')
s.add(0 <= swept, swept <= 10**30)
addedShares = Int('addedShares')
s.add(1 <= addedShares, addedShares <= 10**30)

# Calculate delta (growth in drawn debt)
drawnAfter = fromRayUp(drawnShares * drawnIndex)
drawnBefore = fromRayUp(drawnShares * previousIndex)
delta = drawnAfter - drawnBefore
s.add(delta > 0)

# Calculate fees (protocol's cut)
fees = percentMulDown(delta, liquidityFee)

# Calculate interest (supplier's cut)
interest = delta - fees
s.add(interest > 0)  # Ensured by liquidityFee < 100%

# Calculate totalAddedAssetsBefore (liquidity + swept + aggregatedOwedBefore - realizedFees)
totalAddedAssetsBefore = liquidity + swept + drawnBefore - realizedFees
s.add(totalAddedAssetsBefore > 0)  # Must have positive assets backing shares

# Calculate unmintedFeeShares = toAddedSharesDown(realizedFees)
# Includes virtual shares/assets per SharesMath library
unmintedFeeShares = mulDivDown(realizedFees, addedShares + VIRTUAL_SHARES, totalAddedAssetsBefore + VIRTUAL_ASSETS)

# Calculate interestForFees (interest distributed pro-rata to shares)
interestForFees = mulDivDown(interest, unmintedFeeShares, addedShares + VIRTUAL_SHARES + unmintedFeeShares)

# Total fees
totalFees = fees + interestForFees

# =============================================================================
# Test 1: Can total fees round to 0?
# =============================================================================
s.push()
s.add(totalFees == 0)
check("Test 1: Total fees round to 0 (delta > 0, liquidityFee > 0, totalFees == 0)")
s.pop()

# =============================================================================
# Test 2: Base fee rounding to 0
# =============================================================================
s.push()
s.add(fees == 0)
check("Test 2: Base fee rounds to 0 (delta * liquidityFee < 10000)")
s.pop()

# =============================================================================
# Test 3: Interest for fees rounding to 0 when realizedFees > 0
# =============================================================================
s.push()
s.add(realizedFees > 0)
s.add(interestForFees == 0)
check("Test 3: interestForFees rounds to 0 despite realizedFees > 0")
s.pop()

# =============================================================================
# Test 4: With realistic fee (e.g., 10% = 1000 bps), can fees round to 0?
# =============================================================================
s.push()
s.add(liquidityFee >= 1000)
s.add(totalFees == 0)
check("Test 4: Fees round to 0 with liquidityFee >= 10%")
s.pop()

# =============================================================================
# Test 5: With larger delta (e.g., at least 1e6 wei), can fees round to 0?
# =============================================================================
s.push()
s.add(delta >= 10**6)
s.add(totalFees == 0)
check("Test 5: Fees round to 0 with delta >= 1e6 wei")
s.pop()

# =============================================================================
# Test 6: With 18-decimal token scale amounts
# =============================================================================
s.push()
s.add(drawnShares >= 10**18)
s.add(totalFees == 0)
check("Test 6: Fees round to 0 with drawnShares >= 1e18")
s.pop()

# =============================================================================
# Test 7: Large totalAssets causes interestForFees to round to 0
# =============================================================================
s.push()
s.add(fees > 0)
s.add(realizedFees > 0)
s.add(interestForFees == 0)
check("Test 7: Base fees > 0, realizedFees > 0, but interestForFees rounds to 0")
s.pop()

# =============================================================================
# Test 8: Explore totalAddedAssets/realizedFees ratio that causes rounding
# =============================================================================
s.push()
s.add(fees > 0)
s.add(realizedFees > 0)
s.add(totalAddedAssetsBefore > realizedFees * 1000)
s.add(interestForFees == 0)
check("Test 8: interestForFees = 0 when totalAddedAssetsBefore > 1000 * realizedFees")
s.pop()

# =============================================================================
# Test 9: With realistic token amounts, can interestForFees round to 0?
# =============================================================================
s.push()
s.add(drawnShares >= 10**24)
s.add(fees > 0)
s.add(realizedFees > 0)
s.add(realizedFees <= 10**20)
s.add(interestForFees == 0)
check("Test 9: 1M tokens borrowed, <= 100 tokens realizedFees, interestForFees = 0")
s.pop()

# =============================================================================
# Analytical summary
# =============================================================================
print("\n" + "=" * 70)
print("ANALYTICAL SUMMARY")
print("=" * 70)

print("\n1. MINIMUM DELTA FOR NON-ZERO BASE FEES:")
print("   Formula: delta >= ceil(PERCENTAGE_FACTOR / liquidityFee)")
print("   This is because fees = (delta * liquidityFee) / 10000")
print()
for fee_bps in [100, 500, 1000, 2000, 5000]:
    min_delta = (10000 + fee_bps - 1) // fee_bps
    print(f"   liquidityFee = {fee_bps:4d} bps ({fee_bps/100:5.2f}%): min delta = {min_delta:,} wei")

print("\n2. CONDITION FOR NON-ZERO interestForFees:")
print("   Formula (share-based):")
print("     unmintedFeeShares = realizedFees * addedShares / totalAddedAssetsBefore")
print("     interestForFees = interest * unmintedFeeShares / (addedShares + unmintedFeeShares)")
print()
print("   Key insight: Interest is distributed pro-rata to shares.")
print("   unmintedFeeShares represents what shares realizedFees would be if minted.")
print()
print("   Rounding can occur in two places:")
print("   - unmintedFeeShares calculation (realizedFees * addedShares / totalAddedAssets)")
print("   - interestForFees calculation (interest * unmintedFeeShares / totalShares)")

print("\n3. PRACTICAL IMPLICATIONS:")
print("   - With typical 18-decimal tokens, 1 wei = 10^-18 tokens")
print("   - Small/frequent accruals with low fees may lose precision")
print("   - Higher liquidityFee reduces minimum delta needed")
print("   - Rounding favors suppliers over protocol fees (by design)")
print("   - Interest is distributed pro-rata to share ownership")
