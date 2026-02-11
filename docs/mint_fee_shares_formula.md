# Closed-Form Formula for `mintFeeShares()` Opportunity Cost

## Variables

| Symbol | Meaning                          | Example Value   |
| ------ | -------------------------------- | --------------- |
| **R**  | Annual revenue to treasury (USD) | $20,718,135.99  |
| **r**  | Supply APY (decimal)             | 0.0194          |
| **T**  | Total time horizon (years)       | 3               |
| **Δ**  | Minting interval (years)         | 0.25, 0.5, or 1 |

## Total Interest Earned from Minting

The total interest earned by minting fee shares at interval **Δ** over **T** years:

```
Interest(Δ, T) = R × r × T × (T - Δ) / 2
```

### Verification

| Minting Interval (Δ) | Formula                                    | Result        |
| -------------------- | ------------------------------------------ | ------------- |
| 1 year               | R × r × 3 × (3 - 1) / 2 = R × r × 3        | $1,205,795.52 |
| 6 months             | R × r × 3 × (3 - 0.5) / 2 = R × r × 3.75   | $1,507,244.40 |
| 3 months             | R × r × 3 × (3 - 0.25) / 2 = R × r × 4.125 | $1,657,968.84 |

## Opportunity Cost Between Two Minting Intervals

The difference in interest earned between minting at interval **Δ₁** vs a more frequent interval **Δ₂** (where Δ₁ > Δ₂):

```
Cost(Δ₁, Δ₂) = R × r × T × (Δ₁ - Δ₂) / 2
```

> [!NOTE]
> This is **linear** in the difference of minting periods — useful for cost-benefit analysis against gas costs.

### Example

Yearly vs quarterly over 3 years:

```
Cost(1, 0.25) = $20,718,135.99 × 0.0194 × 3 × (1 - 0.25) / 2
             = $401,931.84 × 3 × 0.375
             = $452,173.23
```

## Continuous Minting Limit

As **Δ → 0** (continuous minting), the maximum possible interest is:

```
Interest_max(T) = R × r × T² / 2
```

For T = 3 years: **$1,808,693.28**

The cost of minting at interval **Δ** vs continuous minting simplifies to:

```
Cost(Δ, 0) = R × r × T × Δ / 2
```

## Optimal Minting Interval

To maximize net benefit (interest earned minus gas spent), we optimize over **Δ**:

```
Net(Δ) = R × r × T × (T - Δ) / 2  -  G × T / Δ
```

Where **G** = gas cost of one `mintFeeShares()` call in USD. Setting the derivative to zero:

```
Δ* = sqrt(2G / (R × r))
```

| Additional Symbol | Meaning                                              |
| ----------------- | ---------------------------------------------------- |
| **G**             | Gas cost per `mintFeeShares()` call (USD)            |
| **G_eth**         | Gas cost per call (ETH)                              |
| **P_eth**         | Price of ETH (USD)                                   |
| **P_asset**       | Price of the market's asset (USD)                    |
| **R_eth**         | Annual treasury revenue (ETH)                        |
| **R_asset**       | Annual treasury revenue (in the asset's native unit) |

### Price-Independent Form (ETH market)

For the ETH market, gas cost and revenue are both denominated in ETH, so the price cancels:

```
Δ* = sqrt(2 × G_eth / (R_eth × r))
```

Where `R_eth = borrowed_eth × borrow_rate × reserve_factor` (= 10,516.5 ETH/year in our example).

> [!IMPORTANT]
> The optimal minting interval for the ETH market is **independent of ETH price**.

### Generalized Form (non-ETH markets)

For markets denominated in a different asset (e.g., WBTC, USDC), the price ratio enters:

```
Δ* = sqrt(2 × G_eth × P_eth / (R_asset × P_asset × r))
```

### Reference Table (ETH market)

Using R = $20.7M/yr, r = 1.94%:

| Gas Cost (USD) | Optimal Interval |
| -------------- | ---------------- |
| $0.10          | ~6 hours         |
| $0.50          | ~14 hours        |
| $1.00          | ~20 hours        |
| $2.00          | ~1.2 days        |
| $5.00          | ~1.8 days        |
| $10.00         | ~2.6 days        |
| $25.00         | ~4.1 days        |
| $50.00         | ~5.8 days        |
| $100.00        | ~1.2 weeks       |

## Assumptions

1. **Simple interest** — does not compound interest-on-interest (negligible at 1.94% APY)
2. **Static market conditions** — supply/borrow amounts, APYs, and ETH price held constant
3. **Interest opportunity cost only** — does not account for share price inflation (value leak to withdrawing suppliers from unminted fees)
