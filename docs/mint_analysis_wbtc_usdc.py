"""
Opportunity Cost Analysis for mintFeeShares() — WBTC & USDC Markets

WBTC Market (Ethereum, 2/11/26):
  - 42.22K WBTC supplied, supply APY 0.01%
  - 1,236.42 WBTC borrowed at 0.34% borrow APY
  - Reserve factor: 50%
  - WBTC price: $67,466.82

USDC Market (Ethereum, 2/11/26):
  - 3.91B USDC supplied, supply APY 2.36%
  - 2.7B USDC borrowed at 3.82% borrow APY
  - Reserve factor: 10%
  - USDC price: $1
"""

import matplotlib.pyplot as plt
import matplotlib.ticker as mticker
import numpy as np

# ─── Market definitions ──────────────────────────────────────────────────────
markets = {
    "WBTC": {
        "supplied":       42_220,
        "supply_apy":     0.0001,      # 0.01%
        "borrowed":       1_236.42,
        "borrow_apy":     0.0034,      # 0.34%
        "reserve_factor": 0.50,        # 50%
        "price":          67_466.82,
        "unit":           "WBTC",
    },
    "USDC": {
        "supplied":       3_910_000_000,
        "supply_apy":     0.0236,      # 2.36%
        "borrowed":       2_700_000_000,
        "borrow_apy":     0.0382,      # 3.82%
        "reserve_factor": 0.10,        # 10%
        "price":          1.0,
        "unit":           "USDC",
    },
}

ETH_PRICE = 1_970.06  # for gas cost conversion

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

def optimal_delta(G_usd, R_usd, r):
    return np.sqrt(2 * G_usd / (R_usd * r))

def delta_to_human(delta_years):
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

# ─── Generate per-market analysis ────────────────────────────────────────────
for name, m in markets.items():
    annual_rev_native = m["borrowed"] * m["borrow_apy"] * m["reserve_factor"]
    annual_rev_usd = annual_rev_native * m["price"]
    r = m["supply_apy"]

    print("=" * 75)
    print(f"{name} MARKET ANALYSIS")
    print("=" * 75)
    print(f"  Borrowed:        {m['borrowed']:,.2f} {m['unit']}")
    print(f"  Borrow APY:      {m['borrow_apy']*100:.2f}%")
    print(f"  Supply APY:      {m['supply_apy']*100:.2f}%")
    print(f"  Reserve Factor:  {m['reserve_factor']*100:.0f}%")
    print(f"  Price:           ${m['price']:,.2f}")
    print(f"  Annual Revenue:  {annual_rev_native:,.4f} {m['unit']} = ${annual_rev_usd:,.2f}")
    print()

    # ── Bar chart: 3-year and 5-year horizons ──
    for T in [3, 5]:
        max_interest = interest_earned(annual_rev_usd, r, T, 0)
        labels = list(intervals.keys())
        deltas = list(intervals.values())
        interests = [interest_earned(annual_rev_usd, r, T, d) for d in deltas]

        fig, ax = plt.subplots(figsize=(12, 7))
        colors = plt.cm.viridis(np.linspace(0.2, 0.9, len(labels)))
        bars = ax.bar(labels, interests, color=colors, edgecolor="white", linewidth=0.8)

        ax.axhline(y=max_interest, color="#e74c3c", linestyle="--", linewidth=1.5,
                   label=f"Continuous minting limit: ${max_interest:,.2f}")

        for bar, val in zip(bars, interests):
            offset = max_interest * 0.015
            ax.text(bar.get_x() + bar.get_width()/2, bar.get_height() + offset,
                    f"${val:,.2f}", ha="center", va="bottom", fontsize=7.5, fontweight="bold")

        ax.set_ylabel(f"Total Interest Earned Over {T} Years (USD)", fontsize=12)
        ax.set_xlabel("Minting Interval", fontsize=12)
        price_str = f"{m['price']:,.2f}"
        ax.set_title(
            f"Treasury Interest Earned by mintFeeShares() Frequency ({T}-Year, {name})\n"
            f"({m['borrowed']:,.2f} {m['unit']} borrowed, {m['borrow_apy']*100:.2f}% borrow APY, "
            f"{m['reserve_factor']*100:.0f}% RF, {m['unit']}=\${price_str})",
            fontsize=11, fontweight="bold"
        )
        ax.yaxis.set_major_formatter(mticker.FuncFormatter(lambda x, _: f"${x:,.2f}"))
        ax.legend(fontsize=10)
        ax.tick_params(axis="x", rotation=30)
        plt.tight_layout()
        fname = f"docs/mint_interval_{name.lower()}_{T}yr.png"
        plt.savefig(fname, dpi=150)
        print(f"  Saved {fname}")
        plt.close()

        # Print table
        print(f"\n  {T}-YEAR INTEREST TABLE:")
        print(f"  {'Interval':<12} {'Interest Earned':<20}")
        print(f"  {'-' * 35}")
        for label, interest in zip(labels, interests):
            print(f"  {label:<12} ${interest:>14,.2f}")
        print(f"  {'Continuous':<12} ${max_interest:>14,.2f}")
        print()

    # ── Optimal minting interval chart ──
    gas_costs = np.logspace(-1, 2, 500)

    fig, ax = plt.subplots(figsize=(10, 7))
    deltas_optimal = [optimal_delta(g, annual_rev_usd, r) for g in gas_costs]
    deltas_hours = [d * 365.25 * 24 for d in deltas_optimal]

    ax.loglog(gas_costs, deltas_hours, color="#2980b9", linewidth=2.5)
    ax.set_xlabel("Gas Cost per mintFeeShares() Call (USD)", fontsize=12)
    ax.set_ylabel("Optimal Minting Interval (hours)", fontsize=12)
    rev_str = f"{annual_rev_usd:,.2f}"
    price_str2 = f"{m['price']:,.2f}"
    ax.set_title(
        f"Optimal Minting Interval vs. Gas Cost ({name})\n"
        f"(R = \${rev_str}/yr, supply APY = {r*100:.2f}%, "
        f"{m['unit']}=\${price_str2})",
        fontsize=11, fontweight="bold"
    )
    ax.grid(True, which="both", alpha=0.3)

    for ref_gas, label in [(0.50, "$0.50"), (2.0, "$2"), (10.0, "$10"), (50.0, "$50")]:
        d = optimal_delta(ref_gas, annual_rev_usd, r)
        h = d * 365.25 * 24
        ax.plot(ref_gas, h, "o", color="#e74c3c", markersize=8, zorder=5)
        ax.annotate(f"{label} gas → {delta_to_human(d)}",
                    xy=(ref_gas, h), xytext=(ref_gas * 2, h * 2),
                    fontsize=9, fontweight="bold",
                    arrowprops=dict(arrowstyle="->", color="#e74c3c"),
                    color="#e74c3c")

    plt.tight_layout()
    fname = f"docs/optimal_mint_interval_{name.lower()}.png"
    plt.savefig(fname, dpi=150)
    print(f"  Saved {fname}")
    plt.close()

    # Print optimal intervals
    print(f"\n  OPTIMAL MINTING INTERVALS ({name}):")
    print(f"  {'Gas Cost':<12} {'Optimal Interval'}")
    print(f"  {'-' * 30}")
    for g in [0.10, 0.50, 1.0, 2.0, 5.0, 10.0, 25.0, 50.0, 100.0]:
        d = optimal_delta(g, annual_rev_usd, r)
        print(f"  ${g:<10.2f} {delta_to_human(d)}")

    # Price-dependent form for non-ETH
    print(f"\n  GENERALIZED FORMULA ({name}):")
    print(f"  Δ* = sqrt(2 × G_eth × P_eth / (R_{name.lower()} × P_{name.lower()} × r))")
    print(f"  R_{name.lower()} = {annual_rev_native:,.4f} {m['unit']}/year")
    print(f"  P_{name.lower()} = ${m['price']:,.2f}")
    print(f"  P_eth = ${ETH_PRICE:,.2f}")
    print()


