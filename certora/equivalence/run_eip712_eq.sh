#!/bin/bash

CONF="certora/equivalence/eip712HashEquivalence.conf"
CORRECT="EIP712HashCorrect"
OPTIMIZED="EIP712HashOptimized"

METHODS=(
  hashPositionManagerUpdate
  hashSetUserPositionManagers
  hashTokenizedDeposit
  hashTokenizedMint
  hashTokenizedWithdraw
  hashTokenizedRedeem
  hashSupply
  hashWithdraw
  hashBorrow
  hashRepay
  hashSetUsingAsCollateral
  hashUpdateUserRiskPremium
  hashUpdateUserDynamicConfig
)

for method in "${METHODS[@]}"; do
  echo "=== Running equivalence check for: $method ==="
  certoraEqCheck conf "$CONF" "$CORRECT:$method" "$OPTIMIZED:$method"
  echo ""
done
