import {$} from 'bun';

interface AdditionalContract {
  transactionType: string;
  contractName: string;
  address: string;
}

interface Transaction {
  hash: string;
  transactionType: string;
  contractName: string | null;
  contractAddress: string | null;
  arguments: string[] | null;
  additionalContracts: AdditionalContract[];
}

interface Broadcast {
  transactions: Transaction[];
}

interface DeployedContract {
  name: string;
  address: string;
  txHash: string;
  hasArgs: boolean;
}

function parseArgs(): {broadcastPath: string; rpcUrl: string} {
  const args = process.argv.slice(2);
  const rpcIdx = args.indexOf('--rpc-url');

  if (rpcIdx === -1 || !args[rpcIdx + 1]) {
    console.error(
      'Usage: bun run scripts/verify-broadcast.ts <broadcast-json> --rpc-url <rpc-url>',
    );
    process.exit(1);
  }

  const rpcUrl = args[rpcIdx + 1];
  const remaining = args.filter((_, i) => i !== rpcIdx && i !== rpcIdx + 1);

  if (!remaining[0]) {
    console.error(
      'Usage: bun run scripts/verify-broadcast.ts <broadcast-json> --rpc-url <rpc-url>',
    );
    process.exit(1);
  }

  return {broadcastPath: remaining[0], rpcUrl};
}

function collectDeployedContracts(broadcast: Broadcast): DeployedContract[] {
  const contracts: DeployedContract[] = [];

  for (const tx of broadcast.transactions) {
    if (
      (tx.transactionType === 'CREATE' || tx.transactionType === 'CREATE2') &&
      tx.contractName &&
      tx.contractAddress
    ) {
      contracts.push({
        name: tx.contractName,
        address: tx.contractAddress,
        txHash: tx.hash,
        hasArgs: Array.isArray(tx.arguments) && tx.arguments.length > 0,
      });
    }

    for (const nested of tx.additionalContracts ?? []) {
      if (
        (nested.transactionType === 'CREATE' || nested.transactionType === 'CREATE2') &&
        nested.contractName &&
        nested.address
      ) {
        contracts.push({
          name: nested.contractName,
          address: nested.address,
          txHash: tx.hash,
          hasArgs: false,
        });
      }
    }
  }

  return contracts;
}

async function verifyContract(contract: DeployedContract, rpcUrl: string): Promise<boolean> {
  const args = [
    'forge',
    'verify-contract',
    contract.address,
    contract.name,
    '--rpc-url',
    rpcUrl,
    '--verifier',
    'custom',
    '--verifier-url',
    'https://virtual.mainnet-aave.us-east.rpc.tenderly.co/38393fd3-0a79-4e60-b8cc-c6bb5903454a/verify',
  ];

  console.log(`\nVerifying ${contract.name} at ${contract.address} (tx: ${contract.txHash})...`);

  const result = await $`${args}`.nothrow().quiet();

  if (result.exitCode === 0) {
    console.log(`  OK: ${contract.name}`);
    return true;
  } else {
    console.error(`  FAIL: ${contract.name}`);
    console.error(`  ${result.stderr.toString().trim()}`);
    return false;
  }
}

async function main() {
  const {broadcastPath, rpcUrl} = parseArgs();

  const file = Bun.file(broadcastPath);
  if (!(await file.exists())) {
    console.error(`File not found: ${broadcastPath}`);
    process.exit(1);
  }

  const broadcast: Broadcast = await file.json();
  const contracts = collectDeployedContracts(broadcast);

  console.log(`Found ${contracts.length} deployed contracts to verify`);

  let passed = 0;
  let failed = 0;

  for (const contract of contracts) {
    const ok = await verifyContract(contract, rpcUrl);
    if (ok) passed++;
    else failed++;
  }

  console.log(`\nDone: ${passed} verified, ${failed} failed out of ${contracts.length} total`);

  if (failed > 0) process.exit(1);
}

main();
