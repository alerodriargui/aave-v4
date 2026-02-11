"""
Opportunity Cost Analysis for mintFeeShares() Minting Intervals

Uses ETH market data from Aave V3 (2/11/26):
  - 2.85M ETH borrowed at 2.46% borrow APY
  - Supply APY: 1.94%
  - Reserve factor: 15%
  - ETH price: $1,970.06

Produces two plots:
  1. Total interest earned for various minting intervals over 3 years
  2. Generalized: optimal minting interval as a function of gas cost & annual revenue
"""

import matplotlib.pyplot as plt
import matplotlib.ticker as mticker
import numpy as np

# ─── Market parameters ───────────────────────────────────────────────────────
BORROWED_ETH     = 2_850_000              # ETH
BORROW_APY       = 0.0246                 # 2.46%
SUPPLY_APY       = 0.0194                 # 1.94%
RESERVE_FACTOR   = 0.15                   # 15%
ETH_PRICE        = 1_970.06               # USD

ANNUAL_REVENUE_ETH = BORROWED_ETH * BORROW_APY * RESERVE_FACTOR  # 10,516.5 ETH
ANNUAL_REVENUE_USD = ANNUAL_REVENUE_ETH * ETH_PRICE               # ~$20.7M

T = 3  # years horizon

# ─── Minting intervals ───────────────────────────────────────────────────────
intervals = {
    "1 year":    1.0,
    "6 months":  0.5,
    "3 months":  0.25,
    "1 month":   1 / 12,
    "2 weeks":   2 / 52,
    "1 week":    1 / 52,
    "1 day":     1 / 365,
    "1 hour":    1 / (365 * 24),
}

# ─── Closed-form formula ─────────────────────────────────────────────────────
# Interest(Δ, T) = R × r × T × (T - Δ) / 2
def interest_earned(R, r, T, delta):
    return R * r * T * (T - delta) / 2

# Continuous minting upper bound
max_interest = interest_earned(ANNUAL_REVENUE_USD, SUPPLY_APY, T, 0)

# Calculate for each interval
labels = list(intervals.keys())
deltas = list(intervals.values())
interests = [interest_earned(ANNUAL_REVENUE_USD, SUPPLY_APY, T, d) for d in deltas]

# ─── Plot 1: Interest earned by minting interval ─────────────────────────────
fig, ax = plt.subplots(figsize=(12, 7))

colors = plt.cm.viridis(np.linspace(0.2, 0.9, len(labels)))
bars = ax.bar(labels, interests, color=colors, edgecolor="white", linewidth=0.8)

# Add the continuous-minting ceiling line
ax.axhline(y=max_interest, color="#e74c3c", linestyle="--", linewidth=1.5,
           label=f"Continuous minting limit: ${max_interest:,.0f}")

# Annotate each bar
for bar, val in zip(bars, interests):
    ax.text(bar.get_x() + bar.get_width() / 2, bar.get_height() + 15_000,
            f"${val:,.0f}", ha="center", va="bottom", fontsize=8, fontweight="bold")

ax.set_ylabel("Total Interest Earned Over 3 Years (USD)", fontsize=12)
ax.set_xlabel("Minting Interval", fontsize=12)
ax.set_title(
    "Treasury Interest Earned by mintFeeShares() Frequency\n"
    f"(ETH Market: {BORROWED_ETH/1e6:.2f}M borrowed, {BORROW_APY*100:.2f}% borrow APY, "
    f"{RESERVE_FACTOR*100:.0f}% reserve factor, ETH=${ETH_PRICE:,.2f})",
    fontsize=12, fontweight="bold"
)
ax.yaxis.set_major_formatter(mticker.FuncFormatter(lambda x, _: f"${x:,.0f}"))
ax.legend(fontsize=11)
ax.tick_params(axis="x", rotation=30)
plt.tight_layout()
plt.savefig("docs/mint_interval_interest.png", dpi=150)
print("Saved docs/mint_interval_interest.png")
plt.close()


# ─── Plot 2: Optimal minting interval vs. gas cost ──────────────────────────
# Optimal Δ* = sqrt(2G / (R × r))
#
# Where G = gas cost of one mintFeeShares() call in USD.
#
# Key insight: if we work in ETH (or the native asset), the price cancels:
#   G_eth = gas_used × gas_price_in_eth
#   R_eth = borrowed × borrow_rate × reserve_factor
#   Δ* = sqrt(2 × G_eth / (R_eth × r))
#
# For non-ETH markets:
#   Δ* = sqrt(2 × G_eth × ETH_price / (R_asset × asset_price × r))

def optimal_delta(G_usd, R_usd, r):
    """Returns optimal minting interval in years."""
    return np.sqrt(2 * G_usd / (R_usd * r))

def delta_to_human(delta_years):
    """Convert fractional years to a readable string."""
    hours = delta_years * 365.25 * 24
    if hours < 1:
        return f"{hours * 60:.1f} min"
    if hours < 24:
        return f"{hours:.1f} hrs"
    days = hours / 24
    if days < 7:
        return f"{days:.1f} days"
    if days < 30:
        return f"{days / 7:.1f} weeks"
    if days < 365:
        return f"{days / 30:.1f} months"
    return f"{days / 365:.1f} years"

