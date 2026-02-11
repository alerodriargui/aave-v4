import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import { z } from 'zod';

// ── Zod Schemas ─────────────────────────────────────────────────────────────

const ZERO_ADDRESS = '0x0000000000000000000000000000000000000000';

const LiquidationConfigSchema = z.object({
  targetHealthFactor: z.string().optional(),
  healthFactorForMaxBonus: z.string().optional(),
  liquidationBonusFactor: z.number().int().optional(),
}).strict();

const TokenSchema = z.object({
  address: z.string(),
  priceFeed: z.string(),
}).strict();

const HubSchema = z.object({
  key: z.string(),
}).strict();

const SpokeSchema = z.object({
  key: z.string(),
  registerOnPositionManagers: z.boolean().optional(),
  oracleDecimals: z.number().int().optional(),
  maxUserReservesLimit: z.number().int().optional(),
  liquidationConfig: LiquidationConfigSchema.optional(),
}).strict();

const IrDataSchema = z.object({
  optimalUsageRatio: z.number().int(),
  baseVariableBorrowRate: z.number().int(),
  variableRateSlope1: z.number().int(),
  variableRateSlope2: z.number().int(),
}).strict();

const TokenizeSchema = z.object({
  enabled: z.boolean().optional(),
  addCap: z.number().int().optional(),
  drawCap: z.number().int().optional(),
}).strict();

const AssetSchema = z.object({
  tokenKey: z.string(),
  hubKey: z.string(),
  liquidityFee: z.number().int().optional(),
  irData: IrDataSchema.optional(),
  tokenize: TokenizeSchema.optional(),
}).strict();

const SpokeRegistrationSchema = z.object({
  assetKey: z.string(),
  hubKey: z.string(),
  spokeKey: z.string(),
  addCap: z.number().int(),
  drawCap: z.number().int(),
  riskPremiumThreshold: z.number().int().optional(),
  active: z.boolean().optional(),
  halted: z.boolean().optional(),
}).strict();

const ReserveSchema = z.object({
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
}).strict();

const PeripherySchema = z.object({
  nativeTokenKey: z.string(),
  deploySignatureGateway: z.boolean().optional(),
  deployNativeTokenGateway: z.boolean().optional(),
}).strict();

const DefaultsSchema = z.object({
  spoke: z.object({
    oracleDecimals: z.number().int().optional(),
    maxUserReservesLimit: z.number().int().optional(),
    liquidationConfig: LiquidationConfigSchema.optional(),
  }).strict().optional(),
  spokeRegistration: z.object({
    riskPremiumThreshold: z.number().int().optional(),
    active: z.boolean().optional(),
    halted: z.boolean().optional(),
  }).strict().optional(),
  reserve: z.object({
    receiveSharesEnabled: z.boolean().optional(),
    frozen: z.boolean().optional(),
    paused: z.boolean().optional(),
    liquidationFee: z.number().int().optional(),
    maxLiquidationBonus: z.number().int().optional(),
  }).strict().optional(),
  asset: z.object({
    liquidityFee: z.number().int().optional(),
  }).strict().optional(),
  tokenize: z.object({
    enabled: z.boolean().optional(),
    addCap: z.number().int().optional(),
    drawCap: z.number().int().optional(),
  }).strict().optional(),
}).strict();

const ConfigSchema = z.object({
  defaults: DefaultsSchema.optional(),
  tokens: z.record(z.string(), TokenSchema),
  hubs: z.array(HubSchema),
  spokes: z.array(SpokeSchema),
  assets: z.array(AssetSchema),
  spokeRegistrations: z.array(SpokeRegistrationSchema),
  reserves: z.array(ReserveSchema),
  periphery: PeripherySchema.optional(),
}).strict();

export type DeployConfig = z.infer<typeof ConfigSchema>;

// ── Validation ──────────────────────────────────────────────────────────────

interface Issue { code: string; msg: string }
export interface ValidationResult { errors: Issue[]; warnings: Issue[] }

