# Aave v4 rounding

Explanation of the rounding directions within the Aave V4 protocol.

## Rounding

- when supplying assets, the resulting shares added on behalf of a user are rounded down.
- when withdrawing assets, the resulting shares removed from a user position are rounded up.
- when borrowing assets, the resulting drawn shares representing a user's debt are rounded up.
- when repaying assets, the resulting drawn shares removed from a user's debt are rounded down.
- when calculating the liquidation fee portion of a liquidation to distribute to the treasury, the result is rounded down.
- when calculating the value of a user's supplied collateral in the base currency, the result is rounded down.
- when calculating the value of a user's total debt in the base currency, the result is rounded up.
- when calculating the total amount of an asset supplied to the protocol (totalAddedAssets), the result is rounded down.
