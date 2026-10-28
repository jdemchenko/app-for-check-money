#!/usr/bin/env node
/**
 * Pure-logic gate for AccountLedger / debt settle / goal progress.
 * Mirrors AppForCheckMoney/Services/AccountLedger.swift (static BYN rates).
 */

const RATES = { byn: 1, usd: 3.25, eur: 3.55, rub: 0.036 };

function convert(amount, from, to) {
  if (from === to) return amount;
  const byn = amount * (RATES[from] ?? 1);
  return byn / (RATES[to] ?? 1);
}

function round2(n) {
  return Math.round(n * 100) / 100;
}

function balance(account, txs) {
  const mine = txs.filter((tx) => {
    if (tx.accountId) return tx.accountId === account.id;
    return account.id === "account-cash-byn";
  });
  const signed = mine.reduce(
    (s, tx) => s + convert(tx.signed, tx.currency, account.currency),
    0
  );
  return round2(account.opening + signed);
}

function totals(accounts, txs, display) {
  const lines = accounts
    .filter((a) => !a.archived)
    .map((a) => {
      const native = balance(a, txs);
      return {
        id: a.id,
        native,
        display: round2(convert(native, a.currency, display)),
      };
    });
  return {
    lines,
    total: round2(lines.reduce((s, l) => s + l.display, 0)),
  };
}

function goalProgress(goal, accounts, txs) {
  const account = accounts.find((a) => a.id === goal.accountId);
  if (!account) return { current: 0, ratio: 0 };
  let current = balance(account, txs);
  if (account.currency !== goal.currency) {
    current = convert(current, account.currency, goal.currency);
  }
  current = round2(current);
  const ratio = goal.target > 0 ? Math.min(1, Math.max(0, current / goal.target)) : 0;
  return { current, ratio };
}

let failed = 0;
function check(name, cond, detail = "") {
  if (!cond) {
    failed += 1;
    console.log(`FAIL  ${name}${detail ? " — " + detail : ""}`);
  } else {
    console.log(`PASS  ${name}`);
  }
}

const cash = {
  id: "account-cash-byn",
  currency: "byn",
  opening: 100,
  archived: false,
};
const usdCard = {
  id: "account-usd",
  currency: "usd",
  opening: 50,
  archived: false,
};

const txs = [
  { accountId: "account-cash-byn", currency: "byn", signed: -15 },
  { accountId: "account-cash-byn", currency: "byn", signed: 40 },
  { accountId: "", currency: "byn", signed: -10 }, // legacy → cash
  { accountId: "account-usd", currency: "usd", signed: -5 },
];

const cashBal = balance(cash, txs);
check("cash balance opening+txs", cashBal === 115, `got ${cashBal}`);

const usdBal = balance(usdCard, txs);
check("usd card balance", usdBal === 45, `got ${usdBal}`);

const tot = totals([cash, usdCard], txs, "byn");
const expectedUsdInByn = round2(45 * 3.25);
check(
  "FX total BYN",
  tot.total === round2(115 + expectedUsdInByn),
  `got ${tot.total} expected ${round2(115 + expectedUsdInByn)}`
);

const goal = { accountId: "account-cash-byn", currency: "byn", target: 230 };
const prog = goalProgress(goal, [cash, usdCard], txs);
check("goal progress 0.5", Math.abs(prog.ratio - 0.5) < 0.001, `got ${prog.ratio}`);

// Debt settle (model-level)
function settle(debt, at = Date.now()) {
  return { ...debt, settledAt: at };
}
const debt = { person: "Ivan", amount: 20, settledAt: null };
const settled = settle(debt);
check("debt settle stamps date", Boolean(settled.settledAt));

console.log("---");
console.log(`failed: ${failed}`);
process.exit(failed ? 1 : 0);
