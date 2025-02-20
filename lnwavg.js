// (v1 * w1 + v2 * w2) / (w1 + w2)

// ln (avg) = ln(v1 * w1 + v2 * w2) - ln(w1 + w2)
// Weighted average calculations using logarithms to avoid precision loss.

function addToWeightedAverageLog(
  logCurrentWeightedAvg, // Logarithm of the current weighted average
  logCurrentSumWeights, // Logarithm of the current sum of weights
  newValue, // New value to add
  newValueWeight // Weight of the new value
) {
  if (newValueWeight === 0n) {
    return [logCurrentWeightedAvg, logCurrentSumWeights];
  }

  const logNewValueWeight = Math.log(Number(newValueWeight));
  const logNewValue = Math.log(Number(newValue));

  if (logCurrentSumWeights === -Infinity) {
    // If the current sum of weights is zero, return the new value and weight.
    return [logNewValue, logNewValueWeight];
  }

  const logWeightedSum = Math.log(
    Math.exp(logCurrentWeightedAvg + logCurrentSumWeights) +
      Math.exp(logNewValue + logNewValueWeight)
  );

  const logNewSumWeights = Math.log(
    Math.exp(logCurrentSumWeights) + Math.exp(logNewValueWeight)
  );

  const logNewWeightedAvg = logWeightedSum - logNewSumWeights;

  return [logNewWeightedAvg, logNewSumWeights];
}

function subtractFromWeightedAverageLog(
  logCurrentWeightedAvg, // Logarithm of the current weighted average
  logCurrentSumWeights, // Logarithm of the current sum of weights
  newValue, // Value to subtract
  newValueWeight // Weight of the value to subtract
) {
  if (newValueWeight === 0n) {
    return [logCurrentWeightedAvg, logCurrentSumWeights];
  }

  const logNewValueWeight = Math.log(Number(newValueWeight));
  const logNewValue = Math.log(Number(newValue));

  const logWeightedValue = logNewValue + logNewValueWeight;
  const logCurrentWeightedSum = logCurrentWeightedAvg + logCurrentSumWeights;

  if (logCurrentSumWeights <= logNewValueWeight) {
    throw new Error(
      "newValueWeight is greater than or equal to currentSumWeights"
    );
  }

  const logNewSumWeights = Math.log(
    Math.exp(logCurrentSumWeights) - Math.exp(logNewValueWeight)
  );

  const logNewWeightedSum = Math.log(
    Math.exp(logCurrentWeightedSum) - Math.exp(logWeightedValue)
  );

  const logNewWeightedAvg = logNewWeightedSum - logNewSumWeights;

  return [logNewWeightedAvg, logNewSumWeights];
}

// Helper function to convert log space values back to normal space
function expLog(logValue) {
  return Math.exp(logValue);
}

// Testing the logarithmic implementation
const values = [200270888961088502n, 30n];
const weights = [350892168986200270888961088502n, 30n];

const toRemove = 0;

let logCurrentWeightedAvg = -Infinity;
let logCurrentSumWeights = -Infinity;

for (let i = 0; i < values.length; i++) {
  console.log("i", i);
  [logCurrentWeightedAvg, logCurrentSumWeights] = addToWeightedAverageLog(
    logCurrentWeightedAvg,
    logCurrentSumWeights,
    values[i],
    weights[i]
  );
  console.log(
    "->",
    expLog(logCurrentWeightedAvg),
    expLog(logCurrentSumWeights)
  );
}

[logCurrentWeightedAvg, logCurrentSumWeights] = subtractFromWeightedAverageLog(
  logCurrentWeightedAvg,
  logCurrentSumWeights,
  values[toRemove],
  weights[toRemove]
);

console.log(expLog(logCurrentWeightedAvg), expLog(logCurrentSumWeights));
