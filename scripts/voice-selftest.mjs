#!/usr/bin/env node
/**
 * Logic self-test gate mirroring Swift VoiceParser + CategoryMatcher + SeedData keywords.
 * Runs on Linux without Xcode. Keep in sync when changing Services/*.swift.
 */

function normalize(text) {
  let s = String(text).toLowerCase().replace(/ё/g, "е");
  s = [...s].map((ch) => (/[\p{L}\p{N}\s]/u.test(ch) ? ch : " ")).join("");
  return s.replace(/\s+/g, " ").trim();
}

/** Unicode-safe token edges (JS \\b breaks on Cyrillic). */
const WB = "(?<![0-9A-Za-zА-Яа-яЁё])";
const WA = "(?![0-9A-Za-zА-Яа-яЁё])";

const CATEGORIES = [
  {
    id: "food",
    nameRu: "Еда",
    nameEn: "Food",
    kind: "expense",
    keywords: [
      "еда", "food", "кофе", "coffee", "обед", "lunch", "ужин", "dinner",
      "завтрак", "breakfast", "ресторан", "restaurant", "кафе", "cafe",
      "продукт", "продукты", "grocery", "groceries", "пицца", "pizza",
      "бургер", "burger", "снек", "snack", "столовая", "супермаркет",
      "supermarket", "макдональдс", "mcdonalds",
    ],
  },
  {
    id: "transport",
    nameRu: "Транспорт",
    nameEn: "Transport",
    kind: "expense",
    keywords: [
      "транспорт", "transport", "такси", "taxi", "метро", "metro", "subway",
      "автобус", "bus", "бензин", "gas", "fuel", "топливо", "заправка",
      "азс", "azs", "gas station", "petrol", "diesel", "дизель",
      "uber", "яндекс", "yandex", "парковка", "parking", "поезд", "train",
      "трамвай", "tram", "самокат", "scooter", "каршеринг", "carshare",
    ],
  },
  {
    id: "entertainment",
    nameRu: "Развлечения",
    nameEn: "Entertainment",
    kind: "expense",
    keywords: [
      "развлечения", "entertainment", "кино", "кинотеатр", "cinema",
      "movie", "movies", "театр", "theater", "theatre", "игры", "games",
      "подписка", "subscription", "netflix", "spotify", "концерт",
      "concert", "клуб", "club", "бар", "bar", "bowling",
    ],
  },
  {
    id: "beauty",
    nameRu: "Красота",
    nameEn: "Beauty",
    kind: "expense",
    keywords: [
      "красота", "beauty", "косметика", "cosmetics", "макияж", "makeup",
      "помада", "lipstick", "крем", "cream", "шампунь", "shampoo",
      "маникюр", "manicure", "педикюр", "pedicure", "салон", "salon",
      "парикмахер", "hairdresser", "стрижка", "haircut", "парфюм",
      "perfume", "духи", "ногти", "nails", "spas", "spa",
    ],
  },
  {
    id: "salary",
    nameRu: "Зарплата",
    nameEn: "Salary",
    kind: "income",
    keywords: [
      "зарплата", "зарплату", "зарплаты", "зарплатой", "salary", "зп",
      "оклад", "wage", "paycheck", "аванс", "payroll",
    ],
  },
  {
    id: "other-expense",
    nameRu: "Другое",
    nameEn: "Other",
    kind: "expense",
    keywords: ["другое", "other", "разное", "misc"],
  },
];

const NOTE_SUPPRESS = new Set(
  [
    "еда", "food", "продукт", "продукты", "grocery", "groceries", "кофе",
    "coffee", "обед", "lunch", "ужин", "dinner", "завтрак", "breakfast",
    "пицца", "pizza", "бургер", "burger", "снек", "snack", "ресторан",
    "restaurant", "кафе", "cafe", "столовая", "супермаркет", "supermarket",
    "транспорт", "transport", "азс", "azs", "заправка", "бензин", "топливо",
    "gas", "fuel", "petrol", "diesel", "дизель", "gas station", "petrol station",
    "такси", "taxi", "метро", "metro", "subway", "автобус", "bus", "парковка",
    "parking", "station", "uber", "яндекс", "yandex", "поезд", "train",
    "развлечения", "entertainment",
    "косметика", "cosmetics", "красота", "beauty", "макияж", "makeup",
    "маникюр", "manicure", "салон", "salon",
    "зарплата", "зарплату", "зарплаты", "salary", "зп", "оклад", "wage",
    "рублей", "рубль", "рубля", "ruble", "rubles", "byn", "br",
    "dollar", "dollars", "usd", "eur", "euro",
    "на", "за", "для", "и", "получил", "получила", "потратил", "потратила",
    "got", "received", "spent", "paid",
  ].map(normalize)
);