# ─── Combined comparison chart ───────────────────────────────────────────────
fig, ax = plt.subplots(figsize=(12, 7))
gas_costs = np.logspace(-1, 2, 500)

all_markets = {
    "ETH": {"rev_usd": 2_850_000 * 0.0246 * 0.15 * ETH_PRICE, "supply_apy": 0.0194, "price": ETH_PRICE},
    "WBTC": {"rev_usd": markets["WBTC"]["borrowed"] * markets["WBTC"]["borrow_apy"] * markets["WBTC"]["reserve_factor"] * markets["WBTC"]["price"],
             "supply_apy": markets["WBTC"]["supply_apy"], "price": markets["WBTC"]["price"]},
    "USDC": {"rev_usd": markets["USDC"]["borrowed"] * markets["USDC"]["borrow_apy"] * markets["USDC"]["reserve_factor"] * markets["USDC"]["price"],
             "supply_apy": markets["USDC"]["supply_apy"], "price": markets["USDC"]["price"]},
}

colors_map = {"ETH": "#627EEA", "WBTC": "#F7931A", "USDC": "#2775CA"}

for mkt_name, mkt in all_markets.items():
    deltas_h = [optimal_delta(g, mkt["rev_usd"], mkt["supply_apy"]) * 365.25 * 24
                for g in gas_costs]
    ax.loglog(gas_costs, deltas_h, color=colors_map[mkt_name], linewidth=2.5,
              label=f"{mkt_name} (R=${mkt['rev_usd']/1e6:.2f}M/yr, APY={mkt['supply_apy']*100:.2f}%)")

ax.set_xlabel("Gas Cost per mintFeeShares() Call (USD)", fontsize=12)
ax.set_ylabel("Optimal Minting Interval (hours)", fontsize=12)
ax.set_title("Optimal Minting Interval — ETH vs WBTC vs USDC Markets",
             fontsize=13, fontweight="bold")
ax.grid(True, which="both", alpha=0.3)
ax.legend(fontsize=10)
plt.tight_layout()
plt.savefig("docs/optimal_mint_interval_comparison.png", dpi=150)
print("Saved docs/optimal_mint_interval_comparison.png")
plt.close()
