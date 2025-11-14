// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.20;

import {console2 as console} from 'forge-std/console2.sol';

import {Script} from 'forge-std/Script.sol';
import {IHub} from 'src/hub/interfaces/IHub.sol';
import {ISpoke} from 'src/spoke/interfaces/ISpoke.sol';
import {IAaveOracle} from 'src/spoke/interfaces/IAaveOracle.sol';
import {MockPriceFeed} from 'tests/mocks/MockPriceFeed.sol';
import {IERC20} from 'src/dependencies/openzeppelin/IERC20.sol';
import {PercentageMath} from 'src/libraries/math/PercentageMath.sol';

// Order:
// 1. Supply and borrow; Deploy mock price feed
// 2. Update storage via tenderly_setStorageAt to the mock price feed
// 3. Liquidate
// 4. Revert storage to the original price feed
contract SupplyAndBorrowScript is Script {
  using PercentageMath for uint256;

  ISpoke internal spoke = ISpoke(0x4054a9EbfcdB692599a8dF61eb0b3484F2d279D4); // frontier spoke
  IHub internal hub = IHub(0x47152350A8CBc93632Ea17DF38D5B3D44BA4ef53); // frontier hub
  address internal ADMIN = 0x7f1fa86B2D643dF2E27C61F72D2443D4F991A8F7;

  address internal user = 0x98cAca8C27adB82a0D3C1efb2CE82E7124d1cfE9;

  uint256 internal collateralReserveId = 0; // UNI
  uint256 internal debtReserveId = 4; // USDC

  ISpoke.Reserve collateralReserve;
  ISpoke.Reserve debtReserve;
  IAaveOracle oracle;
  function run() public virtual {
    collateralReserve = spoke.getReserve(collateralReserveId);
    debtReserve = spoke.getReserve(debtReserveId);
    oracle = IAaveOracle(spoke.ORACLE());

    vm.startBroadcast();
    _execute();
    vm.stopBroadcast();
  }

  function _execute() internal virtual {
    _supplyAndBorrow();
    _deployMockPriceFeed();
  }

  function _supplyAndBorrow() internal {
    uint256 supplyAmount = 15_000e18; // UNI

    console.log('debt reserve', debtReserve.underlying);

    IERC20(collateralReserve.underlying).approve(address(spoke), type(uint256).max);
    IERC20(debtReserve.underlying).approve(address(spoke), type(uint256).max);

    spoke.supply(collateralReserveId, supplyAmount, user);
    spoke.setUsingAsCollateral(collateralReserveId, true, user);

    uint256 debtAmount = spoke.getUserAccountData(user).totalCollateralValue.percentMulDown(
      spoke.getDynamicReserveConfig(collateralReserveId).collateralFactor
    ) / 1e26; // debt amount in $ value
    debtAmount = debtAmount * 10 ** debtReserve.decimals; // USDC

    // supply enough debt asset to be borrowed
    spoke.supply(debtReserveId, debtAmount, user);
    spoke.borrow(debtReserveId, debtAmount, user);

    console.log('HF %e', spoke.getUserAccountData(user).healthFactor);
  }

  function _deployMockPriceFeed() internal virtual {
    uint256 currentPrice = oracle.getReservePrice(collateralReserveId);
    uint256 newPrice = currentPrice.percentMulDown(96_00);

    IAaveOracle oracle = IAaveOracle(spoke.ORACLE());
    MockPriceFeed mockPriceFeed = new MockPriceFeed(
      oracle.DECIMALS(),
      oracle.DESCRIPTION(),
      newPrice
    );

    console.log('newPrice', newPrice);
    console.log('underlying', collateralReserve.underlying);
    console.log('original price feed', oracle.getReserveSource(collateralReserveId));
    console.log('newPriceFeed', address(mockPriceFeed));

    bytes32 slotForReserveId = keccak256(abi.encode(collateralReserveId, uint256(1)));
    // # cast rpc tenderly_setStorageAt TARGET SLOT VALUE --rpc-url mainnet
    console.log('target', address(oracle));
    console.log('slot');
    console.logBytes32(slotForReserveId);
    console.log('value');
    console.logBytes32(bytes32(uint256(uint160(address(mockPriceFeed)))));
  }
}

contract LiquidationCallScript is SupplyAndBorrowScript {
  address internal initialPriceFeed;
  address internal newPriceFeed;
  address internal liquidator = 0xa94B418ec84425965ce4c3735514Fc31dD2bb44B;

  function _execute() internal override {
    uint256 debtToCover = 2000e6;
    bool receiveShares = false;

    console.log('price %e', oracle.getReservePrice(collateralReserveId));
    console.log('hf %e', spoke.getUserAccountData(user).healthFactor);

    IERC20(debtReserve.underlying).approve(address(spoke), type(uint256).max);
    spoke.liquidationCall(collateralReserveId, debtReserveId, user, debtToCover, receiveShares);

    console.log('hf after %e', spoke.getUserAccountData(user).healthFactor);
    console.log('coll value after %e', spoke.getUserAccountData(user).totalCollateralValue);
    console.log('debt value after %e', spoke.getUserAccountData(user).totalDebtValue);
  }
}
