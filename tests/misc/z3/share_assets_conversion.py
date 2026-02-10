# Highlights the fact that supplies shares are always equal to removed shares (after doing the conversion to assets and back to shares).
from commons import *

s = Solver()

totalAddedAssets = Int('totalAddedAssets')
s.add(0 <= totalAddedAssets, totalAddedAssets <= 10**30)
totalAddedShares = Int('totalAddedShares')
s.add(
    totalAddedAssets >= totalAddedShares,
    totalAddedAssets + VIRTUAL_ASSETS < (totalAddedShares + VIRTUAL_SHARES) * 100,
)
suppliedShares = Int('suppliedShares')
s.add(0 <= suppliedShares, suppliedShares <= totalAddedShares)

withdrawableAssets = previewRemoveByShares(
    suppliedShares, totalAddedAssets, totalAddedShares
)
removedShares = previewRemoveByAssets(
    withdrawableAssets, totalAddedAssets, totalAddedShares
)

proveValid(
    s,
    'Supplied shares are always equal to removed shares (after conversion to assets and back to shares)',
    removedShares == suppliedShares,
)
