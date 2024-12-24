import { Shares, Player } from './hardcore.mjs';
console.log('~0_0~');

const yes = new Shares('yes');
const no = new Shares('no');

const market = new Player('market', 0);
const seva = new Player('seva', 1e3);
const alice = new Player('alice', 1e3);
const bob = new Player('bob', 1e3);
const shovhal = new Player('shovhal', 1e3);

[seva, alice, bob, shovhal].forEach(chel => chel.debug());

seva.buy(yes, 100);
alice.buy(yes, 100);
seva.sell(yes, seva.shares.yes / 2);

bob.buy(no, 10);
shovhal.buy(no, 10);

bob.sell(no, bob.shares.no);
shovhal.sell(no, bob.shares.no);

//YES is the truth

market.cash = no.cash;
no.cash = 0;

//market.buy(yes, market.cash);

const prize = market.cash / yes.bought;

alice.cash += alice.shares.yes * prize;
console.log(alice.cash);
seva.cash += seva.shares.yes * prize;

alice.sell(yes, alice.shares.yes);
seva.sell(yes, seva.shares.yes);

bob.debug();

console.log('[*] Market:');
yes.debug();
no.debug();
