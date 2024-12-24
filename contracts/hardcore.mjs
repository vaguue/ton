const PROPORTION = 1280;

export class Player {
  constructor(name, cash) {
    this.name = name;
    this.cash = cash;
    this.shares = {};
  }

  buy(pool, x) {
    const { name } = pool;
    const res = pool.buy(x);

    this.shares[name] = (this.shares[name] ?? 0) + res;
    this.cash -= x;

    this.debug();
  }

  sell(pool, x) {
    const { name } = pool;
    const res = pool.sell(x);

    this.shares[name] = (this.shares[name] ?? 0) - x;
    this.cash += res;

    this.debug();
  }

  debug() {
    console.log('[*]', this.name, 'has', this.cash, 'cash and', JSON.stringify(this.shares), 'shares');
  }
}

const A = 1e3;
const S = 1;
//let L = A + A + S;
let L = S;

export class Shares {
  constructor(name) {
    this.name = name;
    this.R = A;
    this.T = A;

    this.cash = 0;
  }

  buy(x) {
    const { T, R } = this;

    const N = (T - R);
    const p = (2 + N - L) / 2;

    const out = x / p;
    console.log({ out, p });

    L = L + x;

    this.R -= out;
    this.cash += x;

    return out;
  }

  sell(x) {
    const { T, R } = this;

    const N = (T - R);
    const p = (L - N) / 2;

    const out = x / p;
    console.log({ out, p });

    L = L - x;

    this.R += x;
    this.cash -= out;

    return out;
  }

  get bought() {
    return this.T - this.R;
  }

  debug() {
    console.log('[*]', this.name, 'has', this.cash, 'cash and', this.R, 'shares');
  }
}
