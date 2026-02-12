import * as XLSX from 'xlsx';
import fs from 'fs';
import path from 'path';
import {fileURLToPath} from 'url';
import {validate} from './validate-config.ts';

// ══════════════════════════════════════════════════════════════════════════════
// Types
// ══════════════════════════════════════════════════════════════════════════════

type Category =
  | 'Stablecoin'
  | 'Eth Related Asset'
  | 'Btc Related Asset'
  | 'Gov Token'
  | 'Gold Backed Token'
  | 'Ethena Related Asset';

interface SpokeDefinition {
  key: string;
  emode: boolean;
  creditLineFrom: string | null; // e.g., 'CORE_HUB' or null
}

interface ReserveMatrixEntry {
  hubKey: string;
  tokenKey: string;
  spokeKey: string;
  isCollateral: boolean;
  isBorrowable: boolean;
}

interface IrProfile {
  optimalUsageRatio: number;
  baseVariableBorrowRate: number;
  variableRateSlope1: number;
  variableRateSlope2: number;
}

interface ReserveProfile {
  collateralFactor: number;
  collateralRisk: number;
  maxLiquidationBonus?: number; // omit to use default (10500)
  liquidationFee?: number; // omit to use default (1000)
}

interface LiquidationConfigProfile {
  targetHealthFactor: string;
  healthFactorForMaxBonus: string;
  liquidationBonusFactor: number;
}

// ══════════════════════════════════════════════════════════════════════════════
// Constants — Key Normalization Maps
// ══════════════════════════════════════════════════════════════════════════════

const TOKEN_KEY_MAP: Record<string, string> = {
  wETH: 'WETH',
  weth: 'WETH',
  wBTC: 'WBTC',
  cBTC: 'cbBTC',
  'frx USD': 'frxUSD',
  'PT-sUSDEs': 'PT_sUSDe',
  'PT-USDEs': 'PT_USDe',
};

function normalizeTokenKey(excelName: string): string {
  const trimmed = excelName.trim();
  return TOKEN_KEY_MAP[trimmed] ?? trimmed;
}

const HUB_KEY_MAP: Record<string, string> = {
  Prime: 'PRIME_HUB',
  Core: 'CORE_HUB',
  Plus: 'PLUS_HUB',
};

function normalizeHubKey(excelName: string): string {
  const trimmed = excelName.trim();
  const mapped = HUB_KEY_MAP[trimmed];
  if (!mapped) throw new Error(`Unknown hub: "${trimmed}"`);
  return mapped;
}

const SPOKE_KEY_MAP: Record<string, string> = {
  'Bluechip Spoke': 'BLUECHIP_SPOKE',
  'Main Spoke': 'MAIN_SPOKE',
  'Lido e-Spoke': 'LIDO_ESPOKE',
  'EtherFi e-Spoke': 'ETHERFI_ESPOKE',
  'Kelp e-Spoke': 'KELP_ESPOKE',
  'Gold Spoke': 'GOLD_SPOKE',
  'Ethena Spoke': 'ETHENA_SPOKE',
};

function normalizeSpokeKey(excelName: string): string {
  const trimmed = excelName.trim();
  const mapped = SPOKE_KEY_MAP[trimmed];
  if (!mapped) throw new Error(`Unknown spoke: "${trimmed}"`);
  return mapped;
}

// ══════════════════════════════════════════════════════════════════════════════
// Constants — Token Registry (addresses + price feeds)
// ══════════════════════════════════════════════════════════════════════════════

const ZERO = '0x0000000000000000000000000000000000000000';

