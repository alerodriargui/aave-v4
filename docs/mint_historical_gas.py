"""
Optimal minting intervals for each market at historical Ethereum gas prices.

Uses the actual measured gas cost of mintFeeShares() = 82,741 gas
from snapshots/Hub.Operations.json.

Historical gas price eras sourced from Etherscan / public data:
  - 2021 peak:         ~150 gwei  (DeFi summer / NFT mania)
  - 2022 avg:          ~50 gwei   (pre-merge, declining activity)
  - 2023 avg:          ~25 gwei   (post-merge, moderate)
  - Late 2023:         ~10 gwei   (low activity)
  - 2024 post-Dencun:  ~3 gwei    (Dencun upgrade, L2 offloading)
  - 2025 avg:          ~2 gwei    (continued efficiency)
  - Feb 2026 current:  ~0.5 gwei  (post-Fusaka/PeerDAS)
"""

import matplotlib.pyplot as plt
import matplotlib.ticker as mticker
import numpy as np
import math

# ─── Constants ────────────────────────────────────────────────────────────────
MINT_FEE_SHARES_GAS = 82_741  # from snapshot
ETH_PRICE = 1_970.06

# Historical gas prices (gwei) with labels
gas_eras = [
    ("2021 Peak\n(150 gwei)",     150),
    ("2022 Avg\n(50 gwei)",       50),
    ("2023 Avg\n(25 gwei)",       25),
    ("Late 2023\n(10 gwei)",      10),
    ("2024\nPost-Dencun\n(3 gwei)", 3),
    ("2025 Avg\n(2 gwei)",        2),
    ("Feb 2026\n(0.5 gwei)",      0.5),
]

# Markets
markets = {
    "ETH":  {"R_usd": 2_850_000 * 0.0246 * 0.15 * ETH_PRICE, "r": 0.0194,
             "color": "#627EEA"},
    "USDC": {"R_usd": 2_700_000_000 * 0.0382 * 0.10 * 1.0,   "r": 0.0236,
             "color": "#2775CA"},
    "WBTC": {"R_usd": 1_236.42 * 0.0034 * 0.50 * 67_466.82,  "r": 0.0001,
             "color": "#F7931A"},
}

def gas_cost_usd(gas_price_gwei):
    return MINT_FEE_SHARES_GAS * gas_price_gwei * 1e-9 * ETH_PRICE

def optimal_delta_years(G_usd, R_usd, r):
    return math.sqrt(2 * G_usd / (R_usd * r))

def delta_to_human(d):
    hours = d * 365.25 * 24
    if hours < 1: return f"{hours*60:.0f}min"
    if hours < 24: return f"{hours:.1f}h"
    days = hours / 24
    if days < 7: return f"{days:.1f}d"
    if days < 30: return f"{days/7:.1f}w"
    if days < 365: return f"{days/30:.1f}mo"
    return f"{days/365:.1f}yr"

# ─── Compute data ────────────────────────────────────────────────────────────
era_labels = [e[0] for e in gas_eras]
era_gwei = [e[1] for e in gas_eras]
era_usd = [gas_cost_usd(g) for g in era_gwei]

# Print summary table
print("=" * 90)
print(f"{'Gas Era':<25} {'Gwei':>8} {'Cost/Call':>12}   {'ETH':>10}  {'USDC':>10}  {'WBTC':>12}")
print("=" * 90)
for label_raw, gwei in gas_eras:
    label = label_raw.replace('\n', ' ')
    g = gas_cost_usd(gwei)
    vals = {}
    for mkt_name, m in markets.items():
        d = optimal_delta_years(g, m["R_usd"], m["r"])
        vals[mkt_name] = delta_to_human(d)
    print(f"{label:<25} {gwei:>8.1f} ${g:>10.4f}   {vals['ETH']:>10}  {vals['USDC']:>10}  {vals['WBTC']:>12}")
print()

# ─── Chart 1: Grouped bar chart ──────────────────────────────────────────────
fig, ax = plt.subplots(figsize=(16, 8))

x = np.arange(len(era_labels))
width = 0.25
offsets = [-width, 0, width]

for i, (mkt_name, m) in enumerate(markets.items()):
    intervals_hours = []
    for gwei in era_gwei:
        g = gas_cost_usd(gwei)
        d = optimal_delta_years(g, m["R_usd"], m["r"])
        intervals_hours.append(d * 365.25 * 24)
    bars = ax.bar(x + offsets[i], intervals_hours, width, label=mkt_name,
                  color=m["color"], edgecolor="white", linewidth=0.5, alpha=0.85)
    for bar, val, gwei in zip(bars, intervals_hours, era_gwei):
        d = optimal_delta_years(gas_cost_usd(gwei), m["R_usd"], m["r"])
        label_str = delta_to_human(d)
        ax.text(bar.get_x() + bar.get_width()/2, bar.get_height(),
                label_str, ha="center", va="bottom", fontsize=6.5, fontweight="bold",
                color=m["color"])

