// SPDX-License-Identifier: UNLICENSED
// Copyright (c) 2025 Aave Labs
pragma solidity ^0.8.0;

import 'tests/unit/misc/SignatureGateway/SignatureGateway.Base.t.sol';
import {ISignatureTransfer} from 'lib/permit2/src/interfaces/ISignatureTransfer.sol';
import {DeployPermit2} from 'lib/permit2/test/utils/DeployPermit2.sol';
import {EIP712Hash} from 'src/position-manager/libraries/EIP712Hash.sol';

contract SignatureGatewayPermit2BaseTest is SignatureGatewayBaseTest, DeployPermit2 {
  bytes32 internal constant _TOKEN_PERMISSIONS_TYPEHASH =
    keccak256('TokenPermissions(address token,uint256 amount)');

  bytes32 internal constant _FULL_SUPPLY_WITNESS_TYPEHASH =
    keccak256(
      'PermitWitnessTransferFrom(TokenPermissions permitted,address spender,uint256 nonce,uint256 deadline,Supply witness)Supply(address spoke,uint256 reserveId,uint256 amount,address onBehalfOf,uint256 nonce,uint256 deadline)TokenPermissions(address token,uint256 amount)'
    );

  bytes32 internal constant _FULL_REPAY_WITNESS_TYPEHASH =
    keccak256(
      'PermitWitnessTransferFrom(TokenPermissions permitted,address spender,uint256 nonce,uint256 deadline,Repay witness)Repay(address spoke,uint256 reserveId,uint256 amount,address onBehalfOf,uint256 nonce,uint256 deadline)TokenPermissions(address token,uint256 amount)'
    );

  bytes32 internal PERMIT2_DOMAIN_SEPARATOR;

  function setUp() public virtual override {
    super.setUp();
    deployPermit2();
    PERMIT2_DOMAIN_SEPARATOR = ISignatureTransfer(gateway.PERMIT2()).DOMAIN_SEPARATOR();

    vm.prank(SPOKE_ADMIN);
    spoke1.updatePositionManager(address(gateway), true);
    vm.prank(alice);
    spoke1.setUserPositionManager(address(gateway), true);
  }

  function _permit2SupplyData(
    ISpoke spoke,
    address who,
    uint256 deadline
  ) internal returns (ISignatureTransfer.PermitTransferFrom memory permit, ISignatureGateway.Supply memory params) {
    uint256 reserveId = _randomReserveId(spoke);
    uint256 amount = vm.randomUint(1, MAX_SUPPLY_AMOUNT);
    address underlying = address(_underlying(spoke, reserveId));

    permit = ISignatureTransfer.PermitTransferFrom({
      permitted: ISignatureTransfer.TokenPermissions({token: underlying, amount: amount}),
      nonce: vm.randomUint(),
      deadline: deadline
    });

    params = ISignatureGateway.Supply({
      spoke: address(spoke),
      reserveId: reserveId,
      amount: amount,
      onBehalfOf: who,
      nonce: permit.nonce,
      deadline: deadline
    });
  }

  function _permit2RepayData(
    ISpoke spoke,
    address who,
    uint256 deadline
  ) internal returns (ISignatureTransfer.PermitTransferFrom memory permit, ISignatureGateway.Repay memory params) {
    uint256 reserveId = _randomReserveId(spoke);
    uint256 amount = vm.randomUint(1, MAX_SUPPLY_AMOUNT);
    address underlying = address(_underlying(spoke, reserveId));

    permit = ISignatureTransfer.PermitTransferFrom({
      permitted: ISignatureTransfer.TokenPermissions({token: underlying, amount: amount}),
      nonce: vm.randomUint(),
      deadline: deadline
    });

    params = ISignatureGateway.Repay({
      spoke: address(spoke),
      reserveId: reserveId,
      amount: amount,
      onBehalfOf: who,
      nonce: permit.nonce,
      deadline: deadline
    });
  }

  function _getPermit2SupplySignature(
    ISignatureTransfer.PermitTransferFrom memory permit,
    ISignatureGateway.Supply memory params,
    uint256 privateKey
  ) internal view returns (bytes memory) {
    bytes32 witness = _getSupplyWitnessHash(params);
    return _getPermit2WitnessSignature(permit, witness, _FULL_SUPPLY_WITNESS_TYPEHASH, privateKey);
  }

  function _getPermit2RepaySignature(
    ISignatureTransfer.PermitTransferFrom memory permit,
    ISignatureGateway.Repay memory params,
    uint256 privateKey
  ) internal view returns (bytes memory) {
    bytes32 witness = _getRepayWitnessHash(params);
    return _getPermit2WitnessSignature(permit, witness, _FULL_REPAY_WITNESS_TYPEHASH, privateKey);
  }

  function _getPermit2WitnessSignature(
    ISignatureTransfer.PermitTransferFrom memory permit,
    bytes32 witness,
    bytes32 fullTypehash,
    uint256 privateKey
  ) internal view returns (bytes memory) {
    bytes32 tokenPermissionsHash = keccak256(
      abi.encode(_TOKEN_PERMISSIONS_TYPEHASH, permit.permitted.token, permit.permitted.amount)
    );

    bytes32 structHash = keccak256(
      abi.encode(fullTypehash, tokenPermissionsHash, address(gateway), permit.nonce, permit.deadline, witness)
    );

    bytes32 digest = keccak256(abi.encodePacked('\x19\x01', PERMIT2_DOMAIN_SEPARATOR, structHash));

    (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);
    return abi.encodePacked(r, s, v);
  }

  function _getSupplyWitnessHash(ISignatureGateway.Supply memory params) internal pure returns (bytes32) {
    return
      keccak256(
        abi.encode(
          EIP712Hash.SUPPLY_TYPEHASH,
          params.spoke,
          params.reserveId,
          params.amount,
          params.onBehalfOf,
          params.nonce,
          params.deadline
        )
      );
  }

  function _getRepayWitnessHash(ISignatureGateway.Repay memory params) internal pure returns (bytes32) {
    return
      keccak256(
        abi.encode(
          EIP712Hash.REPAY_TYPEHASH,
          params.spoke,
          params.reserveId,
          params.amount,
          params.onBehalfOf,
          params.nonce,
          params.deadline
        )
      );
  }

  function _approvePermit2(ISpoke spoke, uint256 reserveId, address who) internal {
    address underlying = address(_underlying(spoke, reserveId));
    vm.startPrank(who);
    IERC20(underlying).approve(gateway.PERMIT2(), type(uint256).max);
    vm.stopPrank();
  }
}