const TOKEN_REGISTRY: Record<string, {address: string; priceFeed: string}> = {
  WETH: {
    address: '0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2', // "Wrapped Ether"
    priceFeed: '0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419', // "ETH / USD" ~$1,964
  },
  WBTC: {
    address: '0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599', // "Wrapped BTC"
    priceFeed: '0xF4030086522a5bEEa4988F8cA5B36dbC97BeE88c', // "BTC / USD" ~$67,449
  },
  cbBTC: {
    address: '0xcbB7C0000aB88B473b1f5aFd9ef808440eed33Bf', // "Coinbase Wrapped BTC"
    priceFeed: '0x2665701293fCbEB223D11A08D826563EDcCE423A', // "cbBTC / USD" ~$67,240
  },
  wstETH: {
    address: '0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0', // "Wrapped liquid staked Ether 2.0"
    priceFeed: '0x8B6851156023f4f5A66F68BEa80851c3D905Ac93', // "wstETH/ETH/USD" ~$2,409
  },
  weETH: {
    address: '0xCd5fE23C85820F7B72D0926FC9b05b43E359b7ee', // "Wrapped eETH"
    priceFeed: '0x87625393534d5C102cADB66D37201dF24cc26d4C', // "Capped weETH / eETH(ETH) / USD" ~$2,127
  },
  rsETH: {
    address: '0xA1290d69c65A6Fe4DF752f95823fae25cB99e5A7', // "rsETH"
    priceFeed: ZERO, // no USD feed — needs adapter
  },
  USDC: {
    address: '0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48', // "USD Coin"
    priceFeed: '0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6', // "USDC / USD" ~$1.00
  },
  USDT: {
    address: '0xdAC17F958D2ee523a2206206994597C13D831ec7', // "Tether USD"
    priceFeed: '0x3E7d1eAB13ad0104d2750B8863b489D65364e32D', // "USDT / USD" ~$1.00
  },
  GHO: {
    address: '0x40D16FC0246aD3160Ccc09B8D0D3A2cD28aE6C2f', // "Gho Token"
    priceFeed: '0x3f12643D3f6f874d39C2a4c9f2Cd6f2DbAC877FC', // "GHO / USD" ~$1.00
  },
  AAVE: {
    address: '0x7Fc66500c84A76Ad7e9c93437bFc5Ac33E2DDaE9', // "Aave Token"
    priceFeed: '0xbd7F896e60B650C01caf2d7279a1148189A68884', // "AAVE / USD" ~$109
  },
  LINK: {
    address: '0x514910771AF9Ca656af840dff83E8264EcF986CA', // "ChainLink Token"
    priceFeed: '0x2c1d072e956AFFC0D435Cb7AC38EF18d24d9127c', // "LINK / USD" ~$8.40
  },
  sUSDe: {
    address: '0x9D39A5DE30e57443BfF2A8307A4256c8797A3497', // "Staked USDe"
    priceFeed: '0xFF3BC18cCBd5999CE63E788A1c250a88626aD099', // "sUSDe / USD" ~$1.22
  },
  PT_sUSDe: {
    address: '0x3de0ff76E8b528C092d47b9DaC775931cef80F49', // "PT Ethena sUSDE 7MAY2026"
    priceFeed: '0xa0dc0249c32fa79e8B9b17c735908a60b1141B40', // "PT Capped sUSDe USDT/USD linear discount 07MAY2026" ~$0.988
  },
  USDe: {
    address: '0x4c9EDD5852cd905f086C759E8383e09bff1E68B3', // "USDe"
    priceFeed: '0xa569d910839Ae8865Da8F8e70FfFb0cBA869F961', // "USDe / USD" ~$1.00
  },
  LBTC: {
    address: '0x8236a87084f8B84306f72007F36F2618A5634494', // "Lombard Staked Bitcoin"
    priceFeed: '0xF4030086522a5bEEa4988F8cA5B36dbC97BeE88c', // "BTC / USD" ~$67,449 (using BTC/USD directly)
  },
  PYUSD: {
    address: '0x6c3ea9036406852006290770BEdFcAbA0e23A0e8', // "PayPal USD"
    priceFeed: '0x8f1dF6D7F2db73eECE86a18b4381F4707b918FB1', // "PYUSD / USD" ~$1.00
  },
  EURC: {
    address: '0x1aBaEA1f7C830bD89Acc67eC4af516284b1bC33c', // "Euro Coin"
    priceFeed: '0x04F84020Fdf10d9ee64D1dcC2986EDF2F556DA11', // "EURC / USD" ~$1.19
  },
  XAUt: {
    address: '0x68749665FF8D2d112Fa859AA293F07A622782F38', // "Tether Gold"
    priceFeed: '0x214eD9Da11D2fbe465a6fc601a91E62EbEc1a0D6', // "XAU / USD" ~$5,065
  },
  USDG: {
    address: '0xe343167631d89B6Ffc58B88d6b7fB0228795491D', // "Global Dollar"
    priceFeed: '0x14f0737d6b705259e521EA6E9E3506AC78dBd311', // "USDG / USD" ~$1.00
  },
  RLUSD: {
    address: '0x8292Bb45bf1Ee4d140127049757c2E0fF06317eD', // "RLUSD"
    priceFeed: '0x26C46B7aD0012cA71F2298ada567dC9Af14E7f2A', // "RLUSD / USD" ~$1.00
  },
  frxUSD: {
    address: '0xCAcd6fd266aF91b8AeD52aCCc382b4e165586E29', // "Frax USD"
    priceFeed: '0x9B4a96210bc8D9D55b1908B465D8B0de68B7fF83', // "frxUSD / USD" ~$1.00
  },
  PT_USDe: {
    address: '0xAeBf0Bb9f57E89260d57f31AF34eB58657d96Ce0', // "PT Ethena USDe 7MAY2026"
    priceFeed: '0x0a72df02CE3E4185b6CEDf561f0AE651E9BeE235', // "PT Capped USDe USDT/USD linear discount 07MAY2026" ~$0.990
  },
};

// ══════════════════════════════════════════════════════════════════════════════
// Constants — IR Strategy Profiles
// ══════════════════════════════════════════════════════════════════════════════

