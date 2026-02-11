from commons import *

UINT256_MAX = IntVal(2**256 - 1)
SECONDS_PER_YEAR = IntVal(365 * 24 * 60 * 60)

rate = IntVal(2**96 - 1)
lastUpdateTimestamp = IntVal(1)
currentTimestamp = Int('currentTimestamp')
elapsed = currentTimestamp - lastUpdateTimestamp

maximise(
    currentTimestamp,
    'Maximum currentTimestamp for calculateLinearInterest',
    assumptions=[
        elapsed >= 0,
        rate * elapsed <= UINT256_MAX,
        RAY + ((rate * elapsed) / SECONDS_PER_YEAR) <= UINT256_MAX,
    ],
    variables=[(currentTimestamp, 'currentTimestamp')],
)
