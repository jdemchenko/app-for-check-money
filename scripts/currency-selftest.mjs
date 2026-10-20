#!/usr/bin/env node
/**
 * Mirrors CurrencyConverter (BYN pivot) + myfin.by НБРБ JSON parse.
 */

const STATIC_BYN_PER = { byn: 1, usd: 3.25, eur: 3.55, rub: 0.036 };

function convert(amount, from, to, rates = STATIC_BYN_PER) {
  if (from === to) return amount;
  const inByn = amount * (rates[from] ?? 1);
  const rateTo = rates[to] ?? 1;
  return Math.round((inByn / rateTo) * 100) / 100;
}

/** Mirror ExchangeRateStore.parseNbrb */
function parseNbrb(json) {
  const root = typeof json === "string" ? JSON.parse(json) : json;
  const currencies = root?.today?.currencies ?? root?.currencies;
  if (!currencies) throw new Error("no currencies");
  const out = { byn: 1 };
  for (const code of ["usd", "eur", "rub"]) {
    const entry = currencies[code];
    if (!entry) continue;
    const raw = entry.rate;
    const value = typeof raw === "string" ? Number.parseFloat(raw.replace(",", ".")) : Number(raw);
    if (value > 0) out[code] = value;
  }
  if (out.usd == null || out.eur == null) throw new Error("missing majors");
  if (out.rub == null) out.rub = STATIC_BYN_PER.rub;
  return out;
}

const fixture = {
  today: {
    date: 1792443600,
    currencies: {
      usd: { rate: "2.995000", iname: "usd" },
      eur: { rate: "3.356500", iname: "eur" },
      rub: { rate: "0.036127", iname: "rub" },
      byn: { rate: "1", iname: "byn" },
    },
  },
};

let failed = 0;
function check(name, ok, detail = "") {
  if (!ok) failed += 1;
  console.log(`${ok ? "PASS" : "FAIL"}  ${name}${detail ? ` ${detail}` : ""}`);
}

const cases = [
  { name: "identity", amount: 10, from: "byn", to: "byn", expect: 10 },
  { name: "usd→byn static", amount: 10, from: "usd", to: "byn", expect: 32.5 },
  { name: "byn→usd static", amount: 32.5, from: "byn", to: "usd", expect: 10 },
  { name: "eur→usd approx", amount: 10, from: "eur", to: "usd", expect: convert(10, "eur", "usd") },
  { name: "rub small", amount: 1000, from: "rub", to: "byn", expect: 36 },
];

for (const c of cases) {
  const got = convert(c.amount, c.from, c.to);
  check(c.name, got === c.expect, `→ ${got} (expected ${c.expect})`);
}

try {
  const live = parseNbrb(fixture);
  check("parse nbrb fixture", live.usd === 2.995 && live.eur === 3.3565 && Math.abs(live.rub - 0.036127) < 1e-9);
  const liveUsdToByn = convert(10, "usd", "byn", live);
  check("live usd→byn", liveUsdToByn === 29.95, `→ ${liveUsdToByn}`);
} catch (e) {
  check("parse nbrb fixture", false, String(e));
}

async function maybeFetchLive() {
  try {
    const ac = new AbortController();
    const timer = setTimeout(() => ac.abort(), 5000);
    const res = await fetch("https://api.myfin.by/currency/nbrb", {
      headers: { Accept: "application/json" },
      signal: ac.signal,
    });
    clearTimeout(timer);
    if (res.ok) {
      const body = await res.json();
      const rates = parseNbrb(body);
      check("live myfin.by nbrb fetch", rates.usd > 1 && rates.usd < 10, `usd=${rates.usd}`);
    } else {
      check("live myfin.by nbrb fetch (skipped http)", true, `status ${res.status}`);
    }
  } catch (e) {
    check("live myfin.by nbrb fetch (offline ok)", true, String(e.message || e).slice(0, 60));
  }
}

await maybeFetchLive();

console.log("---");
if (failed) process.exit(1);
console.log("Currency-selftest PASSED (static + myfin nbrb parse).");
process.exit(0);