const IR_PROFILES: Record<string, IrProfile> = {
  stablecoin: {
    optimalUsageRatio: 9200,
    baseVariableBorrowRate: 0,
    variableRateSlope1: 550,
    variableRateSlope2: 3500,
  },
  eth: {
    optimalUsageRatio: 9000,
    baseVariableBorrowRate: 0,
    variableRateSlope1: 270,
    variableRateSlope2: 8000,
  },
  lst: {
    optimalUsageRatio: 9000,
    baseVariableBorrowRate: 0,
    variableRateSlope1: 550,
    variableRateSlope2: 8500,
  },
  btc: {
    optimalUsageRatio: 8000,
    baseVariableBorrowRate: 0,
    variableRateSlope1: 400,
    variableRateSlope2: 6000,
  },
  gov_AAVE: {
    optimalUsageRatio: 4500,
    baseVariableBorrowRate: 0,
    variableRateSlope1: 550,
    variableRateSlope2: 30000,
  },
  gov_other: {
    optimalUsageRatio: 4500,
    baseVariableBorrowRate: 0,
    variableRateSlope1: 700,
    variableRateSlope2: 30000,
  },
  gold: {
    optimalUsageRatio: 4500,
    baseVariableBorrowRate: 0,
    variableRateSlope1: 700,
    variableRateSlope2: 30000,
  },
  ethena_yield: {
    optimalUsageRatio: 9000,
    baseVariableBorrowRate: 0,
    variableRateSlope1: 625,
    variableRateSlope2: 4000,
  },
  ethena_pt: {
    optimalUsageRatio: 4500,
    baseVariableBorrowRate: 0,
    variableRateSlope1: 1000,
    variableRateSlope2: 30000,
  },
};

function getIrProfileKey(tokenKey: string, category: Category): string {
  if (category === 'Stablecoin') return 'stablecoin';
  if (category === 'Gold Backed Token') return 'gold';
  if (tokenKey === 'WETH') return 'eth';
  if (['wstETH', 'weETH', 'rsETH'].includes(tokenKey)) return 'lst';
  if (category === 'Btc Related Asset') return 'btc';
  if (tokenKey === 'AAVE') return 'gov_AAVE';
  if (category === 'Gov Token') return 'gov_other';
  if (['sUSDe', 'USDe'].includes(tokenKey)) return 'ethena_yield';
  if (tokenKey.startsWith('PT_')) return 'ethena_pt';
  return 'stablecoin'; // fallback
}

// ══════════════════════════════════════════════════════════════════════════════
// Constants — Reserve Parameter Profiles
// ══════════════════════════════════════════════════════════════════════════════

const RESERVE_PROFILES: Record<string, ReserveProfile> = {
  // Standard spokes
  stable_col_bor: {collateralFactor: 8300, collateralRisk: 0, maxLiquidationBonus: 10000},
  stable_bor_only: {
    collateralFactor: 0,
    collateralRisk: 0,
    maxLiquidationBonus: 10000,
    liquidationFee: 0,
  },
  eth_col_bor: {collateralFactor: 8500, collateralRisk: 0},
  eth_bor_only: {
    collateralFactor: 0,
    collateralRisk: 0,
    maxLiquidationBonus: 10000,
    liquidationFee: 0,
  },
  lst_col_bor: {collateralFactor: 8300, collateralRisk: 0, maxLiquidationBonus: 10600},
  lst_col_only: {collateralFactor: 8300, collateralRisk: 0, maxLiquidationBonus: 10600},
  emode_lst_col: {
    collateralFactor: 9300,
    collateralRisk: 0,
    maxLiquidationBonus: 10600,
    liquidationFee: 1500,
  },
  btc_col_bor: {collateralFactor: 8300, collateralRisk: 0, maxLiquidationBonus: 10600},
  btc_col_only: {collateralFactor: 7800, collateralRisk: 0},
  gov_AAVE: {collateralFactor: 6000, collateralRisk: 4500},
  gov_other: {collateralFactor: 7800, collateralRisk: 500},
  gold_col: {collateralFactor: 7800, collateralRisk: 500},
  ethena_col: {collateralFactor: 8000, collateralRisk: 900, maxLiquidationBonus: 10600},
  ethena_pt_col: {collateralFactor: 7800, collateralRisk: 800},
};

