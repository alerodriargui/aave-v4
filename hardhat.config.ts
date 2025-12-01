import type {HardhatUserConfig} from 'hardhat/config';

import hardhatToolboxViemPlugin from '@nomicfoundation/hardhat-toolbox-viem';
import {configVariable} from 'hardhat/config';
import * as tdly from '@tenderly/hardhat-tenderly';

tdly.setup({automaticVerifications: !!process.env.TENDERLY_AUTOMATIC_VERIFICATION});

const config: HardhatUserConfig = {
  plugins: [hardhatToolboxViemPlugin],
  solidity: {
    profiles: {
      default: {
        version: '0.8.28',
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
          evmVersion: 'cancun',
        },
      },
    },
  },
  paths: {
    sources: 'src',
    tests: 'tests',
  },
  networks: {
    hardhatMainnet: {
      type: 'edr-simulated',
      chainType: 'l1',
    },
    hardhatOp: {
      type: 'edr-simulated',
      chainType: 'op',
    },
    sepolia: {
      type: 'http',
      chainType: 'l1',
      url: configVariable('SEPOLIA_RPC_URL'),
      accounts: [configVariable('SEPOLIA_PRIVATE_KEY')],
    },
    tenderly: {
      type: 'http',
      chainId: 123456789,
      url: 'https://virtual.mainnet.us-east.rpc.tenderly.co/3845ba81-648b-439d-aa02-22ba6551bf67',
    },
  },
  tenderly: {
    project: 'Aave',
    username: 'aave',
    privateVerification: true,
  },
};

export default config;
