#!/usr/bin/env node
/**
 * Mirrors KeywordSuggester + SeedData.synonymBanks for Linux self-test.
 * Keep CATEGORIES in sync with AppForCheckMoney/Models/SeedData.swift.
 */

function normalize(text) {
  let s = String(text).toLowerCase().replace(/ё/g, "е");
  s = [...s].map((ch) => (/[\p{L}\p{N}\s]/u.test(ch) ? ch : " ")).join("");
  return s.replace(/\s+/g, " ").trim();
}

function stem(token) {
  let t = normalize(token);
  if (t.length < 4) return t;
  const endings = [
    "иями", "ями", "ами", "ией", "иею", "ою", "ею",
    "ого", "ему", "ому", "ыми", "ими",
    "ой", "ей", "ом", "ем", "ам", "ям", "ах", "ях", "ых", "их",
    "ую", "юю", "ая", "яя", "ое", "ее", "ые", "ие",
    "ов", "ев", "ин", "ын", "ий", "ый", "ть",
    "ing", "tion", "ments", "ment", "ness", "ies", "ers",
    "ed", "es", "ly", "er", "s",
    "а", "я", "у", "ю", "ы", "и", "е", "о", "ь",
  ];
  for (const ending of endings) {
    if (t.endsWith(ending) && t.length - ending.length >= 3) {
      t = t.slice(0, -ending.length);
      break;
    }
  }
  return t;
}

const CATEGORIES = [
  {
    id: "food",
    nameRu: "Еда",
    nameEn: "Food",
    kind: "expense",
    symbolName: "fork.knife",
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
    symbolName: "car.fill",
    keywords: [
      "транспорт", "transport", "такси", "taxi", "метро", "metro", "subway",
      "автобус", "bus", "бензин", "gas", "fuel", "топливо", "заправка",
      "азс", "azs", "gas station", "petrol", "diesel", "дизель",
      "uber", "яндекс", "yandex", "парковка", "parking", "поезд", "train",
      "трамвай", "tram", "самокат", "scooter", "каршеринг", "carshare",
    ],
  },
  {
    id: "housing",
    nameRu: "Жильё",
    nameEn: "Housing",
    kind: "expense",
    symbolName: "house.fill",
    keywords: [
      "жильё", "жилье", "housing", "аренда", "rent", "квартира",
      "apartment", "коммуналка", "utilities", "свет", "electricity",
      "вода", "water", "ипотека", "mortgage", "жкх", "газ",
    ],
  },
  {
    id: "shopping",
    nameRu: "Покупки",
    nameEn: "Shopping",
    kind: "expense",
    symbolName: "bag.fill",
    keywords: [
      "покупки", "shopping", "одежда", "clothes", "магазин", "shop",
      "store", "amazon", "ozon", "wildberries", "wb", "маркет",
      "одежда", "shoes", "обувь",
    ],
  },
  {
    id: "health",
    nameRu: "Здоровье",
    nameEn: "Health",
    kind: "expense",
    symbolName: "heart.fill",
    keywords: [
      "здоровье", "health", "аптека", "pharmacy", "врач", "doctor",
      "медицина", "medicine", "спорт", "gym", "фитнес", "fitness",
      "таблетки", "больница", "hospital", "стоматолог", "dentist",
    ],
  },
  {
    id: "entertainment",
    nameRu: "Развлечения",
    nameEn: "Entertainment",
    kind: "expense",
    symbolName: "film.fill",
    keywords: [
      "развлечения", "entertainment", "кино", "кинотеатр", "cinema",
      "movie", "movies", "театр", "theater", "theatre", "игры", "games",
      "подписка", "subscription", "netflix", "spotify", "концерт",
      "concert", "клуб", "club", "бар", "bar", "bowling",
    ],
  },
  {
    id: "other-expense",
    nameRu: "Другое",
    nameEn: "Other",
    kind: "expense",
    symbolName: "circle.fill",
    keywords: ["другое", "other", "разное", "misc"],
  },
  {
    id: "salary",
    nameRu: "Зарплата",
    nameEn: "Salary",
    kind: "income",
    symbolName: "briefcase.fill",
    keywords: [
      "зарплата", "зарплату", "зарплаты", "зарплатой", "salary", "зп",
      "оклад", "wage", "paycheck", "аванс", "payroll",
    ],
  },
  {
    id: "freelance",
    nameRu: "Фриланс",
    nameEn: "Freelance",
    kind: "income",
    symbolName: "laptopcomputer",
    keywords: [
      "фриланс", "freelance", "проект", "project", "клиент", "client",
      "заказ", "contract",
    ],
  },
  {
    id: "gifts",
    nameRu: "Подарки",
    nameEn: "Gifts",
    kind: "both",
    symbolName: "gift.fill",
    keywords: [
      "подарок", "gift", "подарки", "gifts", "день рождения", "birthday",
    ],
  },
  {
    id: "other-income",
    nameRu: "Прочий доход",
    nameEn: "Other income",
    kind: "income",
    symbolName: "creditcard.fill",
    keywords: [
      "доход", "income", "перевод", "transfer", "возврат", "refund",
    ],
  },
];