# Gas costs from $0.10 to $100
gas_costs = np.logspace(-1, 2, 500)  # $0.10 to $100

fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(16, 7))

# --- Left panel: ETH market specifically ---
deltas_optimal = [optimal_delta(g, ANNUAL_REVENUE_USD, SUPPLY_APY) for g in gas_costs]
# Convert to hours for readability
deltas_hours = [d * 365.25 * 24 for d in deltas_optimal]

ax1.loglog(gas_costs, deltas_hours, color="#2980b9", linewidth=2.5)
ax1.set_xlabel("Gas Cost per mintFeeShares() Call (USD)", fontsize=12)
ax1.set_ylabel("Optimal Minting Interval (hours)", fontsize=12)
ax1.set_title(
    "Optimal Minting Interval vs. Gas Cost\n"
    f"(ETH Market: R = ${ANNUAL_REVENUE_USD/1e6:.1f}M/yr, supply APY = {SUPPLY_APY*100:.2f}%)",
    fontsize=11, fontweight="bold"
)
ax1.grid(True, which="both", alpha=0.3)

# Mark some reference gas costs
for ref_gas, label in [(0.50, "$0.50"), (2.0, "$2"), (10.0, "$10"), (50.0, "$50")]:
    d = optimal_delta(ref_gas, ANNUAL_REVENUE_USD, SUPPLY_APY)
    h = d * 365.25 * 24
    ax1.plot(ref_gas, h, "o", color="#e74c3c", markersize=8, zorder=5)
    ax1.annotate(f"{label} gas → {delta_to_human(d)}",
                 xy=(ref_gas, h), xytext=(ref_gas * 1.8, h * 1.8),
                 fontsize=9, fontweight="bold",
                 arrowprops=dict(arrowstyle="->", color="#e74c3c"),
                 color="#e74c3c")

# --- Right panel: Generalized across different revenue levels ---
revenue_levels = [1e5, 1e6, 5e6, 20e6, 100e6]
colors2 = plt.cm.plasma(np.linspace(0.2, 0.9, len(revenue_levels)))

for R, c in zip(revenue_levels, colors2):
    deltas_gen = [optimal_delta(g, R, SUPPLY_APY) * 365.25 * 24 for g in gas_costs]
    ax2.loglog(gas_costs, deltas_gen, color=c, linewidth=2,
               label=f"R = ${R/1e6:.1f}M/yr" if R >= 1e6 else f"R = ${R/1e3:.0f}K/yr")

ax2.set_xlabel("Gas Cost per mintFeeShares() Call (USD)", fontsize=12)
ax2.set_ylabel("Optimal Minting Interval (hours)", fontsize=12)
ax2.set_title(
    "Generalized Optimal Minting Interval\n"
    f"(supply APY = {SUPPLY_APY*100:.2f}%, various annual revenue levels)",
    fontsize=11, fontweight="bold"
)
ax2.grid(True, which="both", alpha=0.3)
ax2.legend(fontsize=10)

plt.tight_layout()
plt.savefig("docs/optimal_mint_interval.png", dpi=150)
print("Saved docs/optimal_mint_interval.png")
plt.close()


# ─── Print summary table ─────────────────────────────────────────────────────
print("\n" + "=" * 75)
print("TREASURY INTEREST EARNED OVER 3 YEARS BY MINTING INTERVAL")
print("=" * 75)
print(f"{'Interval':<12} {'Δ (years)':<12} {'Interest Earned':<20} {'vs Never Minting'}")
print("-" * 75)
for label, delta, interest in zip(labels, deltas, interests):
    print(f"{label:<12} {delta:<12.6f} ${interest:>14,.2f}    ${interest:>14,.2f}")
print("-" * 75)
print(f"{'Continuous':<12} {'→ 0':<12} ${max_interest:>14,.2f}    ${max_interest:>14,.2f}")

print("\n" + "=" * 75)
print("GENERALIZED OPTIMAL MINTING INTERVAL")
print("=" * 75)
print("Formula:  Δ* = sqrt(2G / (R × r))")
print("  G = gas cost per mint call (USD)")
print("  R = annual treasury revenue (USD)")
print("  r = supply APY")
print()
print("For ETH market (R = ${:,.0f}/yr, r = {:.2%}):".format(ANNUAL_REVENUE_USD, SUPPLY_APY))
print(f"{'Gas Cost':<12} {'Optimal Interval'}")
print("-" * 30)
for g in [0.10, 0.50, 1.0, 2.0, 5.0, 10.0, 25.0, 50.0, 100.0]:
    d = optimal_delta(g, ANNUAL_REVENUE_USD, SUPPLY_APY)
    print(f"${g:<10.2f} {delta_to_human(d)}")

print()
print("=" * 75)
print("PRICE-INDEPENDENT FORM (for ETH market)")
print("=" * 75)
print("When gas and revenue are in the SAME unit (ETH), price cancels:")
print("  Δ* = sqrt(2 × G_eth / (R_eth × r))")
print(f"  R_eth = {ANNUAL_REVENUE_ETH:,.1f} ETH/year")
print()
print("For non-ETH markets:")
print("  Δ* = sqrt(2 × G_eth × P_eth / (R_asset × P_asset × r))")
print("  where P_eth and P_asset are prices in a common denomination (e.g., USD)")