function getReserveProfileKey(
  tokenKey: string,
  category: Category,
  isCollateral: boolean,
  isBorrowable: boolean,
  isEmodeLst: boolean,
  isEmodeEthena: boolean,
): string {
  // e-mode LST spokes
  if (isEmodeLst) {
    if (category === 'Eth Related Asset' && tokenKey !== 'WETH') return 'emode_lst_col';
    if (tokenKey === 'WETH') return 'eth_bor_only';
    return 'stable_bor_only'; // shouldn't happen, but fallback
  }

  // e-mode Ethena spoke
  if (isEmodeEthena) {
    if (category === 'Ethena Related Asset') {
      if (tokenKey.startsWith('PT_')) return 'ethena_pt_col';
      return 'ethena_col';
    }
    // Stablecoins on Ethena spoke are borrow-only
    return 'stable_bor_only';
  }

  // Standard stablecoins
  if (category === 'Stablecoin') {
    if (isCollateral && isBorrowable) return 'stable_col_bor';
    if (isBorrowable && !isCollateral) return 'stable_bor_only';
    return 'stable_col_bor'; // fallback
  }

  // ETH
  if (tokenKey === 'WETH') {
    if (isCollateral && isBorrowable) return 'eth_col_bor';
    if (isCollateral) return 'eth_col_bor';
    return 'eth_bor_only';
  }

  // LSTs
  if (['wstETH', 'weETH', 'rsETH'].includes(tokenKey)) {
    if (isCollateral && isBorrowable) return 'lst_col_bor';
    return 'lst_col_only';
  }

  // BTC
  if (category === 'Btc Related Asset') {
    if (isCollateral && isBorrowable) return 'btc_col_bor';
    return 'btc_col_only';
  }

  // Governance
  if (tokenKey === 'AAVE') return 'gov_AAVE';
  if (category === 'Gov Token') return 'gov_other';

  // Gold
  if (category === 'Gold Backed Token') {
    if (isCollateral) return 'gold_col';
    return 'stable_bor_only'; // borrow-only stables on Gold spoke
  }

  return 'stable_bor_only'; // fallback
}

// ══════════════════════════════════════════════════════════════════════════════
// Constants — Spoke Liquidation Config Profiles
// ══════════════════════════════════════════════════════════════════════════════

const LIQUIDATION_PROFILES: Record<string, LiquidationConfigProfile> = {
  emode_lst: {
    targetHealthFactor: '1040000000000000000',
    healthFactorForMaxBonus: '800000000000000000',
    liquidationBonusFactor: 1500,
  },
  emode_ethena: {
    targetHealthFactor: '1030000000000000000',
    healthFactorForMaxBonus: '900000000000000000',
    liquidationBonusFactor: 1000,
  },
};

const SPOKE_LIQUIDATION_MAP: Record<string, string | null> = {
  BLUECHIP_SPOKE: null,
  MAIN_SPOKE: null,
  GOLD_SPOKE: null,
  LIDO_ESPOKE: 'emode_lst',
  ETHERFI_ESPOKE: 'emode_lst',
  KELP_ESPOKE: 'emode_lst',
  ETHENA_SPOKE: 'emode_ethena',
};

// ══════════════════════════════════════════════════════════════════════════════
// Constants — Cap Estimation
// ══════════════════════════════════════════════════════════════════════════════

function estimateCaps(
  tokenKey: string,
  category: Category,
  spokeKey: string,
  isBorrowable: boolean,
  isCollateral: boolean,
): {addCap: number; drawCap: number} {
  const isEmodeLst = ['LIDO_ESPOKE', 'ETHERFI_ESPOKE', 'KELP_ESPOKE'].includes(spokeKey);
  const isMain = spokeKey === 'MAIN_SPOKE';
  const isBluechip = spokeKey === 'BLUECHIP_SPOKE';

  // Stablecoins
  if (category === 'Stablecoin') {
    if (tokenKey === 'GHO') {
      return {addCap: 17500000, drawCap: isBorrowable ? 15000000 : 0};
    }
    if (['USDT', 'USDC'].includes(tokenKey)) {
      return {addCap: 3000000, drawCap: isBorrowable ? 2760000 : 0};
    }
    // Mid-tier stables
    return {addCap: 2000000, drawCap: isBorrowable ? 1000000 : 0};
  }

  // ETH
  if (tokenKey === 'WETH') {
    if (isMain || isBluechip) {
      return {addCap: 800, drawCap: isBorrowable ? 725 : 0};
    }
    // e-mode spokes: borrow-only WETH
    return {addCap: 225, drawCap: isBorrowable ? 100 : 0};
  }

  // LSTs
  if (['wstETH', 'weETH', 'rsETH'].includes(tokenKey)) {
    if (isEmodeLst) {
      return {addCap: 200, drawCap: 0}; // collateral-only in e-mode
    }
    return {addCap: 200, drawCap: isBorrowable ? 75 : 0};
  }

  // BTC
  if (category === 'Btc Related Asset') {
    if (tokenKey === 'WBTC') {
      return {addCap: 20, drawCap: isBorrowable ? 7 : 0};
    }
    if (tokenKey === 'cbBTC') {
      return {addCap: 5, drawCap: isBorrowable ? 3 : 0};
    }
    // LBTC and others
    return {addCap: 10, drawCap: isBorrowable ? 5 : 0};
  }

  // Governance
  if (tokenKey === 'AAVE') return {addCap: 9500, drawCap: 0};
  if (tokenKey === 'LINK') return {addCap: 600000, drawCap: 0};

  // Gold
  if (category === 'Gold Backed Token') return {addCap: 5000, drawCap: 0};

  // Ethena
  if (['sUSDe', 'USDe'].includes(tokenKey)) return {addCap: 5000000, drawCap: 0};
  if (tokenKey.startsWith('PT_')) return {addCap: 6000000, drawCap: 0};

  // Fallback
  return {addCap: 1000000, drawCap: isBorrowable ? 500000 : 0};
}