const NOTE_COMMANDS = [
  new RegExp(`в\\s+скобочк(?:ах|и)\\s+напиши\\s*[,:\\-]?\\s*(.+)$`, "i"),
  new RegExp(`в\\s+скобках\\s+напиши\\s*[,:\\-]?\\s*(.+)$`, "i"),
  new RegExp(`в\\s+скобочк(?:ах|и)\\s*[,:\\-]?\\s*(.+)$`, "i"),
  new RegExp(`в\\s+скобках\\s*[,:\\-]?\\s*(.+)$`, "i"),
  new RegExp(`(?:заметка|комментарий|note|comment)\\s*[,:\\-]?\\s*(.+)$`, "i"),
  new RegExp(`напиши\\s*[,:\\-]?\\s*(.+)$`, "i"),
];

const INCOME_CUES = new RegExp(
  `${WB}(got|received|earned|salary|income|получил|получила|зарплат[аыуеой]|доход|заработал|заработала)${WA}`,
  "i"
);
const EXPENSE_CUES = new RegExp(
  `${WB}(spent|spend|paid|pay|bought|buy|потратил|потратила|потрачено|оплатил|оплатила|купил|купила|расход)${WA}`,
  "i"
);

function autoAssign(text, preferredType = null) {
  const normalized = normalize(text);
  if (!normalized) return null;
  let best = null;
  for (const category of CATEGORIES) {
    if (preferredType && category.kind !== "both" && category.kind !== preferredType) continue;
    let score = 0;
    for (const keyword of category.keywords) {
      const k = normalize(keyword);
      if (!k) continue;
      if (normalized.includes(k)) {
        score += Math.max(1.5, k.length / 2.5);
        continue;
      }
      const tokens = k.split(" ").filter((t) => t.length >= 2);
      if (tokens.length >= 2 && tokens.every((t) => normalized.includes(t))) {
        score += tokens.length;
      }
    }
    for (const name of [category.nameRu, category.nameEn]) {
      const n = normalize(name);
      if (n && normalized.includes(n)) score += Math.max(2, n.length / 2);
    }
    if (score > 0 && (!best || score > best.score)) best = { category, score };
  }
  return best?.category ?? null;
}

function parseAmount(text) {
  let cleaned = text.replace(/(\d)\s+(\d{3})\b/g, "$1$2").replace(/,/g, ".");
  const patterns = [
    /(\d+(?:\.\d{1,2})?)\s*(?:₽|руб(?:л(?:ей|я|ь)?)?|rubles?|dollars?|\$|usd|eur|€)/i,
    /(?:₽|руб(?:л(?:ей|я|ь)?)?|rubles?|dollars?|\$|usd|eur|€)\s*(\d+(?:\.\d{1,2})?)/i,
    /(\d+(?:\.\d{1,2})?)/,
  ];
  for (const re of patterns) {
    const m = cleaned.match(re);
    if (m) {
      const value = Number.parseFloat(m[1]);
      if (value > 0) return Math.round(value * 100) / 100;
    }
  }
  return null;
}

function inferType(text) {
  if (INCOME_CUES.test(text)) return "income";
  if (EXPENSE_CUES.test(text)) return "expense";
  return null;
}

function cleanNoteFragment(text) {
  let s = text.replace(/[«»""]/g, "");
  s = s.replace(/^[,.!;?:\-\s]+/, "").replace(/[,.\s]+$/, "");
  s = s.replace(/\s{2,}/g, " ").trim();
  return s;
}

function stripAmountsAndCurrency(text) {
  let working = text.replace(/\d[\d\s.,]*/g, " ");
  working = working.replace(
    new RegExp(`${WB}(руб(?:л(?:ей|я|ь|ями)?)?|rubles?|byn|br|dollars?|usd|eur|доллар(?:ов|а|ы)?|евро|₽|\\$|€)${WA}`, "gi"),
    " "
  );
  return working;
}