ax.set_yscale("log")
ax.set_ylabel("Optimal Minting Interval (hours, log scale)", fontsize=12)
ax.set_xlabel("Historical Gas Price Era", fontsize=12)
ax.set_title(
    "Optimal mintFeeShares() Interval by Historical Gas Price\n"
    f"(mintFeeShares = {MINT_FEE_SHARES_GAS:,} gas, ETH=\\${ETH_PRICE:,.2f})",
    fontsize=13, fontweight="bold"
)
ax.set_xticks(x)
ax.set_xticklabels(era_labels, fontsize=9)
ax.legend(fontsize=11)
ax.grid(True, which="both", axis="y", alpha=0.3)

# Add secondary y-axis labels for days
ax2 = ax.twinx()
ax2.set_yscale("log")
ax2.set_ylim(ax.get_ylim())
day_ticks = [1, 6, 24, 24*7, 24*30, 24*365]
day_labels = ["1 hour", "6 hours", "1 day", "1 week", "1 month", "1 year"]
ax2.set_yticks(day_ticks)
ax2.set_yticklabels(day_labels, fontsize=9)
ax2.set_ylabel("", fontsize=1)

plt.tight_layout()
plt.savefig("docs/optimal_interval_historical_gas.png", dpi=150)
print("Saved docs/optimal_interval_historical_gas.png")
plt.close()


# ─── Chart 2: Line chart — continuous gas price range w/ historical markers ──
fig, ax = plt.subplots(figsize=(14, 8))

gas_range_gwei = np.logspace(-0.5, 2.3, 500)  # 0.3 to 200 gwei
gas_range_usd = [gas_cost_usd(g) for g in gas_range_gwei]

for mkt_name, m in markets.items():
    intervals_hours = [optimal_delta_years(g, m["R_usd"], m["r"]) * 365.25 * 24
                       for g in gas_range_usd]
    ax.loglog(gas_range_gwei, intervals_hours, color=m["color"], linewidth=2.5,
              label=f"{mkt_name} (R=\\${m['R_usd']/1e6:.2f}M/yr, APY={m['r']*100:.2f}%)")

# Mark historical eras
era_colors = ["#e74c3c", "#e67e22", "#f39c12", "#27ae60", "#2ecc71", "#1abc9c", "#3498db"]
for (label_raw, gwei), color in zip(gas_eras, era_colors):
    label = label_raw.replace('\n', ' ')
    ax.axvline(x=gwei, color=color, linestyle="--", linewidth=1, alpha=0.7)
    ax.text(gwei, ax.get_ylim()[0] if ax.get_ylim()[0] > 0 else 1,
            f"  {label}", fontsize=7.5, color=color, rotation=90,
            va="bottom", ha="left", fontweight="bold")

ax.set_xlabel("Gas Price (gwei)", fontsize=12)
ax.set_ylabel("Optimal Minting Interval (hours)", fontsize=12)
ax.set_title(
    "Optimal mintFeeShares() Interval vs Gas Price — All Markets\n"
    f"(mintFeeShares = {MINT_FEE_SHARES_GAS:,} gas, ETH=\\${ETH_PRICE:,.2f})",
    fontsize=13, fontweight="bold"
)
ax.grid(True, which="both", alpha=0.3)
ax.legend(fontsize=10, loc="upper left")

# Right-side human-readable labels
ax2 = ax.twinx()
ax2.set_yscale("log")
ax2.set_ylim(ax.get_ylim())
day_ticks = [1, 6, 24, 24*7, 24*30, 24*365]
day_labels = ["1 hour", "6 hours", "1 day", "1 week", "1 month", "1 year"]
valid = [(t, l) for t, l in zip(day_ticks, day_labels)
         if ax.get_ylim()[0] <= t <= ax.get_ylim()[1]]
if valid:
    ax2.set_yticks([v[0] for v in valid])
    ax2.set_yticklabels([v[1] for v in valid], fontsize=9)

plt.tight_layout()
plt.savefig("docs/optimal_interval_vs_gasprice.png", dpi=150)
print("Saved docs/optimal_interval_vs_gasprice.png")
plt.close()