export function validate(raw: unknown): ValidationResult {
  const errors: Issue[] = [];
  const warnings: Issue[] = [];

  function error(code: string, msg: string) { errors.push({ code, msg }); }
  function warn(code: string, msg: string) { warnings.push({ code, msg }); }

  // ── Phase 1: Schema validation ──────────────────────────────────────────

  const parsed = ConfigSchema.safeParse(raw);
  if (!parsed.success) {
    for (const issue of parsed.error.issues) {
      const p = issue.path.join('.');
      if (issue.code === 'unrecognized_keys') {
        for (const key of issue.keys) {
          error('E20', `${p}: unknown key "${key}"`);
        }
      } else {
        error('SCHEMA', `${p}: ${issue.message}`);
      }
    }
    return { errors, warnings };
  }

  const config = parsed.data;

  // ── Phase 2: Business logic ─────────────────────────────────────────────

  const tokenKeys = new Set(Object.keys(config.tokens));
  const hubKeys = new Set(config.hubs.map(h => h.key));
  const spokeKeys = new Set(config.spokes.map(s => s.key));

  const assetSet = new Set<string>();
  const spokeRegSet = new Set<string>();
  const spokeRegMap = new Map<string, DeployConfig['spokeRegistrations'][number]>();
  const reserveSet = new Set<string>();
  const reserveMap = new Map<string, DeployConfig['reserves'][number]>();

  // ── Assets ──

  config.assets.forEach((a, i) => {
    const label = `assets[${i}] (${a.tokenKey}/${a.hubKey})`;
    if (!tokenKeys.has(a.tokenKey)) error('E1', `${label}: tokenKey "${a.tokenKey}" not found in tokens`);
    if (!hubKeys.has(a.hubKey)) error('E2', `${label}: hubKey "${a.hubKey}" not found in hubs`);

    const key = `${a.tokenKey}|${a.hubKey}`;
    if (assetSet.has(key)) error('E4', `${label}: duplicate asset (same tokenKey+hubKey already exists)`);
    assetSet.add(key);

    if (a.liquidityFee !== undefined && a.liquidityFee > 10000) {
      error('E14', `${label}: liquidityFee ${a.liquidityFee} > 10000 BPS`);
    }

    if (a.irData && a.irData.optimalUsageRatio > 10000) {
      error('E16', `${label}: optimalUsageRatio ${a.irData.optimalUsageRatio} > 10000 BPS`);
    }
  });

  // ── Tokenization Spokes (E19) ──

  if (config.defaults?.tokenize) {
    const dt = config.defaults.tokenize;
    if (dt.drawCap !== undefined && dt.drawCap !== 0) {
      error('E19', `defaults.tokenize: drawCap=${dt.drawCap} must be 0 (cannot borrow from tokenization spokes)`);
    }
  }

  config.assets.forEach((a, i) => {
    if (a.tokenize?.drawCap !== undefined && a.tokenize.drawCap !== 0) {
      error('E19', `assets[${i}] (${a.tokenKey}/${a.hubKey}): tokenize.drawCap=${a.tokenize.drawCap} must be 0 (cannot borrow from tokenization spokes)`);
    }
  });

  // ── Spoke Registrations ──

  config.spokeRegistrations.forEach((sr, i) => {
    const label = `spokeRegistrations[${i}] (${sr.assetKey}/${sr.hubKey}/${sr.spokeKey})`;
    if (!tokenKeys.has(sr.assetKey)) error('E1', `${label}: assetKey "${sr.assetKey}" not found in tokens`);
    if (!hubKeys.has(sr.hubKey)) error('E2', `${label}: hubKey "${sr.hubKey}" not found in hubs`);
    if (!spokeKeys.has(sr.spokeKey)) error('E3', `${label}: spokeKey "${sr.spokeKey}" not found in spokes`);

    const key = `${sr.assetKey}|${sr.hubKey}|${sr.spokeKey}`;
    if (spokeRegSet.has(key)) error('E5', `${label}: duplicate spoke registration`);
    spokeRegSet.add(key);
    spokeRegMap.set(key, sr);

    const assetKey = `${sr.assetKey}|${sr.hubKey}`;
    if (!assetSet.has(assetKey)) {
      error('E7', `${label}: no asset found for (${sr.assetKey}, ${sr.hubKey}) in assets section`);
    }
  });

  // ── Reserves ──

  config.reserves.forEach((r, i) => {
    const label = `reserves[${i}] (${r.spokeKey}/${r.hubKey}/${r.assetKey})`;
    if (!tokenKeys.has(r.assetKey)) error('E1', `${label}: assetKey "${r.assetKey}" not found in tokens`);
    if (!hubKeys.has(r.hubKey)) error('E2', `${label}: hubKey "${r.hubKey}" not found in hubs`);
    if (!spokeKeys.has(r.spokeKey)) error('E3', `${label}: spokeKey "${r.spokeKey}" not found in spokes`);

    const key = `${r.spokeKey}|${r.hubKey}|${r.assetKey}`;
    if (reserveSet.has(key)) error('E6', `${label}: duplicate reserve`);
    reserveSet.add(key);
    reserveMap.set(key, r);

    const assetKey = `${r.assetKey}|${r.hubKey}`;
    if (!assetSet.has(assetKey)) {
      error('E8', `${label}: no asset found for (${r.assetKey}, ${r.hubKey}) in assets section`);
    }

    const srKey = `${r.assetKey}|${r.hubKey}|${r.spokeKey}`;
    if (!spokeRegSet.has(srKey)) {
      error('E9', `${label}: no spoke registration found for (${r.assetKey}, ${r.hubKey}, ${r.spokeKey})`);
    }

    if (r.collateralFactor >= 10000) {
      error('E10', `${label}: collateralFactor ${r.collateralFactor} >= 10000 (must be < 100%)`);
    }

    if (r.maxLiquidationBonus !== undefined && r.maxLiquidationBonus < 10000) {
      error('E11', `${label}: maxLiquidationBonus ${r.maxLiquidationBonus} < 10000 (must be >= 100%)`);
    }

    if (r.collateralFactor > 0 && r.maxLiquidationBonus !== undefined && r.maxLiquidationBonus > 0) {
      const product = r.maxLiquidationBonus * r.collateralFactor;
      const percentMulUp = Math.ceil(product / 10000);
      if (percentMulUp >= 10000) {
        error('E12', `${label}: percentMulUp(maxLiquidationBonus=${r.maxLiquidationBonus}, collateralFactor=${r.collateralFactor}) = ${percentMulUp} >= 10000`);
      }
    }

    if (r.liquidationFee !== undefined && r.liquidationFee > 10000) {
      error('E13', `${label}: liquidationFee ${r.liquidationFee} > 10000 BPS`);
    }

    if (r.collateralRisk > 100000) {
      error('E15', `${label}: collateralRisk ${r.collateralRisk} > 100000 (max 1000.00%)`);
    }

    if (r.borrowable) {
      const sr = spokeRegMap.get(srKey);
      if (sr && sr.drawCap === 0) {
        error('E18', `${label}: borrowable=true but spoke registration has drawCap=0`);
      }
    }
  });

  // ── Periphery ──

  if (config.periphery) {
    if (!tokenKeys.has(config.periphery.nativeTokenKey)) {
      error('E17', `periphery.nativeTokenKey "${config.periphery.nativeTokenKey}" not found in tokens`);
    }
  }

  // ── Warnings ──

  // W2: collateralFactor > 0 but addCap=0
  config.reserves.forEach((r, i) => {
    if (r.collateralFactor === 0) return;
    const srKey = `${r.assetKey}|${r.hubKey}|${r.spokeKey}`;
    const sr = spokeRegMap.get(srKey);
    if (sr && sr.addCap === 0) {
      warn('W2', `reserves[${i}] (${r.spokeKey}/${r.hubKey}/${r.assetKey}): collateralFactor=${r.collateralFactor} but spoke registration has addCap=0`);
    }
  });

  // W3: drawCap > 0 but nothing borrowable
  config.spokeRegistrations.forEach((sr, i) => {
    if (sr.drawCap === 0) return;
    const rKey = `${sr.spokeKey}|${sr.hubKey}|${sr.assetKey}`;
    const reserve = reserveMap.get(rKey);
    if (reserve && !reserve.borrowable) {
      warn('W3', `spokeRegistrations[${i}] (${sr.assetKey}/${sr.hubKey}/${sr.spokeKey}): drawCap=${sr.drawCap} but reserve is not borrowable`);
    }
  });

  // W4: collateralFactor=0 AND borrowable=false
  config.reserves.forEach((r, i) => {
    if (r.collateralFactor === 0 && !r.borrowable) {
      warn('W4', `reserves[${i}] (${r.spokeKey}/${r.hubKey}/${r.assetKey}): collateralFactor=0 and borrowable=false — reserve serves no purpose`);
    }
  });

  // W6: spoke registration with no corresponding reserve
  config.spokeRegistrations.forEach((sr, i) => {
    const rKey = `${sr.spokeKey}|${sr.hubKey}|${sr.assetKey}`;
    if (!reserveSet.has(rKey)) {
      warn('W6', `spokeRegistrations[${i}] (${sr.assetKey}/${sr.hubKey}/${sr.spokeKey}): registered on hub but no reserve exists on spoke`);
    }
  });

  // W7: mock price feeds used in reserves
  const tokensUsedInReserves = new Set(config.reserves.map(r => r.assetKey));
  for (const tokenKey of tokensUsedInReserves) {
    const token = config.tokens[tokenKey];
    if (token && token.priceFeed === ZERO_ADDRESS) {
      warn('W7', `Token "${tokenKey}" has mock price feed (${ZERO_ADDRESS}) but is used in reserves`);
    }
  }

  return { errors, warnings };
}

// ── CLI entry point ─────────────────────────────────────────────────────────

const isMain = process.argv[1] && fileURLToPath(import.meta.url).endsWith(process.argv[1].replace(/.*\//, ''));
if (isMain) {
  const __dirname = path.dirname(fileURLToPath(import.meta.url));
  const configPath = process.argv[2] || path.resolve(__dirname, '../config/mainnet.json');
  const config = JSON.parse(fs.readFileSync(configPath, 'utf8'));
  const { errors, warnings } = validate(config);

  console.log('');
  if (errors.length > 0) {
    console.log('ERRORS:');
    errors.forEach(e => console.log(`  ERROR: [${e.code}] ${e.msg}`));
    console.log('');
  }
  if (warnings.length > 0) {
    console.log('WARNINGS:');
    warnings.forEach(w => console.log(`  WARN:  [${w.code}] ${w.msg}`));
    console.log('');
  }

  const summary = `=== Summary: ${errors.length} error(s), ${warnings.length} warning(s) ===`;
  if (errors.length > 0) {
    console.log(summary);
    process.exit(1);
  } else if (warnings.length > 0) {
    console.log(summary);
    process.exit(0);
  } else {
    console.log('All checks passed. No errors or warnings.');
    process.exit(0);
  }
}
