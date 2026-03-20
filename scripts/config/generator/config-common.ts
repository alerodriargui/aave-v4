// Shared constants and helpers for config generators.

import {z} from 'zod';

export interface IrProfile {
  optimalUsageRatio: number;
  baseDrawnRate: number;
  rateGrowthBeforeOptimal: number;
  rateGrowthAfterOptimal: number;
}

export const ZERO = '0x0000000000000000000000000000000000000000';

export const TOKEN_REGISTRY: Record<string, {address: string; priceFeed: string}> = {
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
    priceFeed: '0x7292C95A5f6A501a9c4B34f6393e221F2A0139c3', // "rsETH / ETH / USD"
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
  PT_sUSDE_7MAY2026: {
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
  PT_USDE_7MAY2026: {
    address: '0xAeBf0Bb9f57E89260d57f31AF34eB58657d96Ce0', // "PT Ethena USDe 7MAY2026"
    priceFeed: '0x0a72df02CE3E4185b6CEDf561f0AE651E9BeE235', // "PT Capped USDe USDT/USD linear discount 07MAY2026" ~$0.990
  },
};

/**
 * Convert a decimal string to a WAD (1e18) string using pure string/BigInt arithmetic.
 * Maximum 6 decimal places — throws if more precision is specified.
 *
 * Pass String(excelCell) from the caller; never convert to Number first,
 * as float arithmetic can silently introduce precision errors.
 *
 * "1.05"    → "1050000000000000000"
 * "1.23200" → "1232000000000000000"  (trailing zeros retained correctly)
 * "1.1"     → "1100000000000000000"  (no float precision loss)
 */
export function toWadString(decimal: string): string {
  const s = String(decimal).trim();
  const dotIndex = s.indexOf('.');
  const intPart = dotIndex === -1 ? s : s.slice(0, dotIndex);
  const fracPart = dotIndex === -1 ? '' : s.slice(dotIndex + 1);

  // ! todo depends on how chaos updates
  // if (fracPart.length > 6) {
  //   throw new Error(
  //     `toWadString: "${decimal}" has ${fracPart.length} decimal places; maximum allowed is 6`,
  //   );
  // }
  if (!/^\d*$/.test(intPart) || (fracPart && !/^\d+$/.test(fracPart))) {
    throw new Error(`toWadString: "${decimal}" is not a valid non-negative decimal`);
  }

  // Pad fracPart to 18 digits, concatenate with intPart, convert once to BigInt.
  // Result = intPart × 10^18 + fracPart × 10^(18 − fracPart.length) = value in WAD.
  return BigInt((intPart || '0') + fracPart.padEnd(18, '0')).toString();
}

export function safeMaxLiquidationBonus(desired: number, collateralFactor: number): number {
  if (collateralFactor === 0) return desired;
  // percentMulUp(mlb, cf) < 10000  ⟺  mlb * cf ≤ 99990000
  const maxSafe = Math.floor(99990000 / collateralFactor);
  return Math.min(desired, maxSafe);
}

// ── On-chain constants ───────────────────────────────────────────────────────
export const UINT40_MAX = 1099511627775; // type(uint40).max — spoke caps
export const UINT24_MAX = 16777215; // type(uint24).max — riskPremiumThreshold, collateralRisk
export const UINT16_MAX = 65535; // type(uint16).max — maxUserReservesLimit
export const WAD = BigInt('1000000000000000000'); // 1e18
export const PERCENTAGE_FACTOR = 10000;
export const MIN_OPTIMAL_RATIO = 100; // AssetInterestRateStrategy.MIN_OPTIMAL_RATIO
export const MAX_OPTIMAL_RATIO = 9900; // AssetInterestRateStrategy.MAX_OPTIMAL_RATIO
export const MAX_ALLOWED_DRAWN_RATE = 100000; // AssetInterestRateStrategy.MAX_ALLOWED_DRAWN_RATE

// ── Zod Schemas ──────────────────────────────────────────────────────────────

const LiquidationConfigSchema = z
  .object({
    targetHealthFactor: z.string().optional(),
    healthFactorForMaxBonus: z.string().optional(),
    liquidationBonusFactor: z.number().int().optional(),
  })
  .strict();

const TokenSchema = z
  .object({
    address: z.string(),
    priceFeed: z.string(),
  })
  .strict();

const HubSchema = z
  .object({
    key: z.string(),
  })
  .strict();

const SpokeSchema = z
  .object({
    key: z.string(),
    registerOnPositionManagers: z.boolean().optional(),
    oracleDecimals: z.number().int().optional(),
    maxUserReservesLimit: z.number().int().optional(),
    liquidationConfig: LiquidationConfigSchema.optional(),
  })
  .strict();

const IrDataSchema = z
  .object({
    optimalUsageRatio: z.number().int(),
    baseDrawnRate: z.number().int(),
    rateGrowthBeforeOptimal: z.number().int(),
    rateGrowthAfterOptimal: z.number().int(),
  })
  .strict();

const TokenizeSchema = z
  .object({
    enabled: z.boolean().optional(),
    name: z.string().optional(),
    symbol: z.string().optional(),
    addCap: z.number().int().optional(),
    drawCap: z.number().int().optional(),
  })
  .strict();

const AssetSchema = z
  .object({
    tokenKey: z.string(),
    hubKey: z.string(),
    liquidityFee: z.number().int().optional(),
    irData: IrDataSchema.optional(),
    tokenize: TokenizeSchema.optional(),
  })
  .strict();

const SpokeRegistrationSchema = z
  .object({
    assetKey: z.string(),
    hubKey: z.string(),
    spokeKey: z.string(),
    addCap: z.number().int(),
    drawCap: z.number().int(),
    riskPremiumThreshold: z.number().int().optional(),
    active: z.boolean().optional(),
    halted: z.boolean().optional(),
  })
  .strict();

const ReserveSchema = z
  .object({
    spokeKey: z.string(),
    hubKey: z.string(),
    assetKey: z.string(),
    borrowable: z.boolean(),
    collateralFactor: z.number().int(),
    maxLiquidationBonus: z.number().int().optional(),
    liquidationFee: z.number().int().optional(),
    collateralRisk: z.number().int(),
    receiveSharesEnabled: z.boolean().optional(),
    frozen: z.boolean().optional(),
    paused: z.boolean().optional(),
  })
  .strict();

const PeripherySchema = z
  .object({
    nativeTokenKey: z.string(),
    deploySignatureGateway: z.boolean().optional(),
    deployNativeTokenGateway: z.boolean().optional(),
    deployGiverPositionManager: z.boolean().optional(),
    deployTakerPositionManager: z.boolean().optional(),
    deployConfigPositionManager: z.boolean().optional(),
  })
  .strict();

const DefaultsSchema = z
  .object({
    spoke: z
      .object({
        oracleDecimals: z.number().int().optional(),
        maxUserReservesLimit: z.number().int().optional(),
        liquidationConfig: LiquidationConfigSchema.optional(),
      })
      .strict()
      .optional(),
    spokeRegistration: z
      .object({
        riskPremiumThreshold: z.number().int().optional(),
        active: z.boolean().optional(),
        halted: z.boolean().optional(),
      })
      .strict()
      .optional(),
    reserve: z
      .object({
        receiveSharesEnabled: z.boolean().optional(),
        frozen: z.boolean().optional(),
        paused: z.boolean().optional(),
        liquidationFee: z.number().int().optional(),
        maxLiquidationBonus: z.number().int().optional(),
      })
      .strict()
      .optional(),
    asset: z
      .object({
        liquidityFee: z.number().int().optional(),
      })
      .strict()
      .optional(),
    tokenize: z
      .object({
        enabled: z.boolean().optional(),
        addCap: z.number().int().optional(),
        drawCap: z.number().int().optional(),
      })
      .strict()
      .optional(),
  })
  .strict();

export const ConfigSchema = z
  .object({
    defaults: DefaultsSchema.optional(),
    tokens: z.record(z.string(), TokenSchema),
    hubs: z.array(HubSchema),
    spokes: z.array(SpokeSchema),
    assets: z.array(AssetSchema),
    spokeRegistrations: z.array(SpokeRegistrationSchema),
    reserves: z.array(ReserveSchema),
    periphery: PeripherySchema.optional(),
  })
  .strict();

export type DeployConfig = z.infer<typeof ConfigSchema>;