// ══════════════════════════════════════════════════════════════════════════════
// Excel Parsing — Sheet 1: Hub Assets
// ══════════════════════════════════════════════════════════════════════════════

interface HubAssetEntry {
  tokenKey: string;
  hubKey: string;
  category: Category;
}

function parseHubAssetsSheet(sheet: XLSX.WorkSheet): {
  entries: HubAssetEntry[];
  categoryMap: Map<string, Category>;
} {
  const rows = XLSX.utils.sheet_to_json<Record<string, string>>(sheet, {header: 1}) as string[][];

  // Find header row (contains 'Asset', 'Hub', 'Category')
  let headerIdx = -1;
  let colAsset = -1;
  let colHub = -1;
  let colCategory = -1;
  for (let i = 0; i < rows.length; i++) {
    const row = rows[i];
    if (!row) continue;
    for (let j = 0; j < row.length; j++) {
      const cell = String(row[j] ?? '').trim();
      if (cell === 'Asset') colAsset = j;
      if (cell === 'Hub') colHub = j;
      if (cell === 'Category') colCategory = j;
    }
    if (colAsset >= 0 && colHub >= 0 && colCategory >= 0) {
      headerIdx = i;
      break;
    }
  }

  if (headerIdx < 0) throw new Error('Hub Assets sheet: could not find header row');

  const entries: HubAssetEntry[] = [];
  const categoryMap = new Map<string, Category>();

  for (let i = headerIdx + 1; i < rows.length; i++) {
    const row = rows[i];
    if (!row) continue;
    const rawAsset = String(row[colAsset] ?? '').trim();
    const rawHub = String(row[colHub] ?? '').trim();
    const rawCategory = String(row[colCategory] ?? '').trim();
    if (!rawAsset || !rawHub) continue;

    const tokenKey = normalizeTokenKey(rawAsset);
    const hubKey = normalizeHubKey(rawHub);
    const category = rawCategory as Category;

    entries.push({tokenKey, hubKey, category});
    if (!categoryMap.has(tokenKey)) {
      categoryMap.set(tokenKey, category);
    }
  }

  return {entries, categoryMap};
}

// ══════════════════════════════════════════════════════════════════════════════
// Excel Parsing — Sheets 2-4: Spoke Reserve Matrices
// ══════════════════════════════════════════════════════════════════════════════

