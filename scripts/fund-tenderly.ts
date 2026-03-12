/**
 * Top up ERC20 balances on a Tenderly fork for all tokens in a config file.
 *
 * Usage:
 *   bun scripts/fund-tenderly.ts <address> [config-path]
 *
 * Examples:
 *   bun scripts/fund-tenderly.ts 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
 *   bun scripts/fund-tenderly.ts 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 config/generated.json
 *
 * Reads `td2` from .env for the Tenderly RPC URL.
 * Default config: config/mainnet.json
 * Default amount: 10^30 wei (covers any token regardless of decimals)
 */

import {readFileSync, existsSync} from 'fs';
import {resolve} from 'path';

// ---------------------------------------------------------------------------
// .env loader (no dependencies)
// ---------------------------------------------------------------------------
function loadEnv() {
  const envPath = resolve(process.cwd(), '.env');
  if (!existsSync(envPath)) return;
  for (const line of readFileSync(envPath, 'utf-8').split('\n')) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith('#')) continue;
    const eq = trimmed.indexOf('=');
    if (eq === -1) continue;
    const key = trimmed.slice(0, eq);
    let val = trimmed.slice(eq + 1);
    if ((val.startsWith('"') && val.endsWith('"')) || (val.startsWith("'") && val.endsWith("'")))
      val = val.slice(1, -1);
    if (!process.env[key]) process.env[key] = val;
  }
}

loadEnv();

// ---------------------------------------------------------------------------
// Args
// ---------------------------------------------------------------------------
const userAddress = process.argv[2];
if (!userAddress || !userAddress.startsWith('0x')) {
  console.error('Usage: bun scripts/fund-tenderly.ts <address> [config-path]');
  process.exit(1);
}

const td2 = process.env.td2;
if (!td2) {
  console.error('td2 not set in .env');
  process.exit(1);
}

const configPath = process.argv[3] || process.env.CONFIG_PATH || 'config/mainnet.json';
const config = JSON.parse(readFileSync(configPath, 'utf-8'));
const tokens: Record<string, {address: string; priceFeed: string}> = config.tokens;

if (!tokens || Object.keys(tokens).length === 0) {
  console.error(`No tokens found in ${configPath}`);
  process.exit(1);
}

// Default: 10^30 — large enough for any token regardless of decimals
const DEFAULT_AMOUNT = '0x' + (10n ** 30n).toString(16);
const amount = process.env.FUND_AMOUNT || DEFAULT_AMOUNT;

// ---------------------------------------------------------------------------
// RPC helper
// ---------------------------------------------------------------------------
let reqId = 1;

async function rpc(method: string, params: unknown[]): Promise<unknown> {
  const body = JSON.stringify({
    jsonrpc: '2.0',
    method,
    params,
    id: reqId++,
  });

  const res = await fetch(td2!, {
    method: 'POST',
    headers: {'Content-Type': 'application/json'},
    body,
  });

  const json = (await res.json()) as {result?: unknown; error?: {message: string}};
  if (json.error) throw new Error(json.error.message);
  return json.result;
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------
console.log(`Funding ${userAddress} on ${td2}`);
console.log(`Config: ${configPath} (${Object.keys(tokens).length} tokens)`);
console.log(`Amount: ${amount}\n`);

let ok = 0;
let fail = 0;

for (const [key, tok] of Object.entries(tokens)) {
  try {
    await rpc('tenderly_setErc20Balance', [tok.address, userAddress, amount]);
    console.log(`  ✓ ${key} (${tok.address})`);
    ok++;
  } catch (e: any) {
    console.log(`  ✗ ${key} (${tok.address}): ${e.message}`);
    fail++;
  }
}

console.log(`\nDone: ${ok} succeeded, ${fail} failed`);
if (fail > 0) process.exit(1);
