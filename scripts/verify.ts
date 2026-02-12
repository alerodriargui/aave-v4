// scripts/verify-tenderly.ts
import {execSync} from 'child_process';
import {readFileSync, existsSync} from 'fs';
import {resolve} from 'path';

// Load .env manually (simple key=value parsing, no dependency needed)
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
    // strip surrounding quotes
    if ((val.startsWith('"') && val.endsWith('"')) || (val.startsWith("'") && val.endsWith("'")))
      val = val.slice(1, -1);
    if (!process.env[key]) process.env[key] = val;
  }
}

loadEnv();

const td2 = process.env.td2;
if (!td2) {
  console.error('td2 not set in env');
  process.exit(1);
}

const deployPath = process.env.DEPLOY_PATH || './output/deploy.json';
const deploy = JSON.parse(readFileSync(deployPath, 'utf-8'));

// Contract name mapping (fully qualified)
const CONTRACTS = {
  accessManager: 'src/dependencies/openzeppelin/AccessManager.sol:AccessManager',
  hub: 'src/hub/Hub.sol:Hub',
  treasury: 'src/spoke/TreasurySpoke.sol:TreasurySpoke',
  irStrategy: 'src/hub/AssetInterestRateStrategy.sol:AssetInterestRateStrategy',
  oracle: 'src/spoke/AaveOracle.sol:AaveOracle',
  signatureGateway: 'src/position-manager/SignatureGateway.sol:SignatureGateway',
  nativeTokenGateway: 'src/position-manager/NativeTokenGateway.sol:NativeTokenGateway',
  hubConfigurator: 'src/hub/HubConfigurator.sol:HubConfigurator',
  spokeConfigurator: 'src/spoke/SpokeConfigurator.sol:SpokeConfigurator',
} as const;

const PROXY_CONTRACT =
  'src/dependencies/openzeppelin/TransparentUpgradeableProxy.sol:TransparentUpgradeableProxy';
const PROXY_SECTIONS = {
  spoke: 'src/spoke/instances/SpokeInstance.sol:SpokeInstance',
  tokenized: 'src/spoke/instances/TokenizationSpokeInstance.sol:TokenizationSpokeInstance',
} as const;

type Result = {label: string; ok: boolean; error?: string};
const results: Result[] = [];

function verify(address: string, contractName: string, label: string) {
  const cmd = `forge verify-contract ${address} ${contractName} --rpc-url ${td2} --verifier custom --verifier-url "${td2}/verify" --watch`;
  console.log(`\n→ ${label}: ${address}`);
  try {
    execSync(cmd, {stdio: 'inherit'});
    results.push({label, ok: true});
  } catch (e: any) {
    results.push({label, ok: false, error: e.message?.slice(0, 120)});
  }
}

function getImpl(proxyAddress: string): string {
  return execSync(`cast implementation ${proxyAddress} --rpc-url ${td2}`, {
    encoding: 'utf-8',
  }).trim();
}

// --- Singleton contracts ---
for (const [key, contractName] of Object.entries(CONTRACTS)) {
  const val = deploy[key];
  if (!val) continue;
  if (typeof val === 'string') {
    verify(val, contractName, key);
  } else {
    // Object with sub-keys (hub, treasury, irStrategy, oracle)
    for (const [subKey, addr] of Object.entries(val)) {
      verify(addr as string, contractName, `${key}.${subKey}`);
    }
  }
}

// --- Proxied contracts (spoke, tokenized) ---
for (const [section, implContractName] of Object.entries(PROXY_SECTIONS)) {
  const entries = deploy[section];
  if (!entries) continue;
  for (const [subKey, proxyAddr] of Object.entries(entries)) {
    const addr = proxyAddr as string;
    // 1. Verify proxy
    verify(addr, PROXY_CONTRACT, `${section}.${subKey} (proxy)`);
    // 2. Get + verify implementation
    try {
      const implAddr = getImpl(addr);
      if (implAddr && implAddr !== '0x0000000000000000000000000000000000000000') {
        verify(implAddr, implContractName, `${section}.${subKey} (impl)`);
      }
    } catch (e: any) {
      results.push({
        label: `${section}.${subKey} (impl fetch)`,
        ok: false,
        error: e.message?.slice(0, 120),
      });
    }
  }
}

// --- Summary ---
console.log('\n' + '='.repeat(60));
const ok = results.filter((r) => r.ok);
const fail = results.filter((r) => !r.ok);
console.log(`✓ ${ok.length} succeeded, ✗ ${fail.length} failed out of ${results.length} total`);
if (fail.length) {
  console.log('\nFailed:');
  for (const f of fail) console.log(`  ✗ ${f.label}: ${f.error ?? 'unknown'}`);
}
