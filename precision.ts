import {
  absDiff,
  random,
  randomIndex,
  RAY,
  rayDiv,
  rayMul,
  Rounding,
} from './tests/ts/prototype/utils';

const main = () => {
  for (let i = 0; i < 100000; i++) {
    const sharePrice = randomIndex();
    const amount = random(1n, 10n ** 10n);
    const share = rayDiv(amount, sharePrice, Rounding.FLOOR);
    const index = rayDiv(amount, share);
    const diff = absDiff(index, sharePrice);
    console.log(diff);
  }
};
main();