function parseSpokeSheet(
  sheet: XLSX.WorkSheet,
  primaryHubKey: string,
): {
  spokeDefinitions: SpokeDefinition[];
  reserveEntries: ReserveMatrixEntry[];
} {
  const rows = XLSX.utils.sheet_to_json<Record<string, string>>(sheet, {header: 1}) as string[][];

  // Phase 1: Parse spoke definitions (rows before the reserve matrix header)
  // Look for "Spokes" / "e-Mode" / "Credit Line From" header row
  const spokeDefinitions: SpokeDefinition[] = [];

  let spokeDefHeaderIdx = -1;
  let colSpokeName = -1;
  let colEmode = -1;
  let colCreditLine = -1;

  for (let i = 0; i < rows.length; i++) {
    const row = rows[i];
    if (!row) continue;
    for (let j = 0; j < row.length; j++) {
      const cell = String(row[j] ?? '').trim();
      if (cell === 'Spokes') colSpokeName = j;
      if (cell === 'e-Mode') colEmode = j;
      if (cell === 'Credit Line From') colCreditLine = j;
    }
    if (colSpokeName >= 0) {
      spokeDefHeaderIdx = i;
      break;
    }
  }

  if (spokeDefHeaderIdx >= 0) {
    for (let i = spokeDefHeaderIdx + 1; i < rows.length; i++) {
      const row = rows[i];
      if (!row) continue;
      const rawName = String(row[colSpokeName] ?? '').trim();
      if (!rawName || rawName === 'Hub' || rawName === 'Assets') break;
      // Skip empty rows or header-like rows
      if (SPOKE_KEY_MAP[rawName] === undefined) continue;

      const emode = String(row[colEmode] ?? '').trim() === 'X';
      const rawCreditLine = colCreditLine >= 0 ? String(row[colCreditLine] ?? '').trim() : '';
      let creditLineFrom: string | null = null;
      if (rawCreditLine && rawCreditLine !== '') {
        // "Core Hub" → "CORE_HUB"
        const mapped =
          HUB_KEY_MAP[rawCreditLine] ?? HUB_KEY_MAP[rawCreditLine.replace(' Hub', '')] ?? null;
        creditLineFrom = mapped;
      }

      spokeDefinitions.push({
        key: normalizeSpokeKey(rawName),
        emode,
        creditLineFrom,
      });
    }
  }

  // Phase 2: Find the reserve matrix header row (contains 'Hub', 'Assets', 'Collateral', 'Borrowable')
  let matrixHeaderIdx = -1;
  let colHub = -1;
  let colAssets = -1;

  // Spoke column pairs: each spoke has a (Collateral, Borrowable) pair
  interface SpokeColumns {
    spokeKey: string;
    colCol: number;
    borCol: number;
  }
  const spokeColumns: SpokeColumns[] = [];

  for (let i = 0; i < rows.length; i++) {
    const row = rows[i];
    if (!row) continue;
    let foundHub = false;
    let foundAssets = false;
    for (let j = 0; j < row.length; j++) {
      const cell = String(row[j] ?? '').trim();
      if (cell === 'Hub') {
        colHub = j;
        foundHub = true;
      }
      if (cell === 'Assets') {
        colAssets = j;
        foundAssets = true;
      }
    }
    if (foundHub && foundAssets) {
      matrixHeaderIdx = i;

      // Now parse the spoke columns from this header row
      // The row contains: Hub | Assets | Collateral | Borrowable | Collateral | Borrowable | ...
      // But the spoke names are in the row above (merged cells)
      const headerRow = rows[i];
      const spokeNameRow = rows[i - 1]; // row above has spoke names

      // Identify Collateral/Borrowable pairs
      let currentSpokeIdx = 0;
      for (let j = colAssets + 1; j < headerRow.length; j++) {
        const cell = String(headerRow[j] ?? '').trim();
        if (cell === 'Collateral') {
          // Find matching Borrowable (next column)
          const borIdx = j + 1;
          // Determine which spoke this belongs to
          let spokeName = '';
          if (spokeNameRow) {
            // The spoke name might be at this column or the merged parent
            spokeName = String(spokeNameRow[j] ?? '').trim();
          }
          if (!spokeName && spokeDefinitions.length > currentSpokeIdx) {
            spokeName = ''; // will use index
          }

          // Try to find spoke name from the spoke name row
          let spokeKey: string;
          if (spokeName && SPOKE_KEY_MAP[spokeName]) {
            spokeKey = normalizeSpokeKey(spokeName);
          } else if (currentSpokeIdx < spokeDefinitions.length) {
            spokeKey = spokeDefinitions[currentSpokeIdx].key;
          } else {
            throw new Error(`Cannot determine spoke for column ${j} in matrix header`);
          }

          spokeColumns.push({
            spokeKey,
            colCol: j,
            borCol: borIdx,
          });
          currentSpokeIdx++;
        }
      }
      break;
    }
  }

  if (matrixHeaderIdx < 0) throw new Error('Could not find reserve matrix header row');

  // Phase 3: Parse reserve data rows
  const reserveEntries: ReserveMatrixEntry[] = [];

  for (let i = matrixHeaderIdx + 1; i < rows.length; i++) {
    const row = rows[i];
    if (!row) continue;
    const rawHub = String(row[colHub] ?? '').trim();
    const rawAsset = String(row[colAssets] ?? '').trim();
    if (!rawHub || !rawAsset) continue;

    const hubKey = normalizeHubKey(rawHub);
    const tokenKey = normalizeTokenKey(rawAsset);

    for (const sc of spokeColumns) {
      const isCol = String(row[sc.colCol] ?? '').trim() === 'X';
      const isBor = String(row[sc.borCol] ?? '').trim() === 'X';
      if (!isCol && !isBor) continue;

      reserveEntries.push({
        hubKey,
        tokenKey,
        spokeKey: sc.spokeKey,
        isCollateral: isCol,
        isBorrowable: isBor,
      });
    }
  }

  return {spokeDefinitions, reserveEntries};
}

// ══════════════════════════════════════════════════════════════════════════════
// Config Assembly
// ══════════════════════════════════════════════════════════════════════════════

