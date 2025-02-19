// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import 'tests/scenario/liquidityHub/LiquidityHub.ScenarioBase.t.sol';
import {SpokeData} from 'src/contracts/LiquidityHub.sol';
import {Asset} from 'src/contracts/LiquidityHub.sol';
import {Utils} from 'tests/Utils.t.sol';

contract BorrowIndex_Scenario1Test is LiquidityHubScenarioBaseTest {
  using SharesMath for uint256;
  using WadRayMath for uint256;
  using PercentageMath for uint256;

  DataTypes.SpokeConfig internal spokeConfig;
  Spoke internal spoke4;

  // Scenario:
  // t0: asset added, spoke1 added, spoke1 draws
  // t1: spoke4 is added; spoke4 draws
  // t2: spoke4 trivial supply action to trigger accrual

  // Assumptions:
  // - constant 10% IR
  // - 1 year between each action
  // - single asset (weth)

  uint256 internal assetId;

  function setUp() public override {
    super.setUp();
    initEnvironment();
    spokeMintAndApprove();

    spokeConfig = DataTypes.SpokeConfig({supplyCap: type(uint256).max, drawCap: type(uint256).max});

    // mock constant 10% IR
    vm.mockCall(
      address(irStrategy),
      IReserveInterestRateStrategy.calculateInterestRates.selector,
      abi.encode(uint256(10_00).bpsToRay())
    );
    spoke4 = new Spoke(address(hub), address(oracle));
    spokes[3].addr = address(spoke4);

    isPrintLogs = false;
    assetId = wethAssetId;
  }

  function test_borrowIndexScenario1() public {
    _testScenario();
  }

  function precondition(Stage stage) internal override {
    super.precondition(stage);

    if (stage == stages[0]) {
      spokes[0].amounts.supply.t_i[t] = 10e18;
      spokes[0].amounts.draw.t_i[t] = 5e18;
    } else if (stage == stages[1]) {
      spokes[3].amounts.draw.t_i[t] = 1e18;
    } else if (stage == stages[2]) {
      spokes[3].amounts.supply.t_i[t] = 1e8;
    }
  }
  function initialAssertions(Stage stage) internal override {
    super.initialAssertions(stage);

    assets[assetId].t_i[t] = hub.getAsset(assetId);
    spokes[0].t_i[t] = hub.getSpoke(assetId, spokes[0].addr);
    spokes[3].t_i[t] = hub.getSpoke(assetId, spokes[3].addr);

    if (stage == stages[0]) {
      // asset
      assertEq(
        assets[assetId].t_i[t].baseBorrowIndex,
        hub.DEFAULT_ASSET_INDEX(),
        't0_i Asset index'
      );
      assertEq(assets[assetId].t_i[t].baseDebt, 0, 't0_i Asset base debt');
      assertEq(
        assets[assetId].t_i[t].lastUpdateTimestamp,
        timeAt(stages[t]),
        't0_i Asset lastUpdateTimestamp'
      );

      // spoke1
      assertEq(spokes[0].t_i[t].baseBorrowIndex, hub.DEFAULT_SPOKE_INDEX(), 't0_i Spoke1 index');
      assertEq(spokes[0].t_i[t].baseDebt, 0, 't0_i Spoke1 base debt');
      assertEq(spokes[0].t_i[t].lastUpdateTimestamp, 0, 't0_i Spoke1 lastUpdateTimestamp');
    } else if (stage == stages[1]) {
      assets[assetId].t_i[t] = hub.getAsset(assetId);
      spokes[0].t_i[t] = hub.getSpoke(assetId, spokes[0].addr);

      // asset
      assertEq(
        assets[assetId].t_i[t].baseBorrowIndex,
        hub.DEFAULT_ASSET_INDEX(),
        't1_i Asset index'
      );
      assertEq(
        assets[assetId].t_i[t].baseDebt,
        spokes[0].amounts.draw.t_i[t - 1],
        't1_i Asset base debt'
      );
      assertEq(
        assets[assetId].t_i[t].lastUpdateTimestamp,
        timeAt(stages[t - 1]),
        't1 Asset lastUpdateTimestamp'
      );

      // spoke1
      assertEq(
        spokes[0].t_i[t].baseBorrowIndex,
        assets[assetId].t_i[t - 1].baseBorrowIndex,
        't1_i Spoke1 index'
      );
      assertEq(
        spokes[0].t_i[t].baseDebt,
        spokes[0].amounts.draw.t_i[t - 1],
        't1_i Spoke1 base debt'
      );
      assertEq(
        spokes[0].t_i[t].lastUpdateTimestamp,
        timeAt(stages[t - 1]),
        't1_i Spoke1 lastUpdateTimestamp'
      );
      // no spoke4 yet
    } else if (stage == stages[2]) {
      // asset
      assertEq(
        assets[assetId].t_i[t].baseBorrowIndex,
        assets[assetId].t_f[t - 1].baseBorrowIndex,
        't2_i Asset index'
      );
      assertEq(
        assets[assetId].t_i[t].baseDebt,
        assets[assetId].t_f[t - 1].baseDebt,
        't2_i Asset base debt'
      );
      assertEq(
        assets[assetId].t_i[t].lastUpdateTimestamp,
        timeAt(stages[t - 1]),
        't2_i Asset lastUpdateTimestamp'
      );

      // spoke1
      assertEq(spokes[0].t_i[t].baseBorrowIndex, hub.DEFAULT_ASSET_INDEX(), 't2_i Spoke1 index');
      assertEq(spokes[0].t_i[t].baseDebt, spokes[0].amounts.draw.t_i[0], 't2_i Spoke1 base debt');
      assertEq(
        spokes[0].t_i[t].lastUpdateTimestamp,
        timeAt(stages[0]),
        't2_i Spoke1 lastUpdateTimestamp'
      );

      // spoke4
      assertEq(
        spokes[3].t_i[t].baseBorrowIndex,
        assets[assetId].t_i[t].baseBorrowIndex,
        't2_i Spoke4 index'
      );
      assertEq(
        spokes[3].t_i[t].baseDebt,
        spokes[3].amounts.draw.t_i[t - 1],
        't2_i Spoke4 base debt'
      );
      assertEq(
        spokes[3].t_i[t].lastUpdateTimestamp,
        timeAt(stages[t - 1]),
        't2_i Spoke4 lastUpdateTimestamp'
      );
    }
  }

  function exec(Stage stage) internal override {
    super.exec(stage);

    if (stage == stages[0]) {
      Utils.supply({
        hub: hub,
        assetId: assetId,
        spoke: spokes[0].addr,
        amount: spokes[0].amounts.supply.t_i[t],
        riskPremium: 0,
        user: bob,
        to: spokes[0].addr
      });
      Utils.draw({
        hub: hub,
        assetId: assetId,
        spoke: spokes[0].addr,
        amount: spokes[0].amounts.draw.t_i[t],
        riskPremium: 0,
        to: bob,
        onBehalfOf: spokes[0].addr
      });
    } else if (stage == stages[1]) {
      hub.addSpoke(assetId, spokeConfig, spokes[3].addr);
      Utils.draw({
        hub: hub,
        assetId: assetId,
        spoke: spokes[3].addr,
        amount: spokes[3].amounts.draw.t_i[t],
        riskPremium: 0,
        to: bob,
        onBehalfOf: spokes[3].addr
      });
    } else if (stage == stages[2]) {
      Utils.supply({
        hub: hub,
        assetId: assetId,
        spoke: spokes[3].addr,
        amount: spokes[3].amounts.supply.t_i[t],
        riskPremium: 0,
        user: bob,
        to: spokes[3].addr
      });
    }
  }

  function skipTime(Stage stage) internal override {
    super.skipTime(stage);

    skip(365 days);
  }

  function finalAssertions(Stage stage) internal override {
    super.finalAssertions(stage);

    assets[assetId].t_f[t] = hub.getAsset(assetId);
    spokes[0].t_f[t] = hub.getSpoke(assetId, spokes[0].addr);
    spokes[3].t_f[t] = hub.getSpoke(assetId, spokes[3].addr);

    if (stage == stages[0]) {
      // asset
      assertEq(
        assets[assetId].t_f[t].baseBorrowIndex,
        hub.DEFAULT_ASSET_INDEX(),
        't0_f Asset index'
      );
      assertEq(
        assets[assetId].t_f[t].baseDebt,
        spokes[0].amounts.draw.t_i[t],
        't0_f Asset base debt'
      );
      assertEq(
        assets[assetId].t_f[t].lastUpdateTimestamp,
        timeAt(stages[t]),
        't0_f Asset lastUpdateTimestamp'
      );

      // spoke1
      assertEq(spokes[0].t_f[t].baseBorrowIndex, hub.DEFAULT_ASSET_INDEX(), 't0_f Spoke1 index');
      assertEq(spokes[0].t_f[t].baseDebt, spokes[0].amounts.draw.t_i[t], 't0_f Spoke1 base debt');
      assertEq(
        spokes[0].t_f[t].lastUpdateTimestamp,
        timeAt(stages[t]),
        't0_f Spoke1 lastUpdateTimestamp'
      );
      // no spoke4 yet
    } else if (stage == stages[1]) {
      states.cumulatedBaseInterest.t_f[t] = MathUtils.calculateLinearInterest(
        assets[assetId].t_f[t - 1].baseBorrowRate,
        timeAt(stages[t - 1])
      );

      // asset
      assertEq(
        assets[assetId].t_f[t].baseBorrowIndex,
        assets[assetId].t_f[t - 1].baseBorrowIndex.rayMul(states.cumulatedBaseInterest.t_f[t]),
        't1_f Asset index'
      );
      assertEq(
        assets[assetId].t_f[t].baseDebt,
        spokes[0].amounts.draw.t_i[t - 1].rayMul(states.cumulatedBaseInterest.t_f[t]) +
          spokes[3].amounts.draw.t_i[t],
        't1_f Asset base debt'
      );
      assertEq(
        assets[assetId].t_f[t].lastUpdateTimestamp,
        timeAt(stages[t]),
        't1_f Asset lastUpdateTimestamp'
      );

      // spoke1
      // nothing changes vs t0 because no spoke1 action
      assertEq(
        spokes[0].t_f[t].baseBorrowIndex,
        spokes[0].t_f[t - 1].baseBorrowIndex,
        't1_f Spoke1 index'
      );
      assertEq(spokes[0].t_f[t].baseDebt, spokes[0].t_f[t - 1].baseDebt, 't1_f Spoke1 base debt');
      assertEq(
        spokes[0].t_f[t].lastUpdateTimestamp,
        spokes[0].t_f[t - 1].lastUpdateTimestamp,
        't1_f Spoke1 lastUpdateTimestamp'
      );

      // spoke4
      assertEq(
        spokes[3].t_f[t].baseBorrowIndex,
        assets[assetId].t_f[t].baseBorrowIndex,
        't1_f Spoke4 index'
      );
      assertEq(spokes[3].t_f[t].baseDebt, spokes[3].amounts.draw.t_i[t], 't1_f Spoke4 base debt');
      assertEq(
        spokes[3].t_f[t].lastUpdateTimestamp,
        timeAt(stages[t]),
        't1_f Spoke4 lastUpdateTimestamp'
      );
    } else if (stage == stages[2]) {
      states.cumulatedBaseInterest.t_f[t] = MathUtils.calculateLinearInterest(
        assets[assetId].t_f[1].baseBorrowRate,
        timeAt(stages[1])
      );

      // asset
      assertEq(
        assets[assetId].t_f[t].baseBorrowIndex,
        assets[assetId].t_f[1].baseBorrowIndex.rayMul(states.cumulatedBaseInterest.t_f[t]),
        't2_f Asset index'
      );
      assertEq(
        assets[assetId].t_f[t].baseDebt,
        assets[assetId].t_f[1].baseDebt.rayMul(states.cumulatedBaseInterest.t_f[t]),
        't1_f Asset base debt'
      );

      // spoke1
      // nothing changes vs t0 because no spoke1 action
      assertEq(
        spokes[0].t_f[t].baseBorrowIndex,
        spokes[0].t_f[0].baseBorrowIndex,
        't2_f Spoke1 index'
      );
      assertEq(spokes[0].t_f[t].baseDebt, spokes[0].t_f[0].baseDebt, 't2_f Spoke1 base debt');
      assertEq(
        spokes[0].t_f[t].lastUpdateTimestamp,
        spokes[0].t_f[0].lastUpdateTimestamp,
        't2_f Spoke1 lastUpdateTimestamp'
      );

      // spoke4
      assertEq(
        spokes[3].t_f[t].baseBorrowIndex,
        assets[assetId].t_f[t].baseBorrowIndex,
        't2_f Spoke4 index'
      );
      assertEq(
        spokes[3].t_f[t].baseDebt,
        spokes[3].amounts.draw.t_i[1].rayMul(states.cumulatedBaseInterest.t_f[t]),
        't2_f Spoke4 base debt'
      );
      assertEq(
        spokes[3].t_f[t].lastUpdateTimestamp,
        timeAt(stages[t]),
        't2_f Spoke4 lastUpdateTimestamp'
      );
    }
  }

  function printInitialLog(Stage stage) internal override {
    super.printInitialLog(stage);

    // Asset
    console.log('Asset borrow index %27e', assets[assetId].t_i[t].baseBorrowIndex);
    console.log('Asset base debt %e', assets[assetId].t_i[t].baseDebt);
    console.log('Asset last update timestamp', assets[assetId].t_i[t].lastUpdateTimestamp);

    // Spoke1
    console.log('Spoke1 borrow index %27e', spokes[0].t_i[t].baseBorrowIndex);
    console.log('Spoke1 base debt %e', spokes[0].t_i[t].baseDebt);
    console.log('Spoke1 last update timestamp', spokes[0].t_i[t].lastUpdateTimestamp);

    // Spoke4
    console.log('Spoke4 borrow index %27e', spokes[3].t_f[t].baseBorrowIndex);
    console.log('Spoke4 base debt %e', spokes[3].t_f[t].baseDebt);
    console.log('Spoke4 last update timestamp', spokes[3].t_f[t].lastUpdateTimestamp);
  }

  function printFinalLog(Stage stage) internal override {
    super.printFinalLog(stage);

    // Asset
    console.log('Asset borrow index %27e', assets[assetId].t_f[t].baseBorrowIndex);
    console.log('Asset base debt %e', assets[assetId].t_f[t].baseDebt);
    console.log('Asset last update timestamp', assets[assetId].t_f[t].lastUpdateTimestamp);

    // Spoke1
    console.log('Spoke1 borrow index %27e', spokes[0].t_f[t].baseBorrowIndex);
    console.log('Spoke1 base debt %e', spokes[0].t_f[t].baseDebt);
    console.log('Spoke1 last update timestamp', spokes[0].t_f[t].lastUpdateTimestamp);

    // Spoke4
    console.log('Spoke4 borrow index %27e', spokes[3].t_f[t].baseBorrowIndex);
    console.log('Spoke4 base debt %e', spokes[3].t_f[t].baseDebt);
    console.log('Spoke4 last update timestamp', spokes[3].t_f[t].lastUpdateTimestamp);
  }
}
