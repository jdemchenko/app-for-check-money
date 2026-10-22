/**
 * Mirrors CSVImport column detection (CheckMoney export + CoinKeeper-like).
 */
function detectDelimiter(line) {
  const semis = (line.match(/;/g) || []).length;
  const commas = (line.match(/,/g) || []).length;
  const tabs = (line.match(/\t/g) || []).length;
  if (semis >= commas && semis >= tabs && semis > 0) return ";";
  if (tabs > commas && tabs > semis) return "\t";
  return ",";
}

function splitCSVLine(line, delimiter) {
  const result = [];
  let current = "";
  let inQuotes = false;
  for (const ch of line) {
    if (ch === '"') {
      inQuotes = !inQuotes;
      continue;
    }
    if (ch === delimiter && !inQuotes) {
      result.push(current);
      current = "";
      continue;
    }
    current += ch;
  }
  result.push(current);
  return result.map((s) => s.trim());
}

function parseAmount(raw) {
  let s = String(raw).replace(/\s|\u00a0/g, "");
  if (s.includes(",") && s.includes(".")) {
    s = s.replace(/\./g, "").replace(",", ".");
  } else {
    s = s.replace(",", ".");
  }
  s = s.replace(/[^\d.\-]/g, "");
  const n = Number(s);
  return Number.isFinite(n) ? n : null;
}

function hasHeader(cells) {
  const h = cells.map((c) => c.toLowerCase());
  return h.some((x) =>
    ["date", "дата", "amount", "сумма", "category", "категория", "type", "тип"].some((k) =>
      x.includes(k)
    )
  );
}

function parse(text) {
  const raw = text.replace(/^\uFEFF/, "");
  const lines = raw
    .split(/\r?\n/)
    .map((l) => l.trim())
    .filter(Boolean);
  if (!lines.length) throw new Error("empty");
  const delim = detectDelimiter(lines[0]);
  const header = splitCSVLine(lines[0], delim);
  const headed = hasHeader(header);
  const data = headed ? lines.slice(1) : lines;
  const map = headed
    ? {
        date: header.findIndex((h) => /date|дата/i.test(h)),
        type: header.findIndex((h) => /type|тип/i.test(h)),
        amount: header.findIndex((h) => /amount|сумма/i.test(h)),
        currency: header.findIndex((h) => /currency|валюта/i.test(h)),
        category: header.findIndex((h) => /category|категория/i.test(h)),
        note: header.findIndex((h) => /note|описание|comment/i.test(h)),
      }
    : { date: 0, type: 1, amount: 2, currency: 3, category: 4, note: 6 };
  const rows = [];
  for (const line of data) {
    const cells = splitCSVLine(line, delim);
    const amount = parseAmount(cells[map.amount] ?? "");
    if (amount == null || amount === 0) continue;
    rows.push({
      amount: Math.abs(amount),
      category: cells[map.category] || "",
      currency: (cells[map.currency] || "BYN").toUpperCase(),
    });
  }
  if (!rows.length) throw new Error("noRows");
  return rows;
}

const exportSample = `date,type,amount,currency,category,payment,note,id
2026-10-01,expense,12.50,BYN,Food,cash,"coffee",abc
2026-10-02,income,1000,BYN,Salary,,payroll,def`;

const coinKeeper = `Дата;Категория;Сумма;Валюта;Описание
01.10.2026;Еда;15,5;BYN;кофе
02.10.2026;Транспорт;8;BYN;такси`;

let failed = 0;
function check(name, fn) {
  try {
    fn();
    console.log(`PASS  ${name}`);
  } catch (e) {
    failed += 1;
    console.log(`FAIL  ${name}: ${e.message || e}`);
  }
}

check("CheckMoney export", () => {
  const rows = parse(exportSample);
  if (rows.length !== 2) throw new Error(`count ${rows.length}`);
  if (rows[0].amount !== 12.5) throw new Error("amount0");
  if (rows[0].category !== "Food") throw new Error("cat0");
});

check("CoinKeeper-like semicolon", () => {
  const rows = parse(coinKeeper);
  if (rows.length !== 2) throw new Error(`count ${rows.length}`);
  if (rows[0].amount !== 15.5) throw new Error("amount0");
  if (rows[1].amount !== 8) throw new Error("amount1");
});

console.log("---");
if (failed) process.exit(1);
console.log("CSV import self-test PASSED");
process.exit(0);