function buildConfig(
  hubAssetEntries: HubAssetEntry[],
  categoryMap: Map<string, Category>,
  allSpokeDefinitions: SpokeDefinition[],
  allReserveEntries: ReserveMatrixEntry[],
): Record<string, unknown> {
  // ── Defaults ──
  const defaults = {
    spoke: {
      oracleDecimals: 8,
      maxUserReservesLimit: 128,
      liquidationConfig: {
        targetHealthFactor: '1050000000000000000',
        healthFactorForMaxBonus: '700000000000000000',
        liquidationBonusFactor: 2000,
      },
    },
    spokeRegistration: {
      riskPremiumThreshold: 100000,
      active: true,
      halted: false,
    },
    reserve: {
      receiveSharesEnabled: true,
      frozen: false,
      paused: false,
      liquidationFee: 1000,
      maxLiquidationBonus: 10500,
    },
    asset: {
      liquidityFee: 1000,
    },
    tokenize: {
      enabled: true,
    },
  };

  // ── Tokens ──
  const allTokenKeys = new Set<string>();
  for (const entry of hubAssetEntries) allTokenKeys.add(entry.tokenKey);
  for (const entry of allReserveEntries) allTokenKeys.add(entry.tokenKey);

  const tokens: Record<string, {address: string; priceFeed: string}> = {};
  for (const key of [...allTokenKeys].sort()) {
    tokens[key] = TOKEN_REGISTRY[key] ?? {address: ZERO, priceFeed: ZERO};
  }

  // ── Hubs ──
  const hubKeyOrder = ['PRIME_HUB', 'CORE_HUB', 'PLUS_HUB'];
  const hubs = hubKeyOrder.map((key) => ({key}));

  // ── Spokes ──
  // Deduplicate and preserve order
  const seenSpokes = new Set<string>();
  const spokeList: SpokeDefinition[] = [];
  for (const sd of allSpokeDefinitions) {
    if (!seenSpokes.has(sd.key)) {
      seenSpokes.add(sd.key);
      spokeList.push(sd);
    }
  }

  const spokes = spokeList.map((sd) => {
    const profileKey = SPOKE_LIQUIDATION_MAP[sd.key];
    const spoke: Record<string, unknown> = {key: sd.key};
    if (profileKey && LIQUIDATION_PROFILES[profileKey]) {
      spoke.liquidationConfig = LIQUIDATION_PROFILES[profileKey];
    } else {
      spoke.liquidationConfig = {};
    }
    return spoke;
  });

  // ── Assets ──
  // One per unique (tokenKey, hubKey) from Hub Assets sheet
  const assetHubSet = new Set<string>();
  const assets: Array<Record<string, unknown>> = [];

  for (const entry of hubAssetEntries) {
    const key = `${entry.tokenKey}|${entry.hubKey}`;
    if (assetHubSet.has(key)) continue;
    assetHubSet.add(key);

    const irKey = getIrProfileKey(entry.tokenKey, entry.category);
    const irData = IR_PROFILES[irKey];

    const asset: Record<string, unknown> = {
      tokenKey: entry.tokenKey,
      hubKey: entry.hubKey,
      irData,
    };

    // wstETH has a special liquidityFee of 500 on Prime hub (from existing config)
    if (entry.tokenKey === 'wstETH' && entry.hubKey === 'PRIME_HUB') {
      asset.liquidityFee = 500;
    }

    assets.push(asset);
  }

  // Ensure cross-hub assets exist in the assets array
  // (e.g., if a spoke borrows USDT from Core Hub, USDT must be listed as an asset on Core Hub)
  for (const re of allReserveEntries) {
    const key = `${re.tokenKey}|${re.hubKey}`;
    if (!assetHubSet.has(key)) {
      // This cross-hub asset is not in Hub Assets sheet — add it
      const category = categoryMap.get(re.tokenKey) ?? 'Stablecoin';
      const irKey = getIrProfileKey(re.tokenKey, category);
      const irData = IR_PROFILES[irKey];
      assets.push({
        tokenKey: re.tokenKey,
        hubKey: re.hubKey,
        irData,
      });
      assetHubSet.add(key);
    }
  }

  // ── Spoke Registrations ──
  const spokeRegs: Array<Record<string, unknown>> = [];
  const srSeen = new Set<string>();

  for (const entry of allReserveEntries) {
    const key = `${entry.tokenKey}|${entry.hubKey}|${entry.spokeKey}`;
    if (srSeen.has(key)) continue;
    srSeen.add(key);

    const category = categoryMap.get(entry.tokenKey) ?? 'Stablecoin';
    const caps = estimateCaps(
      entry.tokenKey,
      category,
      entry.spokeKey,
      entry.isBorrowable,
      entry.isCollateral,
    );

    spokeRegs.push({
      assetKey: entry.tokenKey,
      hubKey: entry.hubKey,
      spokeKey: entry.spokeKey,
      addCap: caps.addCap,
      drawCap: caps.drawCap,
    });
  }

  // ── Reserves ──
  const reserves: Array<Record<string, unknown>> = [];
  const resSeen = new Set<string>();

  // Build a spoke key → definition map for emode lookup
  const spokeDefMap = new Map<string, SpokeDefinition>();
  for (const sd of spokeList) spokeDefMap.set(sd.key, sd);

  for (const entry of allReserveEntries) {
    const key = `${entry.spokeKey}|${entry.hubKey}|${entry.tokenKey}`;
    if (resSeen.has(key)) continue;
    resSeen.add(key);

    const category = categoryMap.get(entry.tokenKey) ?? 'Stablecoin';
    const spokeDef = spokeDefMap.get(entry.spokeKey);
    const isEmodeLst =
      spokeDef?.emode === true &&
      ['LIDO_ESPOKE', 'ETHERFI_ESPOKE', 'KELP_ESPOKE'].includes(entry.spokeKey);
    const isEmodeEthena = spokeDef?.emode === true && entry.spokeKey === 'ETHENA_SPOKE';

    const profileKey = getReserveProfileKey(
      entry.tokenKey,
      category,
      entry.isCollateral,
      entry.isBorrowable,
      isEmodeLst,
      isEmodeEthena,
    );
    const profile = RESERVE_PROFILES[profileKey];
    if (!profile) throw new Error(`No reserve profile for key: ${profileKey}`);

    const reserve: Record<string, unknown> = {
      spokeKey: entry.spokeKey,
      hubKey: entry.hubKey,
      assetKey: entry.tokenKey,
      borrowable: entry.isBorrowable,
      collateralFactor: profile.collateralFactor,
      collateralRisk: profile.collateralRisk,
    };

    // Only include if different from defaults
    if (profile.maxLiquidationBonus !== undefined && profile.maxLiquidationBonus !== 10500) {
      reserve.maxLiquidationBonus = profile.maxLiquidationBonus;
    }
    if (profile.liquidationFee !== undefined && profile.liquidationFee !== 1000) {
      reserve.liquidationFee = profile.liquidationFee;
    }

    reserves.push(reserve);
  }

  // ── Periphery ──
  const periphery = {
    nativeTokenKey: 'WETH',
    deploySignatureGateway: true,
    deployNativeTokenGateway: true,
  };

  return {
    defaults,
    tokens,
    hubs,
    spokes,
    assets,
    spokeRegistrations: spokeRegs,
    reserves,
    periphery,
  };
}

