# Supply Rate Inflation from Unminted Fee Shares

## Variables

| Symbol | Meaning                                      |
| ------ | -------------------------------------------- |
| `L`    | Liquidity (idle assets in the pool)          |
| `D`    | Total drawn (borrowed) assets                |
| `S`    | Swept assets                                 |
| `A₀`   | Total pool assets = `L + S + D`              |
| `r_b`  | Borrow rate (APY)                            |
| `f`    | Liquidity fee (reserve factor)               |
| `U`    | Accumulated unminted fees                    |
| `r_s`  | Ideal supply rate = `(D / A₀) × r_b × (1-f)` |

## How Interest Flows

Borrowers pay interest at rate `r_b` on `D` drawn assets:

```
Total interest per year = D × r_b
```

This is split:

- **Protocol fee**: `D × r_b × f` → added to `U` (realizedFees)
- **Supplier interest**: `D × r_b × (1-f)` → grows `totalAddedAssets`

## Share Price and Supply Rate

In V4, the share price used for conversions is:

```
sharePrice = totalAddedAssets / addedShares
```

where:

```
totalAddedAssets = L + S + D - U = A₀ - U
```

Fees `U` are subtracted (AssetLogic.sol, lines 91–96).

The supply rate is the rate of growth of `totalAddedAssets`:

```
supply_rate = [D × r_b × (1-f)] / totalAddedAssets
            = [D × r_b × (1-f)] / (A₀ - U)
```

## The Inflation

### Ideal Case (U = 0, fees minted continuously)

```
r_s = [D × r_b × (1-f)] / A₀
```

### With Unminted Fees (U > 0)

```
r_s_inflated = [D × r_b × (1-f)] / (A₀ - U)
```

The numerator is unchanged — the same total interest is generated. But it's distributed over a smaller `totalAddedAssets` denominator.

### Inflation Factor

```
r_s_inflated / r_s = A₀ / (A₀ - U)  =  1 / (1 - U/A₀)
```

### Extra Supply Rate

```
extra_rate = r_s_inflated - r_s
           = r_s × U / (A₀ - U)
```

## Why This Happens

When fee shares are minted:

- Treasury gets shares worth `U`
- These shares earn at rate `r_s`
- Treasury's portion of interest = `U × r_s`

When fee shares are NOT minted:

- Treasury has no shares
- That same `U × r_s` of interest goes to existing suppliers instead
- Existing suppliers earn at `r_s_inflated > r_s`

**Total value transferred from treasury to suppliers per year = `U × r_s`**

This is exactly the opportunity cost from the earlier analysis.

## Accumulation Over Time

If fees accumulate uniformly at rate `φ = D × r_b × f` per year:

```
U(t) = φ × t
```

```
inflation_factor(t) = 1 / (1 - φt/A₀)
```

```
extra_rate(t) = r_s × (φt/A₀) / (1 - φt/A₀)
```

## ETH Market Example

| Parameter | Value                        |
| --------- | ---------------------------- |
| `D`       | 2.85M ETH ($5.615B)          |
| `A₀`      | 3.06M ETH ($6.028B)          |
| `r_b`     | 2.46%                        |
| `f`       | 15%                          |
| `r_s`     | 1.94%                        |
| `φ`       | 10,516.5 ETH/yr ($20.72M/yr) |

After 1 year without minting (`U = $20.72M`):

```
U/A₀ = $20.72M / $6.028B = 0.344%
inflation_factor = 1.00345
r_s_inflated = 1.94% × 1.00345 = 1.9467%
extra_rate = 0.0067%
```

Value transferred to suppliers = `$20.72M × 1.94%` = **$401,968/yr**

## Minting Interval to Cap Inflation

**Goal**: If I want to keep the extra supply rate inflation below `X`, how often should I mint?

At time `T` since the last mint, `U = φ × T`. Setting `extra_rate ≤ X`:

```
r_s × φT / (A₀ - φT) ≤ X
```

Solving for `T`:

```
T ≤ (X × A₀) / (φ × (r_s + X))
```

Since in practice `X << r_s`, this simplifies to:

```
T ≈ (X × A₀) / (φ × r_s)
```

### ETH Market Examples

Using `A₀ = $6.028B`, `φ = $20.72M/yr`, `r_s = 1.94%`:

| Max Extra Rate (X) | Minting Interval (T)                                 |
| ------------------ | ---------------------------------------------------- |
| 1 bps (0.01%)      | `0.01% × $6.028B / ($20.72M × 1.94%)` = **150 days** |
| 0.1 bps (0.001%)   | **15 days**                                          |
| 0.01 bps (0.0001%) | **1.5 days**                                         |

### General Formula

```
T = X × A₀ / (φ × r_s)

where:
  X  = maximum tolerable extra supply rate
  A₀ = L + S + D  (total pool assets)
  φ  = D × r_b × f  (fee accrual rate, $/year)
  r_s = (D/A₀) × r_b × (1-f)  (ideal supply rate)
```

Substituting `φ` and `r_s`:

```
T = X / (D × r_b × f × (D/A₀) × r_b × (1-f) / A₀)
  = (X × A₀²) / (D² × r_b² × f × (1-f))
```
