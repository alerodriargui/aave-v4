// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/deployments/batches/BatchBase.t.sol';

contract AaveV4GatewayBatchTest is BatchBaseTest {
  AaveV4GatewayBatch public gatewayBatch;
  BatchReports.GatewaysBatchReport public report;

  function setUp() public override {
    super.setUp();
    gatewayBatch = new AaveV4GatewayBatch(admin, nativeWrapper, salt);
    report = gatewayBatch.getReport();
  }

  function test_getReport() public view {
    assertNotEq(report.nativeGateway, address(0));
    assertNotEq(report.signatureGateway, address(0));
  }

  function test_nativeGatewayWiring() public view {
    NativeTokenGateway gateway = NativeTokenGateway(payable(report.nativeGateway));
    assertEq(gateway.owner(), admin);
    assertEq(gateway.NATIVE_WRAPPER(), nativeWrapper);
  }

  function test_signatureGatewayOwner() public view {
    assertEq(Ownable(report.signatureGateway).owner(), admin);
  }

  function test_revert_zeroOwner() public {
    vm.expectRevert('invalid owner');
    new AaveV4GatewayBatch(address(0), nativeWrapper, salt);
  }

  function test_revert_zeroNativeWrapper() public {
    vm.expectRevert('invalid native wrapper');
    new AaveV4GatewayBatch(admin, address(0), salt);
  }

  function test_differentSaltProducesDifferentAddress() public {
    AaveV4GatewayBatch newBatch = new AaveV4GatewayBatch(
      admin,
      nativeWrapper,
      keccak256('differentSalt')
    );
    assertNotEq(report.nativeGateway, newBatch.getReport().nativeGateway);
  }
}
