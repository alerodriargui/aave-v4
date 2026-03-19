const fs = require("fs");
const path = require("path");

const ROOT = path.resolve(__dirname, "..", "..", "config");
const config = JSON.parse(
  fs.readFileSync(path.join(ROOT, "config.json"), "utf8"),
);

// --- Helpers ---

function sanitizeKey(key) {
  if (/^\d/.test(key)) return "_" + key;
  return key;
}

function tokenRef(tokenKey) {
  return `Tokens.${sanitizeKey(tokenKey)}`;
}

function hubRef(hubKey) {
  return `Hubs.${hubKey}`;
}

function spokeRef(spokeKey) {
  return `Spokes.${spokeKey}`;
}

function irRef(hubKey) {
  return `IrStrategies.${hubKey}`;
}

// --- Generate hubAssetListings ---

function genHubAssetListings(start = 0, end = undefined) {
  const assets = config.assets.slice(start, end);
  const n = assets.length;
  const lines = [];
  lines.push(
    `  function hubAssetListings() public pure override returns (IAaveV4ConfigEngine.AssetListing[] memory listings) {`,
  );
  lines.push(`    listings = new IAaveV4ConfigEngine.AssetListing[](${n});`);

  for (let i = 0; i < n; i++) {
    const a = assets[i];
    const liquidityFee =
      a.liquidityFee !== undefined
        ? a.liquidityFee
        : config.defaults.asset.liquidityFee;
    const ir = a.irData;
    const tok = a.tokenize || {};
    const tokAddCap = tok.addCap || 0;
    const tokName = tok.name || "";
    const tokSymbol = tok.symbol || "";
    lines.push(`    listings[${i}] = IAaveV4ConfigEngine.AssetListing({
      hubConfigurator: IHubConfigurator(Infra.HUB_CONFIGURATOR),
      hub: ${hubRef(a.hubKey)},
      underlying: ${tokenRef(a.tokenKey)},
      decimals: ${config.tokens[a.tokenKey]?.decimals ?? 0},
      feeReceiver: Infra.TREASURY_SPOKE,
      liquidityFee: ${liquidityFee},
      irStrategy: ${irRef(a.hubKey)},
      irData: IAssetInterestRateStrategy.InterestRateData({
        optimalUsageRatio: ${ir.optimalUsageRatio},
        baseDrawnRate: ${ir.baseDrawnRate},
        rateGrowthBeforeOptimal: ${ir.rateGrowthBeforeOptimal},
        rateGrowthAfterOptimal: ${ir.rateGrowthAfterOptimal}
      }),
      tokenization: IAaveV4ConfigEngine.TokenizationSpokeConfig({
        addCap: ${tokAddCap},
        name: "${tokName}",
        symbol: "${tokSymbol}"
      })
    });`);
  }

  lines.push(`    return listings;`);
  lines.push(`  }`);
  return lines.join("\n");
}

// --- Generate hubSpokeToAssetsAdditions ---

function genHubSpokeToAssetsAdditions() {
  // Group spokeRegistrations by (hubKey, spokeKey), preserving order
  const groups = [];
  const groupMap = {};
  for (const reg of config.spokeRegistrations) {
    const key = `${reg.hubKey}|${reg.spokeKey}`;
    if (!groupMap[key]) {
      groupMap[key] = { hubKey: reg.hubKey, spokeKey: reg.spokeKey, regs: [] };
      groups.push(groupMap[key]);
    }
    groupMap[key].regs.push(reg);
  }

  const defaults = config.defaults.spokeRegistration;
  const n = groups.length;
  const lines = [];
  lines.push(
    `  function hubSpokeToAssetsAdditions() public pure override returns (IAaveV4ConfigEngine.SpokeToAssetsAddition[] memory additions) {`,
  );
  lines.push(
    `    additions = new IAaveV4ConfigEngine.SpokeToAssetsAddition[](${n});`,
  );

  for (let g = 0; g < n; g++) {
    const group = groups[g];
    const regs = group.regs;
    const m = regs.length;
    lines.push(`    {`);
    lines.push(
      `      IAaveV4ConfigEngine.SpokeAssetConfig[] memory assets = new IAaveV4ConfigEngine.SpokeAssetConfig[](${m});`,
    );

    for (let j = 0; j < m; j++) {
      const r = regs[j];
      lines.push(`      assets[${j}] = IAaveV4ConfigEngine.SpokeAssetConfig({
        underlying: ${tokenRef(r.assetKey)},
        config: IHub.SpokeConfig({
          addCap: ${r.addCap},
          drawCap: ${r.drawCap},
          riskPremiumThreshold: ${r.riskPremiumThreshold !== undefined ? r.riskPremiumThreshold : defaults.riskPremiumThreshold},
          active: ${defaults.active},
          halted: ${defaults.halted}
        })
      });`);
    }

    lines.push(`      additions[${g}] = IAaveV4ConfigEngine.SpokeToAssetsAddition({
        hubConfigurator: IHubConfigurator(Infra.HUB_CONFIGURATOR),
        hub: ${hubRef(group.hubKey)},
        spoke: ${spokeRef(group.spokeKey)},
        assets: assets
      });`);
    lines.push(`    }`);
  }

  lines.push(`    return additions;`);
  lines.push(`  }`);
  return lines.join("\n");
}

