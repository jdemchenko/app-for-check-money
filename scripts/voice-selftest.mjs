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

const ONES = {
  ноль: 0, один: 1, одна: 1, два: 2, две: 2, три: 3, четыре: 4,
  пять: 5, шесть: 6, семь: 7, восемь: 8, девять: 9,
  десять: 10, одиннадцать: 11, двенадцать: 12, тринадцать: 13,
  четырнадцать: 14, пятнадцать: 15, шестнадцать: 16, семнадцать: 17,
  восемнадцать: 18, девятнадцать: 19,
  zero: 0, one: 1, two: 2, three: 3, four: 4, five: 5,
  six: 6, seven: 7, eight: 8, nine: 9, ten: 10,
  eleven: 11, twelve: 12, thirteen: 13, fourteen: 14, fifteen: 15,
  sixteen: 16, seventeen: 17, eighteen: 18, nineteen: 19,
};
const TENS = {
  двадцать: 20, тридцать: 30, сорок: 40, пятьдесят: 50,
  шестьдесят: 60, семьдесят: 70, восемьдесят: 80, девяносто: 90,
  twenty: 20, thirty: 30, forty: 40, fifty: 50,
  sixty: 60, seventy: 70, eighty: 80, ninety: 90,
};
const HUNDREDS = {
  сто: 100, двести: 200, триста: 300, четыреста: 400,
  пятьсот: 500, шестьсот: 600, семьсот: 700, восемьсот: 800,
  девятьсот: 900, hundred: 100,
};
const THOUSAND_WORDS = new Set([
  "тысяча", "тысячи", "тысяч", "тыща", "тыщи", "тыс",
  "thousand", "thousands",
]);

const SPELLED_TOKENS = new Set([
  ...Object.keys(ONES),
  ...Object.keys(TENS),
  ...Object.keys(HUNDREDS),
  ...THOUSAND_WORDS,
  "миллион", "миллиона", "миллионов", "million",
  "итого", "total",
]);

const CURRENCY_TOKEN = "(руб(?:л(?:ей|я|ь|ями)?)?|rubles?|byn|br|бел(?:\\.?\\s*)?руб(?:л(?:ей|я|ь)?)?|dollars?|usd|eur|доллар(?:ов|а|ы)?|евро|₽|\\$|€)";
const AMOUNT_NUMBER = "(\\d+(?:\\s+\\d{3})*(?:[.,]\\d{1,2})?)";
const COMMODITY_CURRENCY = new RegExp(
  `${WB}(?:покупк[ауие]|купил[аи]?|bought|buying|purchase[sd]?|buy)\\s+${CURRENCY_TOKEN}${WA}`,
  "i"
);