const FAMILY_THRESHOLD = 4;

function tokenOverlapScore(a, b) {
  const ta = new Set(
    a.split(" ").map(stem).filter((t) => t.length >= 2)
  );
  const tb = new Set(
    b.split(" ").map(stem).filter((t) => t.length >= 2)
  );
  let shared = 0;
  for (const t of ta) if (tb.has(t)) shared += 1;
  return shared * 2.5;
}

function prefixSimilarity(a, b) {
  const n = Math.min(a.length, b.length);
  if (!n) return 0;
  let common = 0;
  for (let i = 0; i < n; i += 1) {
    if (a[i] === b[i]) common += 1;
    else break;
  }
  return common / Math.max(a.length, b.length);
}

function kindAffinity(bankKind, preferred) {
  if (bankKind === preferred || bankKind === "both" || preferred === "both") return 1.5;
  return -2;
}

function scoreBank(bank, queries, symbol) {
  let score = 0;
  const bankNames = [bank.nameRu, bank.nameEn].map(normalize);
  const bankStems = new Set(bankNames.map(stem));
  const keywordNorms = bank.keywords.map(normalize).filter(Boolean);
  const keywordStems = new Set(keywordNorms.map(stem));

  for (const q of queries) {
    const qStem = stem(q);
    for (const bn of bankNames) {
      if (q === bn) score += 12;
      else if (q.includes(bn) || bn.includes(q)) score += 7;
      else {
        const ov = tokenOverlapScore(q, bn);
        if (ov > 0) score += ov;
        else if (prefixSimilarity(q, bn) >= 0.7 && Math.min(q.length, bn.length) >= 4) score += 4;
      }
    }
    if (bankStems.has(qStem) && qStem.length >= 3) score += 5;

    for (const kw of keywordNorms) {
      if (q === kw) score += 9;
      else if ((q.includes(kw) || kw.includes(q)) && Math.min(q.length, kw.length) >= 3) score += 4;
      else if (keywordStems.has(qStem) && qStem.length >= 3 && stem(kw) === qStem) score += 3.5;
      else if (tokenOverlapScore(q, kw) >= 3) score += 3;
    }

    for (const token of q.split(" ").filter((t) => t.length >= 3)) {
      const tStem = stem(token);
      if (bankNames.includes(token) || keywordNorms.includes(token)) score += 5;
      else if (bankStems.has(tStem) || keywordStems.has(tStem)) score += 3.5;
      else if (keywordNorms.some((k) => k.includes(token) || token.includes(k))) score += 2.5;
    }
  }

  if (symbol && symbol === bank.symbolName) score += 5;
  return score;
}

function bestFamily(nameRu, nameEn, symbolName, kind) {
  const queries = [nameRu, nameEn].map(normalize).filter(Boolean);
  if (!queries.length) return null;
  let best = null;
  for (const bank of CATEGORIES) {
    let score = scoreBank(bank, queries, symbolName || "");
    if (kind) score += kindAffinity(bank.kind, kind);
    if (score > FAMILY_THRESHOLD && (!best || score > best.score)) {
      best = { bank, score };
    }
  }
  return best?.bank ?? null;
}

function derivedFromNames(ru, en) {
  const out = [];
  for (const raw of [ru, en].filter(Boolean)) {
    const norm = normalize(raw);
    if (norm) out.push(norm);
    const lower = raw.toLowerCase().trim();
    if (lower && lower !== norm) out.push(lower);
    for (const token of norm.split(" ").filter((t) => t.length >= 2)) {
      out.push(token);
      const s = stem(token);
      if (s !== token && s.length >= 3) out.push(s);
    }
  }
  return out;
}