// --- Generate spokeLiquidationConfigUpdates ---

function genSpokeLiquidationConfigUpdates() {
  const spokes = config.spokes;
  const defaultLiq = config.defaults.spoke.liquidationConfig;
  const n = spokes.length;
  const lines = [];
  lines.push(
    `  function spokeLiquidationConfigUpdates() public pure override returns (IAaveV4ConfigEngine.LiquidationConfigUpdate[] memory updates) {`,
  );
  lines.push(
    `    updates = new IAaveV4ConfigEngine.LiquidationConfigUpdate[](${n});`,
  );

  for (let i = 0; i < n; i++) {
    const s = spokes[i];
    const liq = s.liquidationConfig || {};
    const thf = liq.targetHealthFactor || defaultLiq.targetHealthFactor;
    const hfmb =
      liq.healthFactorForMaxBonus || defaultLiq.healthFactorForMaxBonus;
    const lbf =
      liq.liquidationBonusFactor !== undefined
        ? liq.liquidationBonusFactor
        : defaultLiq.liquidationBonusFactor;

    lines.push(`    updates[${i}] = IAaveV4ConfigEngine.LiquidationConfigUpdate({
      spokeConfigurator: ISpokeConfigurator(Infra.SPOKE_CONFIGURATOR),
      spoke: ${spokeRef(s.key)},
      targetHealthFactor: ${thf},
      healthFactorForMaxBonus: ${hfmb},
      liquidationBonusFactor: ${lbf}
    });`);
  }

  lines.push(`    return updates;`);
  lines.push(`  }`);
  return lines.join("\n");
}

// --- Generate spokeReserveListings ---

function genSpokeReserveListings(getAddress, start = 0, end = undefined) {
  const reserves = config.reserves.slice(start, end);
  const defaultReserve = config.defaults.reserve;
  const n = reserves.length;
  const lines = [];
  lines.push(
    `  function spokeReserveListings() public pure override returns (IAaveV4ConfigEngine.ReserveListing[] memory listings) {`,
  );
  lines.push(`    listings = new IAaveV4ConfigEngine.ReserveListing[](${n});`);

  for (let i = 0; i < n; i++) {
    const r = reserves[i];
    const priceFeed = getAddress(config.tokens[r.assetKey].priceFeed);
    const maxLiqBonus =
      r.maxLiquidationBonus !== undefined
        ? r.maxLiquidationBonus
        : defaultReserve.maxLiquidationBonus;
    const liqFee =
      r.liquidationFee !== undefined
        ? r.liquidationFee
        : defaultReserve.liquidationFee;

    lines.push(`    listings[${i}] = IAaveV4ConfigEngine.ReserveListing({
      spokeConfigurator: ISpokeConfigurator(Infra.SPOKE_CONFIGURATOR),
      spoke: ${spokeRef(r.spokeKey)},
      hub: ${hubRef(r.hubKey)},
      underlying: ${tokenRef(r.assetKey)},
      priceSource: ${priceFeed},
      config: ISpoke.ReserveConfig({
        collateralRisk: ${r.collateralRisk},
        paused: ${r.paused !== undefined ? r.paused : defaultReserve.paused},
        frozen: ${r.frozen !== undefined ? r.frozen : defaultReserve.frozen},
        borrowable: ${r.borrowable},
        receiveSharesEnabled: ${r.receiveSharesEnabled !== undefined ? r.receiveSharesEnabled : defaultReserve.receiveSharesEnabled}
      }),
      dynamicConfig: ISpoke.DynamicReserveConfig({
        collateralFactor: ${r.collateralFactor},
        maxLiquidationBonus: ${maxLiqBonus},
        liquidationFee: ${liqFee}
      })
    });`);
  }

  lines.push(`    return listings;`);
  lines.push(`  }`);
  return lines.join("\n");
}