// ══════════════════════════════════════════════════════════════════════════════
// Main Entry Point
// ══════════════════════════════════════════════════════════════════════════════

function main() {
  const __dirname = path.dirname(fileURLToPath(import.meta.url));
  const xlsxPath = process.argv[2] || path.resolve(__dirname, '../configIn/v4 initial config.xlsx');
  const outputPath = process.argv[3] || path.resolve(__dirname, '../config/generated.json');

  console.error(`Reading: ${xlsxPath}`);
  const workbook = XLSX.readFile(xlsxPath);

  // Parse Sheet 1: Hub Assets
  const hubAssetsSheet = workbook.Sheets['Hub Assets'];
  if (!hubAssetsSheet) throw new Error('Sheet "Hub Assets" not found');
  const {entries: hubAssetEntries, categoryMap} = parseHubAssetsSheet(hubAssetsSheet);
  console.error(
    `  Hub Assets: ${hubAssetEntries.length} entries, ${categoryMap.size} unique tokens`,
  );

  // Parse Sheet 2: Prime
  const primeSheet = workbook.Sheets['Prime'];
  if (!primeSheet) throw new Error('Sheet "Prime" not found');
  const prime = parseSpokeSheet(primeSheet, 'PRIME_HUB');
  console.error(
    `  Prime: ${prime.spokeDefinitions.length} spokes, ${prime.reserveEntries.length} reserve entries`,
  );

  // Parse Sheet 3: Core
  const coreSheet = workbook.Sheets['Core'];
  if (!coreSheet) throw new Error('Sheet "Core" not found');
  const core = parseSpokeSheet(coreSheet, 'CORE_HUB');
  console.error(
    `  Core: ${core.spokeDefinitions.length} spokes, ${core.reserveEntries.length} reserve entries`,
  );

  // Parse Sheet 4: Plus
  const plusSheet = workbook.Sheets['Plus'];
  if (!plusSheet) throw new Error('Sheet "Plus" not found');
  const plus = parseSpokeSheet(plusSheet, 'PLUS_HUB');
  console.error(
    `  Plus: ${plus.spokeDefinitions.length} spokes, ${plus.reserveEntries.length} reserve entries`,
  );

  // Merge
  const allSpokeDefinitions = [
    ...prime.spokeDefinitions,
    ...core.spokeDefinitions,
    ...plus.spokeDefinitions,
  ];
  const allReserveEntries = [
    ...prime.reserveEntries,
    ...core.reserveEntries,
    ...plus.reserveEntries,
  ];

  console.error(
    `  Total: ${allSpokeDefinitions.length} spoke definitions, ${allReserveEntries.length} reserve entries`,
  );

  // Build config
  const config = buildConfig(hubAssetEntries, categoryMap, allSpokeDefinitions, allReserveEntries);

  // Validate
  const result = validate(config);
  if (result.errors.length > 0) {
    console.error('\nValidation ERRORS:');
    result.errors.forEach((e) => console.error(`  [${e.code}] ${e.msg}`));
  }
  if (result.warnings.length > 0) {
    console.error('\nValidation WARNINGS:');
    result.warnings.forEach((w) => console.error(`  [${w.code}] ${w.msg}`));
  }
  console.error(`\n=== ${result.errors.length} error(s), ${result.warnings.length} warning(s) ===`);

  // Write output
  const json = JSON.stringify(config, null, 2);
  fs.writeFileSync(outputPath, json + '\n');
  console.error(`\nWritten to: ${outputPath}`);

  if (result.errors.length > 0) process.exit(1);
}

main();
