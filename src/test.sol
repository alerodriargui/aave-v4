pragma solidity ^0.8.0;

import {WadRayMath} from 'src/contracts/WadRayMath.sol';
import {MathUtils} from 'src/contracts/MathUtils.sol';
import {Test, console2 as console} from 'forge-std/Test.sol';

contract MathTets is Test {
  using WadRayMath for uint256;

  function test_hello() public {
    assertEq(WadRayMath.RAY, 1e27);

    uint40 lastUpdateTime = uint40(vm.getBlockTimestamp());
    uint256 base = 100e18;
    uint256 rate = 0.1e27;

    skip((10 * MathUtils.SECONDS_PER_YEAR) / 10);

    uint256 interest = MathUtils.calculateLinearInterest(rate, lastUpdateTime);
    lastUpdateTime = uint40(vm.getBlockTimestamp());

    console.log('base %18e', base);
    console.log('rate %27e', rate);
    console.log('interest %27e', interest);
    base = base.rayMul(interest);
    console.log('total %18e', base);

    skip(MathUtils.SECONDS_PER_YEAR);
    console.log('\n=====================\n');

    interest = MathUtils.calculateLinearInterest(rate, lastUpdateTime);
    lastUpdateTime = uint40(vm.getBlockTimestamp());

    console.log('base %18e', base);
    console.log('rate %27e', rate);
    console.log('interest %27e', interest);
    base = base.rayMul(interest);
    console.log('total %18e', base);
  }

  function test_bye() public {
    Stater instance = new Stater();
    assertEq(instance.a(), 10);
    instance.set(20);
    assertEq(instance.a(), 20);

    address(instance).staticcall(abi.encodeWithSelector(Stater.set.selector, 30));

    assertEq(instance.a(), 20);
  }
}
contract Stater {
  uint public a = 10;
  function set(uint _a) public {
    a = _a;
  }
}