// --- Position managers ---

const POSITION_MANAGERS = [
  "Infra.CONFIG_POSITION_MANAGER",
  "Infra.GIVER_POSITION_MANAGER",
  "Infra.TAKER_POSITION_MANAGER",
  "Infra.SIGNATURE_GATEWAY",
  "Infra.NATIVE_TOKEN_GATEWAY",
];

// --- Generate spokePositionManagerUpdates ---

function genSpokePositionManagerUpdates() {
  const spokeKeys = config.spokes.map((s) => s.key);
  const pms = POSITION_MANAGERS;
  const n = spokeKeys.length * pms.length;
  const lines = [];
  lines.push(
    `  function spokePositionManagerUpdates() public pure override returns (IAaveV4ConfigEngine.PositionManagerUpdate[] memory updates) {`,
  );
  lines.push(
    `    updates = new IAaveV4ConfigEngine.PositionManagerUpdate[](${n});`,
  );

  let idx = 0;
  for (const spokeKey of spokeKeys) {
    for (const pm of pms) {
      lines.push(`    updates[${idx}] = IAaveV4ConfigEngine.PositionManagerUpdate({
      spokeConfigurator: ISpokeConfigurator(Infra.SPOKE_CONFIGURATOR),
      spoke: ${spokeRef(spokeKey)},
      positionManager: ${pm},
      active: true
    });`);
      idx++;
    }
  }

  lines.push(`    return updates;`);
  lines.push(`  }`);
  return lines.join("\n");
}

// --- Generate positionManagerSpokeRegistrations ---

function genPositionManagerSpokeRegistrations() {
  const spokeKeys = config.spokes.map((s) => s.key);
  const pms = POSITION_MANAGERS;
  const n = spokeKeys.length * pms.length;
  const lines = [];
  lines.push(
    `  function positionManagerSpokeRegistrations() public pure override returns (IAaveV4ConfigEngine.SpokeRegistration[] memory registrations) {`,
  );
  lines.push(
    `    registrations = new IAaveV4ConfigEngine.SpokeRegistration[](${n});`,
  );

  let idx = 0;
  for (const spokeKey of spokeKeys) {
    for (const pm of pms) {
      lines.push(`    registrations[${idx}] = IAaveV4ConfigEngine.SpokeRegistration({
      positionManager: ${pm},
      spoke: ${spokeRef(spokeKey)},
      registered: true
    });`);
      idx++;
    }
  }

  lines.push(`    return registrations;`);
  lines.push(`  }`);
  return lines.join("\n");
}

// --- Assemble ---

const ASSET_SPLIT_THRESHOLD = 11;
const RESERVE_SPLIT_THRESHOLD = 30;

const SOLIDITY_IMPORTS = `// SPDX-License-Identifier: UNLICENSED
// AUTOGENERATED - DO NOT EDIT
pragma solidity ^0.8.0;

import {AaveV4Payload} from 'src/config-engine/AaveV4Payload.sol';
import {IAaveV4ConfigEngine} from 'src/config-engine/interfaces/IAaveV4ConfigEngine.sol';
import {IHubConfigurator} from 'src/hub/interfaces/IHubConfigurator.sol';
import {ISpokeConfigurator} from 'src/spoke/interfaces/ISpokeConfigurator.sol';
import {IHub} from 'src/hub/interfaces/IHub.sol';
import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';
import {IAssetInterestRateStrategy} from 'src/hub/interfaces/IAssetInterestRateStrategy.sol';

import {Hubs, Spokes, Tokens, IrStrategies, Infra} from './AaveV4Contracts.sol';`;

function wrapContract(contractName, ...functionBodies) {
  const body = functionBodies.join("\n\n");
  return `${SOLIDITY_IMPORTS}

contract ${contractName} is AaveV4Payload {
  constructor(IAaveV4ConfigEngine configEngine) AaveV4Payload(configEngine) {}

${body}
}
`;
}