const CATEGORIES = [
  {
    id: "housing",
    nameRu: "Жильё",
    nameEn: "Housing",
    kind: "expense",
    keywords: [
      "жильё", "жилье", "housing", "аренда", "rent", "квартира",
      "apartment", "коммуналка", "utilities", "свет", "electricity",
      "вода", "water", "ипотека", "mortgage", "жкх", "газ",
      "интернет дома", "квартплата",
    ],
  },
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
      "supermarket", "макдональдс", "mcdonalds", "картошк", "огурц",
      "гарнир", "доставка еды", "пятёрочка", "пятерочка",
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
      "проезд", "fare",
    ],
  },
  {
    id: "health",
    nameRu: "Здоровье",
    nameEn: "Health",
    kind: "expense",
    keywords: [
      "здоровье", "health", "аптека", "pharmacy", "врач", "doctor",
      "медицина", "medicine", "спорт", "gym", "фитнес", "fitness",
      "таблетки", "больница", "hospital", "стоматолог", "dentist",
    ],
  },
  {
    id: "shopping",
    nameRu: "Одежда",
    nameEn: "Clothing",
    kind: "expense",
    keywords: [
      "одежда", "clothing", "clothes", "обувь", "shoes", "куртка",
      "джинсы", "магазин одежды", "wildberries", "wb", "ozon",
      "вещи", "покупки одежды", "шопинг",
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
      "concert", "клуб", "club", "бар", "bar", "bowling", "хобби",
    ],
  },
  {
    id: "telecom",
    nameRu: "Связь и техника",
    nameEn: "Tech & Comms",
    kind: "expense",
    keywords: [
      "связь", "телефон", "phone", "мобильн", "mobile", "тариф",
      "интернет", "wifi", "роутер", "техника", "гаджет", "gadget",
      "закинул на телефон", "пополнил телефон", "sim", "сим",
      "apple", "samsung", "ноутбук", "laptop", "наушники",
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
      "perfume", "духи", "ногти", "nails", "spa",
    ],
  },
  {
    id: "gifts",
    nameRu: "Подарки",
    nameEn: "Gifts",
    kind: "both",
    keywords: ["подарок", "gift", "подарки", "gifts", "день рождения", "birthday"],
  },
  {
    id: "savings",
    nameRu: "Накопления",
    nameEn: "Savings",
    kind: "expense",
    keywords: [
      "накопления", "savings", "отложил", "отложить", "копилк",
      "вклад", "deposit", "кредит", "credit", "ипотечный платёж",
      "долг", "debt",
    ],
  },
  {
    id: "other-expense",
    nameRu: "Другое",
    nameEn: "Other",
    kind: "expense",
    keywords: ["другое", "other", "разное", "misc"],
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
    id: "freelance",
    nameRu: "Фриланс",
    nameEn: "Freelance",
    kind: "income",
    keywords: [
      "фриланс", "freelance", "проект", "project", "клиент", "client",
      "заказ", "contract",
    ],
  },
  {
    id: "other-income",
    nameRu: "Прочий доход",
    nameEn: "Other income",
    kind: "income",
    keywords: ["доход", "income", "перевод", "transfer", "возврат", "refund"],
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
    "жильё", "жилье", "housing",
    "здоровье", "health",
    "одежда", "clothing", "clothes",
    "развлечения", "entertainment",
    "связь", "техника",
    "накопления", "savings",
    "другое", "other", "разное", "misc",
    "косметика", "cosmetics", "красота", "beauty",
    "категория", "category",
    "зарплата", "зарплату", "зарплаты", "salary", "зп", "оклад", "wage",
    "paycheck", "аванс",
    "фриланс", "freelance",
    "подарок", "подарки", "gift", "gifts",
    "доход", "income", "перевод", "transfer", "возврат", "refund",
    "рублей", "рубль", "рубля", "ruble", "rubles", "byn", "br",
    "копеек", "копейки", "копейка",
    "на", "за", "для", "и", "получил", "получила", "потратил", "потратила",
    "закинул", "закинула", "пополнил", "купил", "купила", "добавь", "кажется",
    "сегодня", "это", "будет", "свой", "свою",
    "got", "received", "spent", "paid", "bought",
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
  `${WB}(spent|spend|paid|pay|bought|buy|потратил|потратила|потрачено|оплатил|оплатила|купил|купила|расход|закинул|закинула|пополнил|пополнила|добавь|добавьте|добавить|итого)${WA}`,
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

function parseSpelled(text) {
  const tokens = text.replace(/-/g, " ").split(/\s+/).filter(Boolean);
  let best = null;
  let i = 0;
  while (i < tokens.length) {
    let value = 0;
    let chunk = 0;
    let consumed = 0;
    let j = i;
    let sawNumber = false;
    while (j < tokens.length) {
      const t = tokens[j];
      if (THOUSAND_WORDS.has(t)) {
        const base = chunk === 0 ? 1 : chunk;
        value += base * 1000;
        chunk = 0;
        sawNumber = true;
        consumed += 1;
        j += 1;
        continue;
      }
      // Hybrid: «тыща 200» / «две тысячи 50»
      if (/^\d+$/.test(t) && sawNumber) {
        chunk += Number.parseInt(t, 10);
        consumed += 1;
        j += 1;
        continue;
      }
      if (HUNDREDS[t] != null) {
        chunk += HUNDREDS[t];
        sawNumber = true;
        consumed += 1;
        j += 1;
        continue;
      }
      if (TENS[t] != null) {
        chunk += TENS[t];
        sawNumber = true;
        consumed += 1;
        j += 1;
        continue;
      }
      if (ONES[t] != null) {
        chunk += ONES[t];
        sawNumber = true;
        consumed += 1;
        j += 1;
        continue;
      }
      if ((t === "и" || t === "and") && sawNumber) {
        consumed += 1;
        j += 1;
        continue;
      }
      break;
    }
    if (sawNumber) {
      value += chunk;
      if (value > 0) best = Math.max(best ?? 0, value);
      i += Math.max(consumed, 1);
    } else {
      i += 1;
    }
  }
  return best;
}

function parseRublesAndKopeks(text) {
  const patterns = [
    /(\d+)\s*(?:руб(?:л(?:ей|я|ь)?)?|rubles?|byn|br)?\s*(\d{1,2})\s*(?:копе(?:ек|йки|йка)|коп\.?|cents?)/i,
    /итого\s+(\d+)[.,]?(\d{1,2})?/i,
  ];
  for (const re of patterns) {
    const m = text.match(re);
    if (!m) continue;
    const whole = Number.parseFloat(m[1]) || 0;
    let frac = 0;
    if (m[2]) {
      frac = m[2].length === 1 ? Number.parseFloat(m[2]) / 10 : Number.parseFloat(m[2]) / 100;
    }
    const value = whole + frac;
    if (value > 0) return Math.round(value * 100) / 100;
  }
  return null;
}

function parseAmount(text) {
  const normalized = normalize(text);
  const withKopeks = parseRublesAndKopeks(normalized);
  if (withKopeks != null) return withKopeks;

  const spelled = parseSpelled(normalized);
  if (spelled != null) return spelled;

  let cleaned = text.replace(/(\d)\s+(\d{3})\b/g, "$1$2").replace(/,/g, ".");
  const patterns = [
    /(\d+(?:\.\d{1,2})?)\s*(?:₽|руб(?:л(?:ей|я|ь)?)?|rubles?|byn|br|dollars?|\$|usd|eur|€)/i,
    /(?:₽|руб(?:л(?:ей|я|ь)?)?|rubles?|byn|br|dollars?|\$|usd|eur|€)\s*(\d+(?:\.\d{1,2})?)/i,
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

function stripSpelled(text) {
  let working = text;
  for (const token of [...SPELLED_TOKENS].sort((a, b) => b.length - a.length)) {
    const escaped = token.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
    working = working.replace(new RegExp(`${WB}${escaped}${WA}`, "gi"), " ");
  }
  return working;
}

function stripAmountsAndCurrency(text) {
  let working = text;
  // Strip only amount-unit pairs; keep commodity «долларов» in notes.
  working = working.replace(new RegExp(`${AMOUNT_NUMBER}\\s*${CURRENCY_TOKEN}`, "gi"), " ");
  working = working.replace(new RegExp(`${CURRENCY_TOKEN}\\s*${AMOUNT_NUMBER}`, "gi"), " ");
  working = working.replace(/\d[\d\s.,]*/g, " ");
  working = working.replace(
    new RegExp(`${WB}(руб(?:л(?:ей|я|ь|ями)?)?|rubles?|₽)${WA}`, "gi"),
    " "
  );
  working = stripSpelled(working);
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
  working = working.replace(INCOME_CUES, " ").replace(EXPENSE_CUES, " ");
  if (matched) {
    working = stripKeyword(matched.nameRu, working);
    working = stripKeyword(matched.nameEn, working);
  }
  for (const token of [...NOTE_SUPPRESS].sort((a, b) => b.length - a.length)) {
    working = stripKeyword(token, working);
  }
  return finalizeNote(working, matched);
}

function resolveCurrencyToken(raw) {
  const t = normalize(raw).replace(/\$/g, "usd").replace(/€/g, "eur").replace(/₽/g, "rub");
  if (t.includes("dollar") || t === "usd" || t.startsWith("доллар")) return "usd";
  if (t.includes("euro") || t === "eur" || t.startsWith("евро")) return "eur";
  if (t === "byn" || t === "br" || t.includes("бел")) return "byn";
  // «руб» → entry default
  return null;
}

function looksLikeCurrencyToken(s) {
  const t = String(s).trim();
  if (!t) return false;
  return !/^\d/.test(t);
}

/** Amount-attached currency wins over trailing commodity words. */
function inferCurrency(text) {
  const patterns = [
    new RegExp(`${AMOUNT_NUMBER}\\s*${CURRENCY_TOKEN}`, "gi"),
    new RegExp(`${CURRENCY_TOKEN}\\s*${AMOUNT_NUMBER}`, "gi"),
  ];
  let best = null;
  for (const re of patterns) {
    for (const m of text.matchAll(re)) {
      const g1 = m[1] ?? "";
      const g2 = m[2] ?? "";
      const token = looksLikeCurrencyToken(g1) ? g1 : g2;
      if (!best || m.index < best.index) best = { index: m.index, token };
    }
  }
  if (best) {
    return resolveCurrencyToken(best.token);
  }

  // No unit on amount: ignore «покупка долларов» commodity phrases.
  let working = text.replace(COMMODITY_CURRENCY, " ");
  if (new RegExp(`${WB}(dollars?|usd|доллар(?:ов|а|ы)?|\\$)${WA}`, "i").test(working)) return "usd";
  if (new RegExp(`${WB}(euros?|eur|евро|€)${WA}`, "i").test(working)) return "eur";
  if (new RegExp(`${WB}(byn|br|бел(?:\\.?\\s*)?руб(?:л(?:ей|я|ь)?)?)${WA}`, "i").test(working)) return "byn";
  return null;
}

const MONTHLY_RE =
  new RegExp(`${WB}(every\\s+month|each\\s+month|monthly|per\\s+month|раз\\s+в\\s+месяц|каждый\\s+месяц|каждую\\s+месяц|ежемесячно|раз\\s+в\\s+мес)${WA}`, "i");
const WEEKLY_RE =
  new RegExp(`${WB}(every\\s+week|each\\s+week|weekly|per\\s+week|раз\\s+в\\s+недел[юи]|каждую\\s+неделю|каждый\\s+недел[юи]|еженедельно)${WA}`, "i");
const MULTI_SPLIT = /(?:,\s*|\s+и\s+|\s+and\s+)(?=(?:[^0-9]{0,40})?\d)/gi;

function detectFrequency(text) {
  if (MONTHLY_RE.test(text)) return "monthly";
  if (WEEKLY_RE.test(text)) return "weekly";
  return null;
}

function stripRecurringCues(text) {
  return text
    .replace(MONTHLY_RE, " ")
    .replace(WEEKLY_RE, " ")
    .replace(/\s{2,}/g, " ")
    .trim();
}

function splitMultiExpense(text) {
  const parts = [];
  let last = 0;
  MULTI_SPLIT.lastIndex = 0;
  let m;
  while ((m = MULTI_SPLIT.exec(text)) !== null) {
    const piece = text.slice(last, m.index).trim();
    if (piece) parts.push(piece);
    last = m.index + m[0].length;
  }
  const tail = text.slice(last).trim();
  if (tail) parts.push(tail);
  const withAmount = parts.filter((p) => parseAmount(p) != null);
  return withAmount.length >= 2 ? withAmount : [text];
}

function parse(rawText) {
  const frequency = detectFrequency(rawText);
  const working = frequency ? stripRecurringCues(rawText) : rawText;
  const amount = parseAmount(working);
  let type = inferType(working);
  let matched = autoAssign(working, type);
  if (!matched) matched = autoAssign(working, null);
  if (!type && matched) type = matched.kind === "income" ? "income" : "expense";
  if (!type) type = "expense";
  matched = autoAssign(working, type) ?? autoAssign(working, null);
  const categoryMatchedByKeyword = Boolean(matched);
  const categoryId =
    matched?.id ??
    CATEGORIES.find((c) => c.kind === type || c.kind === "both")?.id;
  const note = extractNote(working, matched);
  const currency = inferCurrency(working);
  return {
    amount,
    type,
    categoryId,
    note,
    categoryMatchedByKeyword,
    currency,
    frequency,
    isAutosaveReady: Boolean(
      !frequency && amount && amount > 0 && categoryMatchedByKeyword && categoryId
    ),
  };
}

function parseMany(rawText) {
  const trimmed = String(rawText).trim();
  if (!trimmed) return [];
  const frequency = detectFrequency(trimmed);
  if (frequency) {
    const draft = parse(trimmed);
    return [draft];
  }
  const segments = splitMultiExpense(trimmed);
  if (segments.length >= 2) {
    const drafts = segments.map(parse).filter((d) => d.amount && d.amount > 0);
    if (drafts.length >= 2) return drafts;
  }
  return [parse(trimmed)];
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
    expect: { amount: 20, categoryId: "food", note: "", autosave: true, currency: "usd" },
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
    name: "7 RU beauty / косметика (руб → entry default)",
    input: "17 руб косметика",
    expect: { amount: 17, categoryId: "beauty", note: "", autosave: true, currency: null },
  },
  // DeepSeek free-form patterns
  {
    name: "ds phone top-up → telecom + note",
    input: "20 рублей закинул на свой телефон",
    expect: { amount: 20, categoryId: "telecom", note: "телефон", autosave: true, currency: null },
  },
  {
    name: "ds bus fare → transport + проезд note",
    input: "70 рублей это будет проезд на автобусе",
    // «автобусе» kept (declined form ≠ suppress token «автобус»)
    expect: { amount: 70, categoryId: "transport", note: "проезд автобусе", autosave: true },
  },
  {
    name: "ds rent spelled amount → housing + description",
    input: "добавь тысяча тридцать пять рублей. Аренда квартиры.",
    expect: { amount: 1035, categoryId: "housing", note: "Аренда квартиры", autosave: true },
  },
  {
    name: "ds groceries + kopecks",
    input: "купил картошки гарнир огурцов итого 7 рублей 40 копеек",
    expect: { amount: 7.4, categoryId: "food", note: "картошки гарнир огурцов", autosave: true },
  },
  // Amount-attached currency wins over commodity «долларов»
  {
    name: "fx руб amount wins over покупка долларов",
    input: "900 рублей, покупка долларов",
    expect: { amount: 900, currency: null, note: "покупка долларов", autosave: false },
  },
  {
    name: "fx руб + купил доллары",
    input: "500 рублей купил доллары",
    expect: { amount: 500, currency: null },
  },
  {
    name: "fx dollars still stamps when unit on amount",
    input: "20 dollars food",
    expect: { amount: 20, currency: "usd", categoryId: "food" },
  },
  // Hybrid speech thousands + digits
  {
    name: "hybrid тыща 200 → 1200",
    input: "тыща 200 руб подарки деньги ульяне",
    expect: { amount: 1200, categoryId: "gifts", currency: null, noteIncludes: "ульяне" },
  },
  {
    name: "hybrid тысяча 200",
    input: "тысяча 200 рублей",
    expect: { amount: 1200, currency: null },
  },
  {
    name: "hybrid две тысячи 50",
    input: "две тысячи 50 рублей",
    expect: { amount: 2050, currency: null },
  },
  {
    name: "recurring Netflix every month",
    input: "Netflix 10 dollars every month",
    expect: { amount: 10, currency: "usd", frequency: "monthly", autosave: false },
  },
  {
    name: "recurring RU каждый месяц",
    input: "аренда 200 каждый месяц",
    expect: { amount: 200, categoryId: "housing", frequency: "monthly", autosave: false },
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
  if (c.expect.noteIncludes && !normalize(draft.note).includes(normalize(c.expect.noteIncludes))) {
    bugs.push(`noteIncludes: «${draft.note}» missing «${c.expect.noteIncludes}»`);
  }
  for (const filler of ["рублей", "развлечения", "точка"]) {
    if (
      normalize(draft.note).includes(normalize(filler)) &&
      !normalize(c.expect.note ?? "").includes(normalize(filler))
    ) {
      bugs.push(`note contains filler «${filler}»`);
    }
  }
  if (c.expect.autosave !== undefined && draft.isAutosaveReady !== c.expect.autosave) {
    bugs.push(`autosave: got ${draft.isAutosaveReady} expected ${c.expect.autosave}`);
  }
  if (Object.prototype.hasOwnProperty.call(c.expect, "currency") && draft.currency !== c.expect.currency) {
    bugs.push(`currency: got ${draft.currency} expected ${c.expect.currency}`);
  }
  if (Object.prototype.hasOwnProperty.call(c.expect, "frequency") && draft.frequency !== c.expect.frequency) {
    bugs.push(`frequency: got ${draft.frequency} expected ${c.expect.frequency}`);
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

const multi = parseMany("кофе 5 и такси 12");
{
  const bugs = [];
  if (multi.length !== 2) bugs.push(`count ${multi.length}`);
  else {
    if (multi[0].amount !== 5) bugs.push("amount0");
    if (multi[1].amount !== 12) bugs.push("amount1");
    if (multi[0].categoryId !== "food") bugs.push("cat0");
    if (multi[1].categoryId !== "transport") bugs.push("cat1");
  }
  const ok = bugs.length === 0;
  if (!ok) failed += 1;
  console.log(`${ok ? "PASS" : "FAIL"}  multi coffee+taxi`);
  if (!ok) for (const b of bugs) console.log(`      - ${b}`);
}

console.log("\n---");
console.log(`Total: ${results.length + 1}, passed: ${results.length + 1 - failed}, failed: ${failed}`);
if (failed > 0) {
  process.exit(1);
}
console.log("Self-test gate PASSED (logic).");
console.log("BLOCKER: No Xcode/Simulator on this Linux VM — device UI scenarios not executed.");
process.exit(0);
