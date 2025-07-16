pragma solidity ^0.8.0;

import {Test} from 'forge-std/Test.sol';

contract A {
  event log(string message);
  modifier onlyA() {
    emit log('onlyA');
    _;
  }

  function hello() public virtual onlyA {
    emit log('helloA');
  }
}

contract B is A {
  modifier onlyB() {
    emit log('onlyB');
    _;
  }

  function hello() public override onlyB {
    emit log('helloB');
    super.hello();
  }
}

contract HelloTest is Test {
  function test_hello() public {
    B b = new B();
    b.hello();
  }
}