async function writeFormatted(outDir, filename, source) {
  const outPath = path.join(outDir, filename);
  const prettier = await import("prettier");
  const options = await prettier.resolveConfig(outPath);
  const formatted = await prettier.format(source, {
    ...options,
    filepath: outPath,
  });
  fs.writeFileSync(outPath, formatted);
  console.log(`Generated ${filename}`);
}

(async () => {
  const { getAddress } = await import("viem");
  const split = process.argv.includes("--split");

  const outDir = path.join(__dirname, "..");
  fs.mkdirSync(outDir, { recursive: true });

  if (!split) {
    const body = [
      genHubAssetListings(),
      genHubSpokeToAssetsAdditions(),
      genSpokeLiquidationConfigUpdates(),
      genSpokeReserveListings(getAddress),
      genSpokePositionManagerUpdates(),
      genPositionManagerSpokeRegistrations(),
    ].join("\n\n");

    await writeFormatted(
      outDir,
      "InitialConfigPayload.sol",
      wrapContract("InitialConfigPayload", body),
    );
  } else {
    // Payload 1 — hub asset listings (split if > threshold)
    const totalAssets = config.assets.length;
    if (totalAssets > ASSET_SPLIT_THRESHOLD) {
      const suffixes = "abcdefghijklmnopqrstuvwxyz";
      let chunkIdx = 0;
      for (
        let start = 0;
        start < totalAssets;
        start += ASSET_SPLIT_THRESHOLD, chunkIdx++
      ) {
        const end = Math.min(start + ASSET_SPLIT_THRESHOLD, totalAssets);
        const suffix = suffixes[chunkIdx];
        const name = `ConfigPayload_1${suffix}_HubAssetListings`;
        await writeFormatted(
          outDir,
          `${name}.sol`,
          wrapContract(name, genHubAssetListings(start, end)),
        );
      }
    } else {
      await writeFormatted(
        outDir,
        "ConfigPayload_1_HubAssetListings.sol",
        wrapContract(
          "ConfigPayload_1_HubAssetListings",
          genHubAssetListings(),
        ),
      );
    }

    // Payload 2 — hub spoke registrations + liquidation config
    await writeFormatted(
      outDir,
      "ConfigPayload_2_HubSpokeRegistrations.sol",
      wrapContract(
        "ConfigPayload_2_HubSpokeRegistrations",
        genHubSpokeToAssetsAdditions(),
        genSpokeLiquidationConfigUpdates(),
      ),
    );

    // Payload 3 — spoke reserve listings (split in two if > threshold)
    const totalReserves = config.reserves.length;
    if (totalReserves > RESERVE_SPLIT_THRESHOLD) {
      await writeFormatted(
        outDir,
        "ConfigPayload_3a_SpokeReserveListings.sol",
        wrapContract(
          "ConfigPayload_3a_SpokeReserveListings",
          genSpokeReserveListings(getAddress, 0, RESERVE_SPLIT_THRESHOLD),
        ),
      );
      await writeFormatted(
        outDir,
        "ConfigPayload_3b_SpokeReserveListings.sol",
        wrapContract(
          "ConfigPayload_3b_SpokeReserveListings",
          genSpokeReserveListings(getAddress, RESERVE_SPLIT_THRESHOLD),
        ),
      );
    } else {
      await writeFormatted(
        outDir,
        "ConfigPayload_3_SpokeReserveListings.sol",
        wrapContract(
          "ConfigPayload_3_SpokeReserveListings",
          genSpokeReserveListings(getAddress),
        ),
      );
    }

    // Payload 4 — spoke PositionManager updates
    await writeFormatted(
      outDir,
      "ConfigPayload_4_SpokePositionManagerUpdates.sol",
      wrapContract(
        "ConfigPayload_4_SpokePositionManagerUpdates",
        genSpokePositionManagerUpdates(),
      ),
    );

    // Payload 5 — PositionManager spoke registrations
    await writeFormatted(
      outDir,
      "ConfigPayload_5_PositionManagerSpokeRegistrations.sol",
      wrapContract(
        "ConfigPayload_5_PositionManagerSpokeRegistrations",
        genPositionManagerSpokeRegistrations(),
      ),
    );
  }

  process.exit(0);
})();