function stripKeyword(keyword, text) {
  const k = keyword.trim();
  if (!k) return text;
  const escaped = k.replace(/[.*+?^${}()|[\]\\]/g, "\\$&").replace(/\s+/g, "\\s+");
  const re = new RegExp(`${WB}${escaped}${WA}`, "gi");
  return text.replace(re, " ");
}

function finalizeNote(text, matched) {
  let s = stripAmountsAndCurrency(text);
  s = s.replace(INCOME_CUES, " ").replace(EXPENSE_CUES, " ");
  if (matched) {
    s = stripKeyword(matched.nameRu, s);
    s = stripKeyword(matched.nameEn, s);
    for (const keyword of [...matched.keywords].sort((a, b) => b.length - a.length)) {
      if (NOTE_SUPPRESS.has(normalize(keyword))) s = stripKeyword(keyword, s);
    }
  }
  s = s.replace(new RegExp(`${WB}(на|за|для|про|из|от|по|и|a|an|the|for|on|at|to|of)${WA}`, "gi"), " ");
  for (const token of [...NOTE_SUPPRESS].sort((a, b) => b.length - a.length)) {
    s = stripKeyword(token, s);
  }
  s = cleanNoteFragment(s);
  const normalized = normalize(s);
  if (!normalized) return "";
  if (NOTE_SUPPRESS.has(normalized)) return "";
  const tokens = normalized.split(" ");
  if (tokens.length && tokens.every((t) => NOTE_SUPPRESS.has(t))) return "";
  return s;
}

function noteFromCommand(text) {
  for (const re of NOTE_COMMANDS) {
    const m = text.match(re);
    if (m?.[1] && cleanNoteFragment(m[1])) return cleanNoteFragment(m[1]);
  }
  return null;
}

function splitTrailingDetail(text) {
  for (const sep of [",", " — ", " – ", " - "]) {
    const idx = text.lastIndexOf(sep);
    if (idx === -1) continue;
    const prefix = text.slice(0, idx).trim();
    const tail = text.slice(idx + sep.length).trim();
    if (prefix && tail) return { prefix, tail };
  }
  return null;
}

function extractNote(rawText, matched) {
  const commanded = noteFromCommand(rawText);
  if (commanded) return finalizeNote(commanded, matched);

  const split = splitTrailingDetail(rawText);
  if (split && matched) {
    const preferred = matched.kind === "income" ? "income" : "expense";
    const prefixMatch = autoAssign(split.prefix, preferred);
    if (prefixMatch?.id === matched.id) {
      return finalizeNote(split.tail, matched);
    }
  }

  let working = rawText;
  for (const re of NOTE_COMMANDS) working = working.replace(re, " ");
  working = stripAmountsAndCurrency(working);
  if (matched) {
    working = stripKeyword(matched.nameRu, working);
    working = stripKeyword(matched.nameEn, working);
  }
  for (const token of [...NOTE_SUPPRESS].sort((a, b) => b.length - a.length)) {
    working = stripKeyword(token, working);
  }
  return finalizeNote(working, matched);
}

function parse(rawText) {
  const amount = parseAmount(rawText);
  let type = inferType(rawText);
  let matched = autoAssign(rawText, type);
  // If type filter blocked income category, retry without filter
  if (!matched) matched = autoAssign(rawText, null);
  if (!type && matched) type = matched.kind === "income" ? "income" : "expense";
  if (!type) type = "expense";
  // Re-match with inferred type for consistency
  matched = autoAssign(rawText, type) ?? autoAssign(rawText, null);
  const categoryMatchedByKeyword = Boolean(matched);
  const categoryId =
    matched?.id ??
    CATEGORIES.find((c) => c.kind === type || c.kind === "both")?.id;
  const note = extractNote(rawText, matched);
  return {
    amount,
    type,
    categoryId,
    note,
    categoryMatchedByKeyword,
    isAutosaveReady: Boolean(amount && amount > 0 && categoryMatchedByKeyword && categoryId),
  };
}

function applyManualOverride(draft, newCategoryId) {
  return { ...draft, categoryId: newCategoryId, categoryMatchedByKeyword: false, manualOverride: true };
}

