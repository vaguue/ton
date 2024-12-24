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

export class Shares {
  constructor(name) {
    this.name = name;
    this.R = 1e18;
    this.T = 1e18;

    this.cash = 0;
  }

  buy(x) {
    const { T, R } = this;

    const b = (T - R) / 1e15;
    const root = ((PROPORTION * x) / 1e9 + b*b)**0.5;
    let out = (root - b) * 1e15;

    out = Math.sqrt(out);

    this.R -= out;
    this.cash += x;

    return out;
  }

  sell(x) {
    const { T, R } = this;

    const b = (T - R) / 1e15;
    if ((T - R) < x) {
      x = T - R;
      //throw new Error('0_o');
    }

    const r = (T - R - x) / 1e15;
    let out = (b * b - r * r) / PROPORTION * 1e9;

    out = Math.sqrt(out);

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
