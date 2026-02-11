import matplotlib.pyplot as plt
import matplotlib.ticker as mticker
import numpy as np

BORROWED_ETH     = 2_850_000
BORROW_APY       = 0.0246
SUPPLY_APY       = 0.0194
RESERVE_FACTOR   = 0.15
ETH_PRICE        = 1_970.06
ANNUAL_REVENUE_USD = BORROWED_ETH * BORROW_APY * RESERVE_FACTOR * ETH_PRICE
T = 5

intervals = {
    "1 year":    1.0,
    "6 months":  0.5,
    "3 months":  0.25,
    "1 month":   1/12,
    "2 weeks":   2/52,
    "1 week":    1/52,
    "1 day":     1/365,
    "1 hour":    1/(365*24),
}

def interest_earned(R, r, T, delta):
    return R * r * T * (T - delta) / 2

max_interest = interest_earned(ANNUAL_REVENUE_USD, SUPPLY_APY, T, 0)
labels = list(intervals.keys())
deltas = list(intervals.values())
interests = [interest_earned(ANNUAL_REVENUE_USD, SUPPLY_APY, T, d) for d in deltas]

fig, ax = plt.subplots(figsize=(12, 7))
colors = plt.cm.viridis(np.linspace(0.2, 0.9, len(labels)))
bars = ax.bar(labels, interests, color=colors, edgecolor="white", linewidth=0.8)
ax.axhline(y=max_interest, color="#e74c3c", linestyle="--", linewidth=1.5,
           label=f"Continuous minting limit: ${max_interest:,.0f}")
for bar, val in zip(bars, interests):
    ax.text(bar.get_x() + bar.get_width()/2, bar.get_height() + 40_000,
            f"${val:,.0f}", ha="center", va="bottom", fontsize=8, fontweight="bold")
ax.set_ylabel("Total Interest Earned Over 5 Years (USD)", fontsize=12)
ax.set_xlabel("Minting Interval", fontsize=12)
ax.set_title(
    "Treasury Interest Earned by mintFeeShares() Frequency (5-Year Horizon)\n"
    f"(ETH Market: {BORROWED_ETH/1e6:.2f}M borrowed, {BORROW_APY*100:.2f}% borrow APY, "
    f"{RESERVE_FACTOR*100:.0f}% reserve factor, ETH=${ETH_PRICE:,.2f})",
    fontsize=12, fontweight="bold")
ax.yaxis.set_major_formatter(mticker.FuncFormatter(lambda x, _: f"${x:,.0f}"))
ax.legend(fontsize=11)
ax.tick_params(axis="x", rotation=30)
plt.tight_layout()
plt.savefig("docs/mint_interval_interest_5yr.png", dpi=150)
print("Saved docs/mint_interval_interest_5yr.png")
for label, interest in zip(labels, interests):
    print(f"{label:<12} ${interest:>14,.2f}")
print(f"{'Continuous':<12} ${max_interest:>14,.2f}")