function nearbySynonyms(names) {
  const tokens = new Set(
    names
      .flatMap((n) => normalize(n).split(" "))
      .filter((t) => t.length >= 3)
      .flatMap((t) => [t, stem(t)])
  );
  if (!tokens.size) return [];
  const hits = [];
  for (const bank of CATEGORIES) {
    for (const keyword of bank.keywords) {
      const kn = normalize(keyword);
      const ks = stem(kn);
      let hit = false;
      for (const t of tokens) {
        if (t === kn || t === ks || kn.includes(t) || t.includes(kn) || stem(t) === ks) {
          hit = true;
          break;
        }
      }
      if (hit) hits.push(keyword);
    }
  }
  return hits;
}

function dedupe(items) {
  const seen = new Set();
  const out = [];
  for (const item of items) {
    const trimmed = String(item).trim();
    if (!trimmed) continue;
    const key = normalize(trimmed);
    if (!key || seen.has(key)) continue;
    seen.add(key);
    out.push(trimmed);
  }
  return out;
}

function suggest({ nameRu = "", nameEn = "", symbolName = "", kind = null } = {}) {
  const ru = nameRu.trim();
  const en = nameEn.trim();
  if (!ru && !en) return [];
  let result = derivedFromNames(ru, en);
  const family = bestFamily(ru, en, symbolName, kind);
  if (family) result = result.concat(family.keywords);
  else result = result.concat(nearbySynonyms([ru, en]));
  return dedupe(result);
}

function hasAny(list, needles) {
  const norms = list.map(normalize);
  return needles.every((n) => norms.some((x) => x === normalize(n) || x.includes(normalize(n))));
}

const cases = [
  {
    name: "food exact RU",
    input: { nameRu: "Еда" },
    expectFamilyMarkers: ["кофе", "обед", "restaurant"],
  },
  {
    name: "transport via keyword token",
    input: { nameRu: "Такси и метро" },
    expectFamilyMarkers: ["taxi", "uber", "бензин"],
  },
  {
    name: "salary declined form",
    input: { nameRu: "Зарплату", kind: "income" },
    expectFamilyMarkers: ["зп", "оклад", "salary"],
  },
  {
    name: "entertainment EN",
    input: { nameRu: "Кино", nameEn: "Movies" },
    expectFamilyMarkers: ["netflix", "cinema", "подписка"],
  },
  {
    name: "symbol boost food",
    input: { nameRu: "Кафе", symbolName: "fork.knife" },
    expectFamilyMarkers: ["coffee", "lunch"],
  },
  {
    name: "custom unknown derives tokens",
    input: { nameRu: "Питомцы" },
    expectIncludes: ["питомцы", "питомц"],
    expectNotFamily: true,
  },
  {
    name: "housing ё→е",
    input: { nameRu: "Жилье" },
    expectFamilyMarkers: ["аренда", "жкх"],
  },
];

let failed = 0;
for (const c of cases) {
  const keywords = suggest(c.input);
  const bugs = [];
  if (c.expectFamilyMarkers && !hasAny(keywords, c.expectFamilyMarkers)) {
    bugs.push(`missing family markers ${c.expectFamilyMarkers.join(", ")}; got ${keywords.slice(0, 12).join(", ")}`);
  }
  if (c.expectIncludes && !hasAny(keywords, c.expectIncludes)) {
    bugs.push(`missing derived ${c.expectIncludes.join(", ")}; got ${keywords.join(", ")}`);
  }
  if (c.expectNotFamily) {
    const foodish = hasAny(keywords, ["mcdonalds", "uber", "netflix", "payroll"]);
    if (foodish) bugs.push("unexpected full default-family spill for custom name");
  }
  if (!keywords.length) bugs.push("empty suggestion");
  const ok = bugs.length === 0;
  if (!ok) failed += 1;
  console.log(`${ok ? "PASS" : "FAIL"}  ${c.name}`);
  if (!ok) {
    console.log(`      input: ${JSON.stringify(c.input)}`);
    console.log(`      keywords: ${keywords.join(", ")}`);
    for (const b of bugs) console.log(`      - ${b}`);
  }
}

console.log("\n---");
console.log(`Total: ${cases.length}, failed: ${failed}`);
if (failed > 0) process.exit(1);
console.log("Keyword-suggest self-test PASSED.");
process.exit(0);
