import {skip} from './core';
import {f, MAX_UINT, p, it, runScenarios, randomAmount} from './utils';

it()((ctx) => {
  const [alice, bob, charlie] = ctx.users;
  const amount1 = p('10000');
  const amount2 = p('200');
  const amount3 = p('500');

  alice.supply(amount1);
  alice.borrow(amount1);
  skip();
  alice.repay(amount2);
  bob.borrow(amount2);
  skip();
  alice.repay(amount3);
  charlie.borrow(amount3);
  alice.repay(amount3);
  skip();
  charlie.borrow(amount3);
  skip();
  alice.repay(MAX_UINT);
  skip();
  charlie.repay(MAX_UINT);
  skip();
  bob.repay(MAX_UINT);
  skip();
  alice.withdraw(amount2);
  skip();
  alice.withdraw(alice.getSuppliedBalance());

  alice.log(true, true);
});

it()((ctx) => {
  const [alice] = ctx.users;
  const amount = p(1000);

  alice.supply(amount);
  alice.borrow(amount);

  alice.log(true, true);

  alice.repay(amount);
  alice.log(true, true);

  alice.repay(MAX_UINT);
});

it()((ctx) => {
  const [alice, bob, charlie] = ctx.users;

  const amount1 = p('1000');
  alice.supply(amount1);
  alice.borrow(amount1);

  skip();

  alice.log(true, true);
  alice.repay(MAX_UINT);
  alice.log(true, true);

  const amount2 = p('1000');
  bob.borrow(amount2);
  skip();

  bob.repay(MAX_UINT);

  skip();
  const amount4 = p('700');
  charlie.borrow(amount4);

  skip();
  charlie.repay(amount4);
  charlie.log(true, true);

  skip();
  // charlie.log(true, true);
  charlie.repay(MAX_UINT);
  // charlie.log(true, true);
});

it()((ctx) => {
  const [alice, bob, charlie] = ctx.users;

  const amount1 = p('10000');
  const amount2 = p('200');
  const amount3 = p('500');

  alice.supply(amount1);
  alice.borrow(amount1);

  skip();
  alice.repay(amount2);
  bob.borrow(amount2);

  alice.updateRiskPremium();

  skip();
  alice.repay(amount3);
  charlie.borrow(amount3);
  alice.repay(amount3);

  skip();
  charlie.borrow(amount3);

  skip();
  alice.repay(MAX_UINT);

  skip();
  charlie.repay(MAX_UINT);

  skip();
  bob.repay(MAX_UINT);
});

it()((ctx) => {
  const [alice, bob, charlie] = ctx.users;

  const amount1 = p('10000');
  const amount2 = p('200');
  const amount3 = p('500');

  alice.supply(amount1);

  skip();
  bob.borrow(amount2);
  bob.supply(amount3);

  skip();
  charlie.supply(amount3);
  charlie.borrow(amount2);

  skip();
  charlie.repay(MAX_UINT);
  bob.repay(MAX_UINT);

  skip();
  charlie.withdraw(MAX_UINT);
  bob.withdraw(MAX_UINT);
  alice.withdraw(MAX_UINT);

  alice.supply(amount1);

  skip();
  bob.borrow(amount2);
  bob.supply(amount3);

  skip();
  charlie.supply(amount3);
  charlie.borrow(amount2);

  skip();
  charlie.repay(MAX_UINT);
  bob.repay(MAX_UINT);

  skip();
  charlie.withdraw(MAX_UINT);
  bob.withdraw(MAX_UINT);
  alice.withdraw(MAX_UINT);
});

it('6 supply yields -1 bc of index')((ctx) => {
  const [alice, bob] = ctx.users;
  const amount = p(100);
  const amount2 = p(500);

  bob.supply(amount2);
  // skip();
  bob.withdraw(amount2 / 2n);
  // skip();
  bob.borrow(amount2 / 2n);

  alice.supply(amount);
  // skip();
  console.log('alice supplied amount', f(alice.getSuppliedBalance()), f(amount));
  alice.withdraw(amount);
});

runScenarios();
