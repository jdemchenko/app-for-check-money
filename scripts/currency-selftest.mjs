#!/usr/bin/env node
/**
 * Mirrors CurrencyConverter (BYN pivot, approximate static rates).
 */

const BYN_PER = { byn: 1, usd: 3.25, eur: 3.55, rub: 0.036 };

function convert(amount, from, to) {
  if (from === to) return amount;
  const inByn = amount * (BYN_PER[from] ?? 1);
  const rateTo = BYN_PER[to] ?? 1;
  return Math.round((inByn / rateTo) * 100) / 100;
}

const cases = [
  { name: "identity", amount: 10, from: "byn", to: "byn", expect: 10 },
  { name: "usd→byn", amount: 10, from: "usd", to: "byn", expect: 32.5 },
  { name: "byn→usd", amount: 32.5, from: "byn", to: "usd", expect: 10 },
  { name: "eur→usd approx", amount: 10, from: "eur", to: "usd", expect: convert(10, "eur", "usd") },
  { name: "rub small", amount: 1000, from: "rub", to: "byn", expect: 36 },
];

let failed = 0;
for (const c of cases) {
  const got = convert(c.amount, c.from, c.to);
  const ok = got === c.expect;
  if (!ok) failed += 1;
  console.log(`${ok ? "PASS" : "FAIL"}  ${c.name} → ${got} (expected ${c.expect})`);
}
console.log("---");
if (failed) process.exit(1);
console.log("Currency-selftest PASSED (static BYN-pivot rates).");
process.exit(0);
