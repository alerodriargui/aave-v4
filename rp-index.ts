const RAY = 10n ** 27n;
const YEAR = 31536000n;
function bpsToRay(bps: number) {
    return BigInt(bps) * RAY / 100_00n;
}    
function calcLinearInterest(rate: bigint, timeDelta: bigint) {
    const result = rate * timeDelta;
    return RAY + result / YEAR;
}

const rate = bpsToRay(0.1e4)

const index1 = calcLinearInterest(rate, 0n)
const index2 = calcLinearInterest(rate, 1n * YEAR)
const index3 = calcLinearInterest(rate, 2n * YEAR)

console.log('index1 %27e, index2 %27e, index3 %27e', index1, index2, index3)

console.log('change between index1 and index2 %27e, expected %27e', (index2 * RAY) / index1, calcLinearInterest(rate, 1n * YEAR))


