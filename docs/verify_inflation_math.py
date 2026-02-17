
# Constants from the document
D = 2.85e6  # 2.85M ETH
A0 = 3.06e6 # 3.06M ETH
rb = 0.0246 # 2.46%
f = 0.15    # 15%

# Derived constants calculation
rs_calc = (D / A0) * rb * (1 - f)
phi_calc = D * rb * f

print(f"Calculated r_s: {rs_calc:.6f} (Doc: 1.94%)")
print(f"Calculated phi: {phi_calc:.2f} ETH/yr (Doc: 10,516.5)")

# USD Values for check
ETH_PRICE = 5615000000 / 2850000 # derived from D=$5.615B
# actually assume D_usd and A0_usd from doc
D_usd = 5.615e9
A0_usd = 6.028e9
phi_usd = D_usd * rb * f
print(f"Phi USD: ${phi_usd:,.2f} (Doc: $20.72M)")

# Section: Accumulation after 1 year (U = phi)
U = phi_calc
ratio = U / A0
print(f"U/A0: {ratio:.6f} (Doc: 0.344% = 0.00344)")

inf_factor = 1 / (1 - ratio)
print(f"Inflation Factor: {inf_factor:.6f} (Doc: 1.00345)")

rs_inflated = rs_calc * inf_factor
print(f"r_s inflated: {rs_inflated:.6f} (Doc: 1.9467%)")

extra_rate = rs_inflated - rs_calc
print(f"Extra Rate: {extra_rate:.8f} (Doc: 0.0067%)")

val_transferred_usd = phi_usd * rs_calc
print(f"Value Transferred USD: ${val_transferred_usd:,.2f} (Doc: $401,968)")

# Section: Minting Interval
# Formula: T = (X * A0) / (phi * rs)
# Case 1: X = 1 bps = 0.01% = 0.0001
X1 = 0.0001
T1_years = (X1 * A0_usd) / (phi_usd * rs_calc)
T1_days = T1_years * 365
print(f"Minting Interval for 1bps (0.0001): {T1_years:.4f} years = {T1_days:.2f} days (Doc: 150 days)")

# Case 2: X = 0.1 bps = 0.00001
X2 = 0.00001
T2_years = (X2 * A0_usd) / (phi_usd * rs_calc)
T2_days = T2_years * 365
print(f"Minting Interval for 0.1bps (0.00001): {T2_years:.4f} years = {T2_days:.2f} days (Doc: 15 days)")

# Case 3: X = 0.01 bps = 0.000001
X3 = 0.000001
T3_years = (X3 * A0_usd) / (phi_usd * rs_calc)
T3_days = T3_years * 365
print(f"Minting Interval for 0.01bps (0.000001): {T3_years:.4f} years = {T3_days:.2f} days (Doc: 1.5 days)")

