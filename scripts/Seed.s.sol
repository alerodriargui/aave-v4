// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import {Script, stdJson, console2 as console} from 'forge-std/Script.sol';
import {IHub} from 'src/hub/interfaces/IHub.sol';
import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';
import {IAaveOracle} from 'src/spoke/interfaces/IAaveOracle.sol';
import {IERC20Metadata} from 'src/dependencies/openzeppelin/IERC20Metadata.sol';
import {SafeERC20, IERC20} from 'src/dependencies/openzeppelin/SafeERC20.sol';
import {MockPriceFeed} from 'tests/mocks/MockPriceFeed.sol';
import {ConfigReader} from './ConfigReader.sol';
import {DeployReader} from './DeployReader.sol';
import {ScriptUtils} from './ScriptUtils.sol';
// import {LiquidationVictim} from 'tests/mocks/LiquidationVictim.sol'; // TODO: re-enable when LiquidationVictim mock is available

/// @title Seed
/// @notice Standalone seed script for Aave V4. Reads config + deploy JSON, performs
///         supply/withdraw/borrow/repay/liquidation with randomized amounts on all configured reserves.
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

  // TODO: re-enable when LiquidationVictim mock is available
  // /// @notice Set up a liquidatable position on each spoke, crash the price, and liquidate.
  // ///         Emits liquidation events for backend indexing.
  // function liquidate() external {
  //   _loadState();
  //   vm.startBroadcast();
  //   LiquidationVictim victim = new LiquidationVictim();
  //
  //   for (uint256 si = 0; _config.spokeExists(si); si++) {
  //     string memory key = _config.spokeKey(si);
  //     _liquidateSpoke(key, victim);
  //   }
  // }

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
    address oracle = _deploy.oracle(res.spokeKey);
    uint256 assetId = hub.getAssetId(token);
    uint256 reserveId = spoke.getReserveId(address(hub), assetId);

    if (token == 0xdAC17F958D2ee523a2206206994597C13D831ec7) return;

    // Skip if spoke cannot accept draw for this asset
    if (!spoke.getReserveConfig(reserveId).borrowable) return;

    // Random amount: $10 to $100 worth (oracle decimals = 8)
    uint256 targetUsd = bound(vm.randomUint(), 10e8, 100e8);
    uint256 amount = _getAmount(targetUsd, oracle, reserveId, token);

    IERC20(token).forceApprove(address(spoke), amount * 10);
    (, address caller, ) = vm.readCallers();
    bytes[] memory actions = new bytes[](3);
    actions[0] = abi.encodeCall(ISpoke.supply, (reserveId, amount * 10, caller));
    actions[1] = abi.encodeCall(ISpoke.setUsingAsCollateral, (reserveId, true, caller));
    actions[2] = abi.encodeCall(ISpoke.borrow, (reserveId, amount, caller));
    spoke.multicall(actions);

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

  // ==================== Liquidation (commented out — LiquidationVictim mock not available) ====================

  // TODO: re-enable when LiquidationVictim mock is available
  /*
  function _liquidateSpoke(string memory spokeKey, LiquidationVictim victim) internal {
    ISpoke spoke = ISpoke(_deploy.spoke(spokeKey));
    address oracle = _deploy.oracle(spokeKey);

    address collToken;
    address debtToken;
    uint256 collReserveId;
    uint256 debtReserveId;
    uint16 collateralFactor;
    {
      (bool found, uint256 collIdx, uint256 debtIdx) = _findLiquidationPair(spokeKey);
      if (!found) {
        console.log('liquidate: no pair for', spokeKey);
        return;
      }
      (collToken, debtToken, collReserveId, debtReserveId, collateralFactor) = _resolveLiqPair(
        spoke, collIdx, debtIdx
      );
    }

    {
      uint256 liquidityAmount = _getAmount(2000e8, oracle, debtReserveId, debtToken);
      _mintTokens(debtToken, liquidityAmount);
      IERC20(debtToken).forceApprove(address(spoke), liquidityAmount);
      (, address caller, ) = vm.readCallers();
      spoke.supply(debtReserveId, liquidityAmount, caller);
    }

    {
      uint256 supplyAmount = _getAmount(1000e8, oracle, collReserveId, collToken);
      uint256 borrowUsd = (uint256(1000e8) * collateralFactor * 80) / (10000 * 100);
      uint256 borrowAmount = _getAmount(borrowUsd, oracle, debtReserveId, debtToken);
      _mintTokens(collToken, supplyAmount);
      IERC20(collToken).safeTransfer(address(victim), supplyAmount);
      victim.openPosition(spoke, collToken, collReserveId, supplyAmount, debtReserveId, borrowAmount);
    }

    console.log('liquidate:', spokeKey);

    uint256 originalPrice = IAaveOracle(oracle).getReservePrice(collReserveId);
    _setPrice(spoke, collReserveId, originalPrice / 2);

    {
      uint256 debtToCover = spoke.getUserTotalDebt(debtReserveId, address(victim));
      _mintTokens(debtToken, debtToCover);
      IERC20(debtToken).forceApprove(address(spoke), debtToCover);
      spoke.liquidationCall(collReserveId, debtReserveId, address(victim), debtToCover, false);
      console.log('  liquidated debt', debtToCover);
    }

    _setPrice(spoke, collReserveId, originalPrice);
  }

  function _resolveLiqPair(ISpoke spoke, uint256 collIdx, uint256 debtIdx) internal view
    returns (address collToken, address debtToken, uint256 collReserveId, uint256 debtReserveId, uint16 collateralFactor)
  {
    ConfigReader.ReserveConfig memory collConf = _config.readReserve(collIdx);
    ConfigReader.ReserveConfig memory debtConf = _config.readReserve(debtIdx);
    collateralFactor = collConf.collateralFactor;
    IHub collHub = IHub(_deploy.hub(collConf.hubKey));
    IHub debtHub = IHub(_deploy.hub(debtConf.hubKey));
    collToken = _deploy.token(collConf.assetKey);
    debtToken = _deploy.token(debtConf.assetKey);
    uint256 collAssetId = collHub.getAssetId(collToken);
    collReserveId = spoke.getReserveId(address(collHub), collAssetId);
    debtReserveId = spoke.getReserveId(address(debtHub), debtHub.getAssetId(debtToken));
  }

  function _findLiquidationPair(string memory spokeKey) internal view
    returns (bool found, uint256 collIdx, uint256 debtIdx)
  {
    for (uint256 i = 0; _config.reserveExists(i); i++) {
      ConfigReader.ReserveConfig memory r = _config.readReserve(i);
      if (!ScriptUtils.strEq(r.spokeKey, spokeKey)) continue;
      if (r.collateralFactor == 0 || r.paused || r.frozen) continue;
      for (uint256 j = 0; _config.reserveExists(j); j++) {
        ConfigReader.ReserveConfig memory r2 = _config.readReserve(j);
        if (!ScriptUtils.strEq(r2.spokeKey, spokeKey)) continue;
        if (!r2.borrowable || r2.paused) continue;
        if (ScriptUtils.strEq(r.assetKey, r2.assetKey)) continue;
        return (true, i, j);
      }
    }
    return (false, 0, 0);
  }

  function _setPrice(ISpoke spoke, uint256 reserveId, uint256 newPrice) internal {
    uint8 oracleDecimals = IAaveOracle(spoke.ORACLE()).DECIMALS();
    address feed = address(new MockPriceFeed(oracleDecimals, 'SEED', newPrice));
    spoke.updateReservePriceSource(reserveId, feed);
  }
  */

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

    address[5] memory whales = [
      0x000000000004444c5dc75cB358380D2e3dE08A90,
      0x52Aa899454998Be5b000Ad077a46Bbe360F4e497,
      0x38C503a438185cDE29b5cF4dC1442FD6F074F1cc,
      0x8dAe8ECe668cf80d348873F23D456448E8694883,
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