const cases = [
  {
    name: "1a RU entertainment + note command",
    input: "150 рублей развлечения, в скобочках напиши кинотеатр",
    expect: { amount: 150, categoryId: "entertainment", note: "кинотеатр", autosave: true },
  },
  {
    name: "1b RU entertainment + comma detail",
    input: "150 рублей развлечения, кинотеатр",
    expect: { amount: 150, categoryId: "entertainment", note: "кинотеатр", autosave: true },
  },
  {
    name: "2 EN food",
    input: "20 dollars food",
    expect: { amount: 20, categoryId: "food", note: "", autosave: true },
  },
  {
    name: "3 RU АЗС / заправка → transport",
    input: "200 рублей АЗС, заправка",
    expect: { amount: 200, categoryId: "transport", note: "", autosave: true },
  },
  {
    name: "4 EN gas station → transport",
    input: "200 dollars gas station",
    expect: { amount: 200, categoryId: "transport", note: "", autosave: true },
  },
  {
    name: "5 quick-entry autosave readiness",
    input: "450 на кофе",
    expect: { amount: 450, categoryId: "food", note: "", autosave: true },
  },
  {
    name: "6 manual override persists",
    input: "100 food",
    expect: { amount: 100, categoryId: "food", note: "", autosave: true },
    overrideTo: "entertainment",
  },
  {
    name: "edge empty speech",
    input: "",
    expect: { amount: null, autosave: false, note: "" },
  },
  {
    name: "edge missing amount",
    input: "кофе и такси",
    expect: { amount: null, autosave: false, categoryAnyOf: ["food", "transport"] },
  },
  {
    name: "edge income salary",
    input: "получил зарплату 80000",
    expect: { amount: 80000, categoryId: "salary", note: "", autosave: true, type: "income" },
  },
  {
    name: "7 RU beauty / косметика (руб → amount only)",
    input: "17 руб косметика",
    expect: { amount: 17, categoryId: "beauty", note: "", autosave: true },
  },
];

let failed = 0;
const results = [];

for (const c of cases) {
  let draft = parse(c.input);
  const bugs = [];

  if (Object.prototype.hasOwnProperty.call(c.expect, "amount")) {
    if (draft.amount !== c.expect.amount) bugs.push(`amount: got ${draft.amount} expected ${c.expect.amount}`);
  }
  if (c.expect.categoryId && draft.categoryId !== c.expect.categoryId) {
    bugs.push(`category: got ${draft.categoryId} expected ${c.expect.categoryId}`);
  }
  if (c.expect.categoryAnyOf && !c.expect.categoryAnyOf.includes(draft.categoryId)) {
    bugs.push(`category: got ${draft.categoryId} expected one of ${c.expect.categoryAnyOf}`);
  }
  if (c.expect.type && draft.type !== c.expect.type) {
    bugs.push(`type: got ${draft.type} expected ${c.expect.type}`);
  }
  if (c.expect.note !== undefined && normalize(draft.note) !== normalize(c.expect.note)) {
    bugs.push(`note: got «${draft.note}» expected «${c.expect.note}»`);
  }
  for (const filler of ["рублей", "dollars", "развлечения", "точка"]) {
    if (
      normalize(draft.note).includes(normalize(filler)) &&
      normalize(c.expect.note ?? "") !== normalize(filler)
    ) {
      bugs.push(`note contains filler «${filler}»`);
    }
  }
  if (c.expect.autosave !== undefined && draft.isAutosaveReady !== c.expect.autosave) {
    bugs.push(`autosave: got ${draft.isAutosaveReady} expected ${c.expect.autosave}`);
  }

  if (c.overrideTo) {
    draft = applyManualOverride(draft, c.overrideTo);
    if (draft.categoryId !== c.overrideTo || !draft.manualOverride) {
      bugs.push(`override: category not persisted as ${c.overrideTo}`);
    }
  }

  const ok = bugs.length === 0;
  if (!ok) failed += 1;
  results.push({ name: c.name, ok, draft, bugs });
  console.log(`${ok ? "PASS" : "FAIL"}  ${c.name}`);
  if (!ok) {
    console.log(`      input: ${JSON.stringify(c.input)}`);
    console.log(`      draft: ${JSON.stringify(draft)}`);
    for (const b of bugs) console.log(`      - ${b}`);
  }
}

console.log("\n---");
console.log(`Total: ${results.length}, passed: ${results.length - failed}, failed: ${failed}`);
if (failed > 0) {
  process.exit(1);
}
console.log("Self-test gate PASSED (logic).");
console.log("BLOCKER: No Xcode/Simulator on this Linux VM — device UI scenarios not executed.");
process.exit(0);
