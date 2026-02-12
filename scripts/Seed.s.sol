// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {Script, stdJson, console2 as console} from 'forge-std/Script.sol';
import {IHub} from 'src/hub/interfaces/IHub.sol';
import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';
import {IAaveOracle} from 'src/spoke/interfaces/IAaveOracle.sol';
import {IERC20Metadata} from 'src/dependencies/openzeppelin/IERC20Metadata.sol';
import {SafeERC20, IERC20} from 'src/dependencies/openzeppelin/SafeERC20.sol';
import {ConfigReader} from './ConfigReader.sol';
import {DeployReader} from './DeployReader.sol';

/// @title Seed
/// @notice Standalone seed script for Aave V4. Reads config + deploy JSON, performs
///         supply/withdraw/borrow/repay with randomized amounts on all configured reserves.
/// @dev Uses ConfigReader + DeployReader libraries (no manual mapping restoration).
///      Run: `forge script scripts/Seed.s.sol -s "run()" --fork-url <RPC> --broadcast`
contract Seed is Script {
  using stdJson for string;
  using SafeERC20 for IERC20;
  using ConfigReader for string;
  using DeployReader for string;

  string internal _config;
  string internal _deploy;

  // ==================== State Loading ====================

  function _loadState() internal {
    string memory configPath = vm.envOr('CONFIG_PATH', string('config/mainnet.json'));
    string memory deployPath = vm.envOr('DEPLOY_PATH', string('output/deploy.json'));
    _config = vm.readFile(configPath);
    _deploy = vm.readFile(deployPath);
  }

  // ==================== Entry Points ====================

  /// @notice Default: supply all reserves then borrow all borrowable reserves.
  function run() external {
    _loadState();
    vm.startBroadcast();
    for (uint256 i; _config.reserveExists(i); i++) _supply(i);
    for (uint256 i; _config.reserveExists(i); i++) _borrow(i);
  }

  /// @notice Supply random amounts to all reserves.
  function supplyAll() external {
    _loadState();
    vm.startBroadcast();
    for (uint256 i; _config.reserveExists(i); i++) _supply(i);
  }

  /// @notice Borrow random amounts from all borrowable reserves.
  function borrowAll() external {
    _loadState();
    vm.startBroadcast();
    for (uint256 i; _config.reserveExists(i); i++) _borrow(i);
  }

  /// @notice Repay 60% of debt on all reserves.
  function repayAll() external {
    _loadState();
    vm.startBroadcast();
    for (uint256 i; _config.reserveExists(i); i++) _repay(i);
  }

  /// @notice Withdraw random amounts from all reserves.
  function withdrawAll() external {
    _loadState();
    vm.startBroadcast();
    for (uint256 i; _config.reserveExists(i); i++) _withdraw(i);
  }

  // ==================== Actions ====================

  function _supply(uint256 i) internal {
    ConfigReader.ReserveConfig memory res = _config.readReserve(i);
    IHub hub = IHub(_deploy.hub(res.hubKey));
    ISpoke spoke = ISpoke(_deploy.spoke(res.spokeKey));
    address token = _deploy.token(res.assetKey);
    address oracle = _deploy.oracle(res.spokeKey);
    uint256 assetId = hub.getAssetId(token);
    uint256 reserveId = spoke.getReserveId(address(hub), assetId);

    // Skip if spoke cannot accept supply for this asset
    if (hub.getSpokeConfig(assetId, address(spoke)).addCap == 0) return;

    if (token == 0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984) return; // problem w uni

    // Random amount: $0.01 to $100 worth (oracle decimals = 8)
    uint256 targetUsd = bound(vm.randomUint(), 0.01e8, 100e8);
    uint256 amount = _getAmount(targetUsd, oracle, reserveId, token);

    (, address caller, ) = vm.readCallers();
    _mintTokens(token, amount);
    IERC20(token).forceApprove(address(spoke), amount);
    spoke.supply(reserveId, amount, caller);
    spoke.setUsingAsCollateral(reserveId, true, caller);

    console.log('supply', res.assetKey, res.spokeKey);
    console.log('  amount', amount);
  }

  function _borrow(uint256 i) internal {
    ConfigReader.ReserveConfig memory res = _config.readReserve(i);
    if (!res.borrowable) return;

    IHub hub = IHub(_deploy.hub(res.hubKey));
    ISpoke spoke = ISpoke(_deploy.spoke(res.spokeKey));
    address token = _deploy.token(res.assetKey);
    uint256 assetId = hub.getAssetId(token);
    uint256 reserveId = spoke.getReserveId(address(hub), assetId);

    uint8 decimals = IERC20Metadata(token).decimals();
    uint256 upperBound = decimals >= 4 ? 10 ** (decimals - 3) : 10;
    uint256 amount = bound(vm.randomUint(), 2, upperBound);
    if (amount == 0) return;

    (, address caller, ) = vm.readCallers();
    spoke.borrow(reserveId, amount, caller);

    console.log('borrow', res.assetKey, res.spokeKey);
    console.log('  amount', amount);
  }

  function _repay(uint256 i) internal {
    ConfigReader.ReserveConfig memory res = _config.readReserve(i);
    IHub hub = IHub(_deploy.hub(res.hubKey));
    ISpoke spoke = ISpoke(_deploy.spoke(res.spokeKey));
    address token = _deploy.token(res.assetKey);
    uint256 assetId = hub.getAssetId(token);
    uint256 reserveId = spoke.getReserveId(address(hub), assetId);

    (, address caller, ) = vm.readCallers();
    uint256 debt = spoke.getUserTotalDebt(reserveId, caller);
    uint256 amount = (debt * 3) / 5; // Repay 60%
    if (amount == 0) return;

    _mintTokens(token, amount);
    IERC20(token).forceApprove(address(spoke), amount);
    spoke.repay(reserveId, amount, caller);

    console.log('repay', res.assetKey, res.spokeKey);
    console.log('  amount', amount);
  }

  function _withdraw(uint256 i) internal {
    ConfigReader.ReserveConfig memory res = _config.readReserve(i);
    IHub hub = IHub(_deploy.hub(res.hubKey));
    ISpoke spoke = ISpoke(_deploy.spoke(res.spokeKey));
    address token = _deploy.token(res.assetKey);
    uint256 assetId = hub.getAssetId(token);
    uint256 reserveId = spoke.getReserveId(address(hub), assetId);

    (, address caller, ) = vm.readCallers();
    uint256 maxWithdraw = spoke.getUserSuppliedAssets(reserveId, caller);
    uint256 amount = bound(vm.randomUint(), 0, maxWithdraw);
    if (amount == 0) return;

    spoke.withdraw(reserveId, amount, caller);

    console.log('withdraw', res.assetKey, res.spokeKey);
    console.log('  amount', amount);
  }

  // ==================== Utilities ====================

  /// @dev Convert a USD target (in oracle decimals, e.g. 100e8 = $100) to token units.
  function _getAmount(
    uint256 targetPriceUsd,
    address oracle,
    uint256 reserveId,
    address token
  ) internal view returns (uint256) {
    uint256 price = IAaveOracle(oracle).getReservePrice(reserveId);
    require(price > 0, 'oracle price is 0');
    uint8 decimals = IERC20Metadata(token).decimals();
    return (targetPriceUsd * (10 ** decimals)) / price;
  }

  /// @dev Ensure the broadcast caller has at least `amount` of `tokenAddr`.
  ///      Tries known whale addresses first. Falls back to revert if no source found.
  // TODO: find a more robust minting/sourcing strategy (deal() doesn't work for all ERC20s)
  function _mintTokens(address tokenAddr, uint256 amount) internal {
    (, address caller, ) = vm.readCallers();
    IERC20 token = IERC20(tokenAddr);
    uint256 balance = token.balanceOf(caller);
    if (balance >= amount) return;
    uint256 left = amount - balance;

    address[3] memory whales = [
      0x000000000004444c5dc75cB358380D2e3dE08A90,
      0x52Aa899454998Be5b000Ad077a46Bbe360F4e497,
      tokenAddr
    ];
    for (uint256 i; i < whales.length; ++i) {
      address whale = whales[i];
      if (token.balanceOf(whale) >= left) {
        vm.stopBroadcast();
        vm.startBroadcast(whale);
        token.safeTransfer(caller, left);
        vm.stopBroadcast();
        vm.startBroadcast();
        return;
      }
    }

    revert(
      string.concat('_mintTokens: no whale with sufficient balance for ', vm.toString(tokenAddr))
    );
  }
}
