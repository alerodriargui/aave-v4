function addToWeightedAverage(
  currentWeightedAvg,
  currentSumWeights,
  newValue,
  newValueWeight
) {
  if (newValueWeight === 0n) {
    return [currentWeightedAvg, currentSumWeights];
  }
  if (currentSumWeights === 0n) {
    return [newValue, newValueWeight];
  }

  console.log("add");
  console.log(newValue, newValueWeight);
  console.log(currentWeightedAvg, currentSumWeights);

  const newSumWeights = currentSumWeights + newValueWeight;
  const newWeightedAvg =
    (currentWeightedAvg * currentSumWeights + newValue * newValueWeight) /
    newSumWeights;

  return [newWeightedAvg, newSumWeights];
}

function subtractFromWeightedAverage(
  currentWeightedAvg,
  currentSumWeights,
  newValue,
  newValueWeight
) {
  if (newValueWeight === 0n) {
    return [currentWeightedAvg, currentSumWeights];
  }

  if (currentSumWeights === newValueWeight) {
    return [0n, 0n];
  }
  if (currentSumWeights < newValueWeight) {
    throw new Error("newValueWeight is greater than currentSumWeights");
  }

  const newWeightedValue = newValue * newValueWeight;
  const currentWeightedSum = currentWeightedAvg * currentSumWeights;

  console.log(newValue, newValueWeight);
  console.log(currentWeightedAvg, currentSumWeights);

  if (currentWeightedSum < newWeightedValue) {
    throw new Error("newWeightedValue is greater than currentWeightedSum");
  }

  const newSumWeights = currentSumWeights - newValueWeight;
  const newWeightedAvg =
    (currentWeightedSum - newWeightedValue) / newSumWeights;

  return [newWeightedAvg, newSumWeights];
}

// const MULTIPLIER = 10n ** 36n;
// const values = [
//   200270888961088502n,
//   30n,
//   900270888961088502n,
//   900270888961088502n,
//   900270888961088502n,
// ].map((a) => a * MULTIPLIER);
// const weights = [
//   350892168986200270888961088502n,
//   30n,
//   950892168986200270888961088509n,
//   950892168986200270888961088509n,
//   950892168986200270888961088509n,
// ];

// const toRemove = [0, 2, 3, 4];

const MULTIPLIER = 10n ** 18n;
const values = [
  6994558642899766525213756686980474114657n,
  295539632709645506335497881n,
  4518665859835766492408027040892612118836n,
  4022172284556747385114782264790801754n,
  7804459145905499248567493856055210788773n,
].map((a) => a * MULTIPLIER);
const weights = [
  587190520470810964496990008533n,
  870300654252243063879479276566n,
  793850986694249993325032070764n,
  62378152749241338750457466252n,
  63131558699418281431348121377n,
];
const toRemove = [];

let currentWeightedAvg = 0n,
  currentSumWeights = 0n,
  calcWeightedAvg = 0n,
  calcSumWeights = 0n;

for (let i = 0; i < values.length; i++) {
  console.log("i", i);
  [currentWeightedAvg, currentSumWeights] = addToWeightedAverage(
    currentWeightedAvg,
    currentSumWeights,
    values[i],
    weights[i]
  );
  calcWeightedAvg += (values[i] * weights[i]) / MULTIPLIER;
  calcSumWeights += weights[i];
  console.log("->", currentWeightedAvg, currentSumWeights);
}

for (let j = 0; j < toRemove.length; j++) {
  [currentWeightedAvg, currentSumWeights] = subtractFromWeightedAverage(
    currentWeightedAvg,
    currentSumWeights,
    values[toRemove[j]],
    weights[toRemove[j]]
  );
  calcWeightedAvg -= (values[toRemove[j]] * weights[toRemove[j]]) / MULTIPLIER;
  calcSumWeights -= weights[toRemove[j]];
}

if (calcSumWeights != 0) calcWeightedAvg /= calcSumWeights;

console.log({ currentWeightedAvg, currentSumWeights });
console.log({
  currentWeightedAvg: currentWeightedAvg / MULTIPLIER,
  currentSumWeights,
});

console.log({ calcWeightedAvg, calcSumWeights });

console.log("weighted avg, current", currentWeightedAvg);
console.log("weighted avg, current", currentWeightedAvg / MULTIPLIER);
console.log("weighted avg, calc   ", calcWeightedAvg);
