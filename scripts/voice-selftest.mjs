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
/** JS `\w` is ASCII-only — use this after Cyrillic stems (бел…, европ…). */
const WL = "[0-9A-Za-zА-Яа-яЁё_]*";

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

const CURRENCY_TOKEN = "(руб(?:л(?:ей|я|ь|ями)?)?|rubles?|byn|br|белорусск(?:их|ий|ого|ом|ими)?\\s+руб(?:л(?:ей|я|ь|ями)?)?|бел(?:\\.?\\s*)?руб(?:л(?:ей|я|ь)?)?|dollars?|usd|eur|gbp|доллар(?:ов|а|ы)?|евро|фунт(?:ов|а|ы|ами|е|ом)?(?:\\s+стерлинг\\w*)?|pounds?|₽|\\$|€|£)";
const AMOUNT_CURRENCY_UNIT = "(?:₽|\\$|€|£|руб(?:л(?:ей|я|ь|ями)?)?|rubles?|byn|br|dollars?|usd|eur|gbp|доллар(?:ов|а|ы)?|евро|фунт(?:ов|а|ы|ами|е|ом)?|pounds?)";
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
      "еда", "еды", "еду", "едой", "food",
      "кофе", "coffee", "кофейн", "кофейня", "кофейню",
      "обед", "lunch", "ужин", "dinner",
      "завтрак", "breakfast", "ресторан", "restaurant", "кафе", "cafe",
      "продукт", "продукты", "grocery", "groceries", "пицца", "pizza",
      "бургер", "burger", "снек", "snack", "столовая", "супермаркет",
      "supermarket", "макдональдс", "mcdonalds", "картошк", "огурц",
      "гарнир", "доставка еды", "доставку еды", "доставка", "доставку",
      "доставк", "delivery", "food delivery", "food order", "заказ еды",
      "поесть", "поел", "поела", "пообедал", "пообедала", "поужинал", "поужинала",
      "пятёрочка", "пятерочка",
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
      "заправил", "заправила", "заправ", "машину", "машина",
      "азс", "azs", "gas station", "petrol", "diesel", "дизель",
      "uber", "яндекс такси", "яндекс го", "yandex go", "yandex taxi",
      "парковка", "parking", "поезд", "train",
      "трамвай", "tram", "самокат", "scooter", "каршеринг", "carshare", "carsharing",
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
      "концерт", "concert", "клуб", "club", "бар", "bar", "bowling", "хобби",
    ],
  },
  {
    id: "subscriptions",
    nameRu: "Подписки",
    nameEn: "Subscriptions",
    kind: "expense",
    keywords: [
      "подписк", "подписка", "подписку", "подписки", "subscription", "subscriptions",
      "программа", "программу", "программе",
      "netflix", "spotify",
      "яндекс music", "yandex music", "яндекс музык", "яндекс plus", "яндекс плюс",
      "yandex plus", "apple music", "apple",
      "эпл мьюзик", "эппл мьюзик", "эпл music",
      "youtube premium", "youtube music", "ютюб премиум", "ютуб премиум",
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
    keywords: [
      "другое", "other", "разное", "misc",
      "игрушк", "toys", "toy", "цвет", "flowers", "flower",
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
    id: "freelance",
    nameRu: "Фриланс",
    nameEn: "Freelance",
    kind: "income",
    keywords: [
      "фриланс", "freelance", "проект", "project", "клиент", "client",
      "заказчик", "contract",
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
    "на", "за", "для", "и", "я", "получил", "получила", "потратил", "потратила",
    "закинул", "закинула", "пополнил", "купил", "купила", "заказал", "заказала",
    "добавь", "кажется",
    "сегодня", "вчера", "позавчера", "утром", "вечером",
    "вчерашнего", "вчерашний", "дня", "день",
    "это", "будет", "свой", "свою",
    "got", "received", "spent", "paid", "bought", "ordered",
    "зашёл", "зашла", "зашел", "зашли", "мы", "попил", "попила",
    "ездил", "ездила", "в",
    "доставка", "доставку", "доставк", "еды", "еду", "едой", "delivery",
    "ещё", "еще", "так", "привет", "слушай", "короче", "типа", "ну",
    "сходил", "сходила", "ходил", "ходила", "поесть", "поел", "поела",
    "заправила", "заправил", "заправка", "машину", "машина",
    "понедельник", "вторник", "среда", "среду", "четверг", "пятница", "пятницу",
    "суббота", "субботу", "воскресенье", "пн", "вт", "ср", "чт", "пт", "сб", "вс",
    "салон", "подписку", "подписка", "программу", "программа",
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
  `${WB}(spent|spend|paid|pay|bought|buy|потратил|потратила|потрачено|оплатил|оплатила|купил|купила|заказал|заказала|расход|закинул|закинула|пополнил|пополнила|добавь|добавьте|добавить|итого)${WA}`,
  "i"
);
/** ASCII `\w` misses Cyrillic endings — use an explicit letter class. */
const LETTER = "[а-яёА-ЯЁa-zA-Z]";
const FOOD_DELIVERY_CUE = new RegExp(
  `${WB}(?:доставк${LETTER}*\\s+ед${LETTER}*|ед${LETTER}*\\s+доставк${LETTER}*|заказ${LETTER}*\\s+(?:доставк${LETTER}*|ед${LETTER}*)|order(?:ed)?\\s+food|food\\s+order|food\\s+delivery|delivery\\s+food|доставк${LETTER}*)${WA}`,
  "i"
);
/** «поесть» / «сходил поесть» → Еда (never housing). */
const FOOD_MEAL_CUE = new RegExp(
  `${WB}(?:поесть|поел[аи]?|поем|поедим|поужина${LETTER}*|пообеда${LETTER}*|обеда${LETTER}*|ужина${LETTER}*|завтрака${LETTER}*|сходил[аи]?\\s+поесть|ходили\\s+поесть|went\\s+(?:to\\s+)?(?:eat|lunch|dinner)|had\\s+(?:lunch|dinner|breakfast))${WA}`,
  "i"
);
/** «заправила машину» / АЗС → Транспорт (never housing). */
const FUEL_CUE = new RegExp(
  `${WB}(?:заправ${LETTER}*|бензин${LETTER}*|топлив${LETTER}*|дизел${LETTER}*|азс|gas\\s*station|petrol|diesel|fuel(?:ed|ling)?)${WA}`,
  "i"
);
/** «салон» → Красота (never Еда / housing). */
const BEAUTY_SALON_CUE = new RegExp(
  `${WB}(?:салон${LETTER}*|salon|маникюр${LETTER}*|педикюр${LETTER}*|парикмахер${LETTER}*|стрижк${LETTER}*|beauty\\s*salon)${WA}`,
  "i"
);
const NOTE_NARRATIVE_FILLER = new RegExp(
  `${WB}(?:мы\\s+)?(?:зашли|зашёл|зашел|зашла|зайти)\\s+в${WA}` +
    `|${WB}(?:мы\\s+)?(?:зашли|зашёл|зашел|зашла)${WA}` +
    `|${WB}(?:потратил${LETTER}*|потрачено|ездил${LETTER}*|попил${LETTER}*|купил${LETTER}*|оплатил${LETTER}*|сходил${LETTER}*|ходил${LETTER}*)${WA}` +
    `|${WB}(?:ещё|еще|так|привет|слушай|короче|типа|ну)${WA}`,
  "gi"
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
    /(\d+(?:\.\d{1,2})?)\s*(?:₽|\$|€|£|руб(?:л(?:ей|я|ь)?)?|rubles?|byn|br|dollars?|usd|eur|gbp|фунт(?:ов|а|ы)?|pounds?)/i,
    /(?:₽|\$|€|£|руб(?:л(?:ей|я|ь)?)?|rubles?|byn|br|dollars?|usd|eur|gbp|фунт(?:ов|а|ы)?|pounds?)\s*(\d+(?:\.\d{1,2})?)/i,
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
  // Soft truncation — keep a short descriptive phrase, not the whole utterance.
  const maxChars = 42;
  if (s.length > maxChars) {
    const words = s.split(/\s+/).filter(Boolean);
    const clipped = [];
    let len = 0;
    for (const w of words) {
      const next = len + w.length + (clipped.length ? 1 : 0);
      if (next > maxChars) break;
      clipped.push(w);
      len = next;
    }
    s = clipped.length ? clipped.join(" ") : s.slice(0, maxChars);
  }
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
  // ё/е interchangeable so normalized suppress tokens hit spoken «зашёл».
  const flexible = [...k]
    .map((ch) => {
      if (ch === "е" || ch === "ё") return "[её]";
      if (ch === "Е" || ch === "Ё") return "[ЕЁ]";
      if (/\s/.test(ch)) return "\\s+";
      return ch.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
    })
    .join("");
  const re = new RegExp(`${WB}${flexible}${WA}`, "gi");
  return text.replace(re, " ");
}

function stripFiller(text) {
  NOTE_NARRATIVE_FILLER.lastIndex = 0;
  return text.replace(NOTE_NARRATIVE_FILLER, " ");
}

function finalizeNote(text, matched) {
  let s = stripAmountsAndCurrency(text);
  s = s.replace(INCOME_CUES, " ").replace(EXPENSE_CUES, " ");
  s = stripFiller(s);
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
  s = stripFiller(s);
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
  working = stripFiller(working);
  if (matched) {
    working = stripKeyword(matched.nameRu, working);
    working = stripKeyword(matched.nameEn, working);
  }
  for (const token of [...NOTE_SUPPRESS].sort((a, b) => b.length - a.length)) {
    working = stripKeyword(token, working);
  }
  working = stripFiller(working);
  return finalizeNote(working, matched);
}

function resolveCurrencyToken(raw) {
  // Map symbols before normalize — normalize() strips €/$/£/₽.
  let t = String(raw)
    .replace(/\$/g, " usd ")
    .replace(/€/g, " eur ")
    .replace(/£/g, " gbp ")
    .replace(/₽/g, " rub ");
  t = normalize(t);
  const parts = new Set(t.split(/\s+/).filter(Boolean));
  if (t.includes("dollar") || t === "usd" || t.startsWith("доллар") || parts.has("usd")) return "usd";
  if (t.includes("euro") || t === "eur" || t.startsWith("евро") || parts.has("eur")) return "eur";
  if (
    t.includes("pound") ||
    t === "gbp" ||
    t.startsWith("фунт") ||
    t.includes("стерлинг") ||
    parts.has("gbp")
  ) {
    return "gbp";
  }
  if (t === "byn" || t === "br" || t.includes("бел") || t.includes("белорус")) return "byn";
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
  if (new RegExp(`${WB}(pounds?|gbp|фунт(?:ов|а|ы|ами|е|ом)?(?:\\s+стерлинг\\w*)?|£)${WA}`, "i").test(working)) {
    return "gbp";
  }
  if (new RegExp(`${WB}(byn|br|белорусск\\w*|бел(?:\\.?\\s*)?руб(?:л(?:ей|я|ь)?)?)${WA}`, "i").test(working)) return "byn";
  return null;
}

const MONTHLY_RE =
  new RegExp(`${WB}(every\\s+month|each\\s+month|monthly|per\\s+month|раз\\s+в\\s+месяц|каждый\\s+месяц|каждую\\s+месяц|ежемесячно|раз\\s+в\\s+мес)${WA}`, "i");
const WEEKLY_RE =
  new RegExp(`${WB}(every\\s+week|each\\s+week|weekly|per\\s+week|раз\\s+в\\s+недел[юи]|каждую\\s+неделю|каждый\\s+недел[юи]|еженедельно)${WA}`, "i");
const MULTI_SPLIT = /(?:,\s*|\s+и\s+|\s+and\s+)(?=(?:[^0-9]{0,40})?\d)/gi;
const AMOUNT_SPAN = new RegExp(
  `\\d+(?:[.,]\\d{1,2})?\\s*${AMOUNT_CURRENCY_UNIT}|${AMOUNT_CURRENCY_UNIT}\\s*\\d+(?:[.,]\\d{1,2})?`,
  "gi"
);
const NARRATIVE_SPLIT = new RegExp(
  `(?:\\s+потом\\s+|\\s+затем\\s+|\\s+после\\s+(?:этого|того)\\s+|(?<=[\\p{L}\\d.])\\s+(?=оплатил[аи]?${WA})|(?<=[\\p{L}\\d.])\\s+(?=заказал[аи]?${WA})|(?<=[\\p{L}\\d.])\\s+(?=утром${WA})|(?<=[\\p{L}\\d.])\\s+(?=вечером${WA})|(?<=[\\p{L}\\d.])\\s+(?=сегодня${WA})|(?<=[\\p{L}\\d.])\\s+(?=вчера${WA})|(?<=[\\p{L}\\d.])\\s+(?=позавчера${WA})|(?<=[\\p{L}\\d.])\\s+(?=во?\\s+(?:понедельник|вторник|сред[ауеы]|четверг|пятниц[уыае]|суббот[уыае]|воскресень[еяю]|пн|вт|ср|чт|пт|сб|вс)${WA})|(?<=[\\p{L}\\d.])\\s+(?=(?:понедельник|вторник|сред[ауеы]|четверг|пятниц[уыае]|суббот[уыае]|воскресень[еяю])${WA}))`,
  "giu"
);
const SESSION_EUR = new RegExp(
  `${WB}(?:моя\\s+валюта\\s+евро|валюта\\s+евро|в\\s+европ${WL}|в\\s+еврозоне|europe|eurozone)${WA}`,
  "i"
);
const SESSION_USD = new RegExp(
  `${WB}(?:моя\\s+валюта\\s+(?:доллар${WL}|usd)|валюта\\s+(?:доллар${WL}|usd)|в\\s+сша)${WA}`,
  "i"
);
const SESSION_BYN = new RegExp(
  `${WB}(?:моя\\s+валюта\\s+(?:бел${WL}|byn|br|руб${WL})|валюта\\s+(?:бел${WL}|byn|br)|в\\s+рб|белорусск${WL}|бел\\.?\\s*руб|\\bbyn\\b|\\bbr\\b)${WA}`,
  "i"
);
const COMPANION_STRIP = new RegExp(
  `${WB}(?:вместе\\s+)?с\\s+[А-ЯЁа-яё][а-яёА-Яа-яЁё]{1,40}${WA}`,
  "giu"
);
const SUBSCRIPTION_CUE = new RegExp(
  `${WB}(?:подписк${LETTER}*(?:\\s+(?:на\\s+)?(?:программ${LETTER}*|сервис${LETTER}*|приложен${LETTER}*))?|subscription|netflix|spotify|яндекс\\s*(?:music|plus|плюс|музык\\w*)|yandex\\s*(?:music|plus)|apple\\s*music|\\bapple\\b|эпл\\s*мьюзик|эппл\\s*мьюзик|эпл\\s*music|youtube\\s*premium|youtube\\s*music)${WA}`,
  "i"
);
const SUBSCRIPTION_BRANDS = [
  {
    id: "apple_music",
    re: new RegExp(`${WB}(?:apple\\s*music|эпл\\s*мьюзик|эппл\\s*мьюзик|эпл\\s*music)${WA}`, "i"),
    name: "Apple Music",
  },
  {
    id: "youtube_premium",
    re: new RegExp(
      `${WB}(?:youtube\\s*premium|youtube\\s*music|ютюб\\s*премиум|ютуб\\s*премиум)${WA}`,
      "i"
    ),
    name: "YouTube Premium",
  },
  {
    id: "yandex_music",
    re: new RegExp(`${WB}(?:яндекс\\s*music|yandex\\s*music|яндекс\\s*музык\\w*)${WA}`, "i"),
    name: "Yandex Music",
  },
  {
    id: "yandex_plus",
    re: new RegExp(`${WB}(?:яндекс\\s*(?:plus|плюс)|yandex\\s*plus)${WA}`, "i"),
    name: "Yandex Plus",
  },
  { id: "netflix", re: new RegExp(`${WB}netflix${WA}`, "i"), name: "Netflix" },
  { id: "spotify", re: new RegExp(`${WB}spotify${WA}`, "i"), name: "Spotify" },
  { id: "apple_music", re: new RegExp(`${WB}apple${WA}`, "i"), name: "Apple Music" },
];

function detectFrequency(text) {
  MONTHLY_RE.lastIndex = 0;
  WEEKLY_RE.lastIndex = 0;
  if (MONTHLY_RE.test(text)) return "monthly";
  if (WEEKLY_RE.test(text)) return "weekly";
  return null;
}

function detectSubscriptionBrand(text) {
  for (const brand of SUBSCRIPTION_BRANDS) {
    brand.re.lastIndex = 0;
    if (brand.re.test(text)) return brand;
  }
  return null;
}

function detectSubscription(text) {
  SUBSCRIPTION_CUE.lastIndex = 0;
  if (SUBSCRIPTION_CUE.test(text)) return "monthly";
  if (detectSubscriptionBrand(text)) return "monthly";
  return null;
}

function detectSessionCurrency(text) {
  SESSION_EUR.lastIndex = 0;
  SESSION_USD.lastIndex = 0;
  SESSION_BYN.lastIndex = 0;
  if (SESSION_EUR.test(text)) return "eur";
  if (SESSION_USD.test(text)) return "usd";
  if (SESSION_BYN.test(text)) return "byn";
  return null;
}

function stripCompanions(text) {
  return text.replace(COMPANION_STRIP, " ").replace(/\s{2,}/g, " ").trim();
}

function detectDateAnchor(text) {
  let part = null;
  if (new RegExp(`${WB}(?:утром|с\\s+утра|morning)${WA}`, "i").test(text)) part = "morning";
  else if (new RegExp(`${WB}(?:вечером|evening|tonight)${WA}`, "i").test(text)) part = "evening";

  const yesterdayGen = new RegExp(
    `${WB}(?:вечером\\s+вчерашнего(?:\\s+дня)?|утром\\s+вчерашнего(?:\\s+дня)?|вчерашн(?:его|ий|яя|ее|им)\\s+(?:дня|день|вечер\\w*|утр\\w*))${WA}`,
    "i"
  );
  if (yesterdayGen.test(text)) {
    if (!part) {
      if (/вечер/i.test(text)) part = "evening";
      else if (/утр/i.test(text)) part = "morning";
    }
    return { offset: -1, part, dayExplicit: true };
  }
  if (new RegExp(`${WB}позавчера${WA}`, "i").test(text)) {
    return { offset: -2, part, dayExplicit: true };
  }
  if (new RegExp(`${WB}вчера${WA}`, "i").test(text)) {
    return { offset: -1, part, dayExplicit: true };
  }
  if (new RegExp(`${WB}сегодня${WA}`, "i").test(text)) {
    return { offset: 0, part, dayExplicit: true };
  }
  // Weekdays пн–вс / full names — most recent occurrence (incl. today).
  const weekdayCues = [
    [2, `(?:понедельн${LETTER}*|пн)`],
    [3, `(?:вторник${LETTER}*|вт)`],
    [4, `(?:сред[аеуы]|ср)`],
    [5, `(?:четверг${LETTER}*|чт)`],
    [6, `(?:пятниц${LETTER}*|пт)`],
    [7, `(?:суббот${LETTER}*|сб)`],
    [1, `(?:воскресень${LETTER}*|вс)`],
  ];
  for (const [weekday, pat] of weekdayCues) {
    if (new RegExp(`${WB}${pat}${WA}`, "i").test(text)) {
      return { offset: offsetToWeekday(weekday), part, dayExplicit: true };
    }
  }
  // Bare «утром» / «вечером» — day-part only; keep prior day when set.
  if (part) return { offset: 0, part, dayExplicit: false };
  return null;
}

/** Gregorian weekday 1=Sun…7=Sat → days since most recent occurrence (0=today). */
function offsetToWeekday(targetWeekday, from = new Date()) {
  const greg = from.getDay() + 1;
  let delta = greg - targetWeekday;
  if (delta < 0) delta += 7;
  return -delta;
}

function stripRecurringCues(text) {
  return text
    .replace(MONTHLY_RE, " ")
    .replace(WEEKLY_RE, " ")
    .replace(/\s{2,}/g, " ")
    .trim();
}

function splitByAmountSpans(text) {
  AMOUNT_SPAN.lastIndex = 0;
  const matches = [...text.matchAll(AMOUNT_SPAN)];
  if (matches.length < 2) return null;
  const parts = [];
  for (let i = 0; i < matches.length; i++) {
    const start = i === 0 ? 0 : matches[i].index;
    const end = i + 1 < matches.length ? matches[i + 1].index : text.length;
    const piece = text.slice(start, end).trim();
    if (piece) parts.push(piece);
  }
  const withAmount = parts.filter((p) => parseAmount(p) != null);
  return withAmount.length >= 2 ? parts.filter((p) => parseAmount(p) != null) : null;
}

function splitMultiExpense(text) {
  // Prefer comma/«и» first so «30 евро, подписка 3 доллара» keeps brand with the 3.
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
  let withAmount = parts.filter((p) => parseAmount(p) != null);
  if (withAmount.length >= 2) {
    // Further split each clause on bare amount+unit runs («15 € … 30 $»).
    const expanded = [];
    for (const part of withAmount.length >= 2 ? parts : [text]) {
      if (parseAmount(part) == null && withAmount.length >= 2) continue;
      const spanned = splitByAmountSpans(part);
      if (spanned) expanded.push(...spanned);
      else if (parseAmount(part) != null) expanded.push(part);
    }
    const ok = expanded.filter((p) => parseAmount(p) != null);
    if (ok.length >= 2) return ok;
    return withAmount;
  }

  const spanned = splitByAmountSpans(text);
  if (spanned) return spanned;
  return [text];
}

function splitNarrative(text) {
  const parts = [];
  let last = 0;
  NARRATIVE_SPLIT.lastIndex = 0;
  let m;
  let found = false;
  while ((m = NARRATIVE_SPLIT.exec(text)) !== null) {
    found = true;
    const piece = text.slice(last, m.index).trim();
    if (piece) parts.push(piece);
    last = m.index + m[0].length;
  }
  if (!found) return splitMultiExpense(text);
  const tail = text.slice(last).trim();
  if (tail) parts.push(tail);
  // Flatten: each narrative clause may still hold comma/«и» multi-amounts
  // (e.g. «продукты 30 евро, подписка 3 доллара … были вчера»).
  // Keep date-only clauses («утром», «вчера я») so materialize can advance anchors.
  const expanded = [];
  for (const part of parts) {
    const multi = splitMultiExpense(part);
    if (multi.length >= 2) expanded.push(...multi);
    else expanded.push(part);
  }
  const withAmount = expanded.filter((p) => parseAmount(p) != null);
  return withAmount.length >= 2 ? expanded : [text];
}

function countAmountMentions(text) {
  const digitCount = (text.match(/\d+(?:[.,]\d{1,2})?/g) || []).length;
  const spelledOnes = [
    "один", "одна", "два", "две", "три", "четыре", "пять", "шесть", "семь",
    "восемь", "девять", "десять", "one", "two", "three", "four", "five",
  ];
  let spelledHits = 0;
  for (const word of spelledOnes) {
    if (new RegExp(`${WB}${word}${WA}`, "i").test(text)) spelledHits += 1;
  }
  if (digitCount > 0) return digitCount + spelledHits;
  return spelledHits;
}

function isFoodDelivery(text) {
  FOOD_DELIVERY_CUE.lastIndex = 0;
  return FOOD_DELIVERY_CUE.test(text);
}

function isFoodMeal(text) {
  FOOD_MEAL_CUE.lastIndex = 0;
  return FOOD_MEAL_CUE.test(text);
}

function isFuelExpense(text) {
  FUEL_CUE.lastIndex = 0;
  return FUEL_CUE.test(text);
}

function isBeautySalon(text) {
  BEAUTY_SALON_CUE.lastIndex = 0;
  return BEAUTY_SALON_CUE.test(text);
}

function parse(rawText, sessionCurrency = null, dayOffset = null, dayPart = null) {
  const session = sessionCurrency ?? detectSessionCurrency(rawText);
  const anchor = detectDateAnchor(rawText);
  const offset = dayOffset ?? anchor?.offset ?? null;
  const part = dayPart ?? anchor?.part ?? null;
  const brand = detectSubscriptionBrand(rawText);
  const subscription = detectSubscription(rawText) ?? (brand ? "monthly" : null);
  const frequency = detectFrequency(rawText) ?? subscription;
  const working = frequency ? stripRecurringCues(rawText) : rawText;
  const amount = parseAmount(working);
  let type = inferType(working);
  const delivery = isFoodDelivery(working) || isFoodDelivery(rawText);
  const meal = isFoodMeal(working) || isFoodMeal(rawText);
  const fuel = isFuelExpense(working) || isFuelExpense(rawText);
  const salon = isBeautySalon(working) || isBeautySalon(rawText);
  const hasSubCue = Boolean(subscription || brand);
  if (delivery || meal || subscription) type = "expense";
  let matched = autoAssign(working, type);
  if (!matched) matched = autoAssign(working, null);
  if (!type && matched) type = matched.kind === "income" ? "income" : "expense";
  if (delivery || meal || subscription) type = "expense";
  if (!type) type = "expense";
  matched = autoAssign(working, type) ?? autoAssign(working, null);
  // Strong cues beat weak / housing misses (salon before meal so «салон» ≠ Еда).
  if (salon) {
    matched = CATEGORIES.find((c) => c.id === "beauty") ?? matched;
  } else if (delivery || meal) {
    matched = CATEGORIES.find((c) => c.id === "food") ?? matched;
  } else if (fuel) {
    matched = CATEGORIES.find((c) => c.id === "transport") ?? matched;
  } else if (
    matched?.id === "housing" &&
    (delivery || meal || /доставк|еды|еду|заказ|поесть|поел/i.test(working))
  ) {
    matched = CATEGORIES.find((c) => c.id === "food") ?? matched;
  }
  // Any подписк* cue (incl. «подписку на программу» / $ / €) → Подписки, never housing.
  if (hasSubCue) {
    matched =
      CATEGORIES.find((c) => c.id === "subscriptions") ??
      (brand ? CATEGORIES.find((c) => c.id === "entertainment") : null) ??
      matched;
  }
  const categoryMatchedByKeyword = Boolean(matched);
  // Blind fallback is housing (sort 0) — never use it for meal/fuel/salon/sub/delivery.
  let categoryId;
  if (delivery || meal) {
    categoryId = matched?.id ?? CATEGORIES.find((c) => c.id === "food")?.id;
  } else if (fuel) {
    categoryId = matched?.id ?? CATEGORIES.find((c) => c.id === "transport")?.id;
  } else if (salon) {
    categoryId = matched?.id ?? CATEGORIES.find((c) => c.id === "beauty")?.id;
  } else if (hasSubCue) {
    categoryId = matched?.id ?? CATEGORIES.find((c) => c.id === "subscriptions")?.id;
  } else {
    categoryId =
      matched?.id ??
      CATEGORIES.find((c) => c.kind === type || c.kind === "both")?.id;
  }
  let note = extractNote(working, matched);
  if (brand) note = brand.name;
  let currency = inferCurrency(working);
  if (currency == null && session != null) currency = session;
  return {
    amount,
    type,
    categoryId,
    note,
    categoryMatchedByKeyword,
    currency,
    frequency,
    dayOffset: offset,
    dayPart: part,
    subscriptionBrand: brand?.id ?? null,
    isAutosaveReady: Boolean(
      !frequency && amount && amount > 0 && categoryMatchedByKeyword && categoryId
    ),
  };
}

function materializeSegments(segments, fullText, sessionCurrency) {
  let activeOffset = null;
  let activePart = null;
  const preamble = detectDateAnchor(fullText);
  if (preamble?.dayExplicit) {
    activeOffset = preamble.offset;
    activePart = preamble.part;
  }
  const drafts = [];
  for (const segment of segments) {
    const anchor = detectDateAnchor(segment);
    if (anchor) {
      if (anchor.dayExplicit && anchor.offset != null) {
        activeOffset = anchor.offset;
      } else if (activeOffset == null && anchor.offset != null) {
        activeOffset = anchor.offset;
      }
      if (anchor.part) activePart = anchor.part;
    }
    const draft = parse(segment, sessionCurrency, activeOffset, activePart);
    if (!(draft.amount && draft.amount > 0)) continue;
    if (!draft.frequency) {
      const sub = detectSubscription(segment);
      if (sub) draft.frequency = sub;
    }
    if (!draft.subscriptionBrand) {
      const brand = detectSubscriptionBrand(segment);
      if (brand) {
        draft.subscriptionBrand = brand.id;
        draft.frequency = draft.frequency ?? "monthly";
        draft.note = brand.name;
        draft.categoryId = "subscriptions";
        draft.categoryMatchedByKeyword = true;
      }
    }
    drafts.push(draft);
  }
  return drafts;
}

function parseMany(rawText) {
  const trimmed = String(rawText).trim();
  if (!trimmed) return [];
  const sessionCurrency = detectSessionCurrency(trimmed);
  const cleaned = stripCompanions(trimmed);
  const amountCount = countAmountMentions(cleaned);

  if (amountCount <= 1) {
    const frequency = detectFrequency(cleaned) ?? detectSubscription(cleaned);
    if (frequency) {
      const draft = parse(cleaned, sessionCurrency);
      draft.frequency = frequency;
      return [draft];
    }
  }

  const narrative = splitNarrative(cleaned);
  if (narrative.length >= 2) {
    const drafts = materializeSegments(narrative, cleaned, sessionCurrency);
    if (drafts.length >= 2) return drafts;
  }

  const simple = splitMultiExpense(cleaned);
  if (simple.length >= 2) {
    const drafts = materializeSegments(simple, cleaned, sessionCurrency);
    if (drafts.length >= 2) return drafts;
  }

  return [parse(cleaned, sessionCurrency)];
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
    expect: {
      amount: 10,
      currency: "usd",
      categoryId: "subscriptions",
      frequency: "monthly",
      autosave: false,
    },
  },
  {
    name: "recurring RU каждый месяц",
    input: "аренда 200 каждый месяц",
    expect: { amount: 200, categoryId: "housing", frequency: "monthly", autosave: false },
  },
  // Ivan screenshot tip — meal / fuel / salon / sub / filler notes
  {
    name: "ivan поесть → food never housing",
    input: "сходил поесть на 25 руб",
    expect: { amount: 25, categoryId: "food", type: "expense" },
  },
  {
    name: "ivan поесть bare → food",
    input: "поесть 40 рублей",
    expect: { amount: 40, categoryId: "food", type: "expense" },
  },
  {
    name: "ivan заправила машину → transport",
    input: "заправила машину на 50 руб",
    expect: { amount: 50, categoryId: "transport", type: "expense" },
  },
  {
    name: "ivan салон → beauty never food",
    input: "в салоне 1200 руб",
    expect: { amount: 1200, categoryId: "beauty", type: "expense" },
  },
  {
    name: "ivan подписку на программу $ → subscriptions",
    input: "оплатил подписку на программу 5 долларов",
    expect: {
      amount: 5,
      currency: "usd",
      categoryId: "subscriptions",
      frequency: "monthly",
      autosave: false,
    },
  },
  {
    name: "ivan подписка € → subscriptions never housing",
    input: "подписка 9 евро",
    expect: {
      amount: 9,
      currency: "eur",
      categoryId: "subscriptions",
      frequency: "monthly",
      autosave: false,
    },
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

const multiCases = [
  {
    name: "multi coffee+taxi",
    input: "кофе 5 и такси 12",
    expect: [
      { amount: 5, categoryId: "food" },
      { amount: 12, categoryId: "transport" },
    ],
  },
  {
    name: "ivan narrative BYN/USD/dates/subscription",
    input:
      "Слушай я в рб моя валюта белорусский рубль и вчера я купил на 15 белорусских рублей кофе зашёл в кофейню попил оплатил подписку Яндекс Music три доллара потом я сходил за продуктами с Ульяной и купили мы продукты на 40 руб. сегодня утром я ездил на Каршеринг потратил 18 руб.",
    expect: [
      { amount: 15, currency: "byn", categoryId: "food", dayOffset: -1 },
      {
        amount: 3,
        currency: "usd",
        categoryId: "subscriptions",
        dayOffset: -1,
        frequency: "monthly",
        subscriptionBrand: "yandex_music",
      },
      { amount: 40, currency: "byn", categoryId: "food", dayOffset: -1 },
      {
        amount: 18,
        currency: "byn",
        categoryId: "transport",
        dayOffset: 0,
        dayPart: "morning",
      },
    ],
    forbidNoteIncludes: ["ульяной", "ульяна"],
  },
  {
    name: "ivan variant потом/затем + сегодня вечером",
    input:
      "вчера кофе 10 руб потом продукты 25 руб затем сегодня вечером каршеринг 12 руб",
    expect: [
      { amount: 10, categoryId: "food", dayOffset: -1 },
      { amount: 25, categoryId: "food", dayOffset: -1 },
      {
        amount: 12,
        categoryId: "transport",
        dayOffset: 0,
        dayPart: "evening",
      },
    ],
  },
  {
    name: "subscription alone → recurring monthly",
    input: "оплатил подписку Яндекс Music три доллара",
    expect: [
      {
        amount: 3,
        currency: "usd",
        categoryId: "subscriptions",
        frequency: "monthly",
        subscriptionBrand: "yandex_music",
      },
    ],
  },
  {
    name: "ivan europe EUR session + explicit USD",
    input:
      "нахожусь в европе и моя валюта евро: продукты 30 евро, подписка 3 доллара эпл мьюзик были вчера и сегодня 30 евро на такси",
    expect: [
      { amount: 30, currency: "eur", categoryId: "food", dayOffset: -1 },
      {
        amount: 3,
        currency: "usd",
        categoryId: "subscriptions",
        dayOffset: -1,
        frequency: "monthly",
        subscriptionBrand: "apple_music",
      },
      { amount: 30, currency: "eur", categoryId: "transport", dayOffset: 0 },
    ],
  },
  {
    name: "ivan unicode €/$/£ multi",
    input: "Добавь 15 € за продукты 30 $ за игрушки и 15 £ за цветы",
    expect: [
      { amount: 15, currency: "eur", categoryId: "food", type: "expense" },
      { amount: 30, currency: "usd", categoryId: "other-expense", type: "expense" },
      { amount: 15, currency: "gbp", categoryId: "other-expense", type: "expense" },
    ],
    forbidNoteIncludes: ["£", "фунт", "gbp", "housing"],
  },
  {
    name: "ivan delivery food ≠ freelance + семь долларов",
    input:
      "в рб моя валюта белорусский рубль вчера я оплатил подписку Apple Music семь долларов сегодня утром заказал доставку еды на 15 руб",
    expect: [
      {
        amount: 7,
        currency: "usd",
        categoryId: "subscriptions",
        type: "expense",
        frequency: "monthly",
        dayOffset: -1,
        subscriptionBrand: "apple_music",
      },
      {
        amount: 15,
        currency: "byn",
        categoryId: "food",
        type: "expense",
        dayOffset: 0,
        dayPart: "morning",
      },
    ],
    forbidNoteIncludes: ["вчера", "утром", "я"],
  },
  {
    name: "ivan вечером вчерашнего дня + carshare + delivery",
    input:
      "в рб моя валюта белорусский рубль Вчера я купил на 30 руб продукты утром потом оплатил подписку семь долларов Apple Music и вечером вчерашнего дня зашёл в кофейню потратил 17 руб. сегодня ездил на Каршеринг потратил 30 руб и заказал доставку еды на 15 руб",
    expect: [
      {
        amount: 30,
        currency: "byn",
        categoryId: "food",
        dayOffset: -1,
        dayPart: "morning",
      },
      {
        amount: 7,
        currency: "usd",
        categoryId: "subscriptions",
        frequency: "monthly",
        dayOffset: -1,
        subscriptionBrand: "apple_music",
      },
      {
        amount: 17,
        currency: "byn",
        categoryId: "food",
        dayOffset: -1,
        dayPart: "evening",
        // Short venue note only — no «мы зашли» / «потратил» filler.
        note: "кофейню",
      },
      {
        amount: 30,
        currency: "byn",
        categoryId: "transport",
        dayOffset: 0,
      },
      {
        amount: 15,
        currency: "byn",
        categoryId: "food",
        dayOffset: 0,
        type: "expense",
        note: "",
      },
    ],
    forbidNoteIncludes: [
      "housing",
      "вчерашнего",
      "дня",
      "зашёл",
      "зашел",
      "зашли",
      "потратил",
      "мы",
      "ездил",
      "Ульяной",
      "ульяной",
    ],
  },
  {
    name: "ivan weekday пт/сб amounts ≠ all сегодня",
    input: "в пятницу кофе 10 руб в субботу такси 20 руб",
    expect: [
      { amount: 10, categoryId: "food", dayOffset: offsetToWeekday(6) },
      { amount: 20, categoryId: "transport", dayOffset: offsetToWeekday(7) },
    ],
  },
  {
    name: "ivan weekday abbr пн–чт",
    input: "в пн продукты 15 руб во вт бензин 30 руб в ср такси 8 руб в чт кофе 5 руб",
    expect: [
      { amount: 15, categoryId: "food", dayOffset: offsetToWeekday(2) },
      { amount: 30, categoryId: "transport", dayOffset: offsetToWeekday(3) },
      { amount: 8, categoryId: "transport", dayOffset: offsetToWeekday(4) },
      { amount: 5, categoryId: "food", dayOffset: offsetToWeekday(5) },
    ],
  },
  {
    name: "ivan meal+fuel+salon+sub narrative",
    input:
      "привет ещё так сходил поесть на 25 руб потом заправила машину на 50 руб затем в салоне 1200 руб и оплатил подписку на программу 5 долларов",
    expect: [
      { amount: 25, categoryId: "food", type: "expense" },
      { amount: 50, categoryId: "transport", type: "expense" },
      { amount: 1200, categoryId: "beauty", type: "expense" },
      {
        amount: 5,
        currency: "usd",
        categoryId: "subscriptions",
        frequency: "monthly",
      },
    ],
    forbidNoteIncludes: ["привет", "ещё", "еще", "так", "сходил", "заправила", "housing"],
  },
];

// Delivery cue + filler unit checks (Cyrillic endings; note strip).
{
  const bugs = [];
  if (!isFoodDelivery("заказал доставку еды на 15 руб")) {
    bugs.push("isFoodDelivery Cyrillic доставку");
  }
  if (!isFoodDelivery("доставка еды")) bugs.push("isFoodDelivery доставка еды");
  if (!isFoodDelivery("food order")) bugs.push("isFoodDelivery food order");
  if (!isFoodMeal("сходил поесть")) bugs.push("isFoodMeal сходил поесть");
  if (!isFuelExpense("заправила машину")) bugs.push("isFuelExpense заправила");
  if (!isBeautySalon("салон")) bugs.push("isBeautySalon салон");
  const cafe = parse("вечером вчерашнего дня зашёл в кофейню потратил 17 руб");
  if (cafe.categoryId !== "food") bugs.push(`cafe cat ${cafe.categoryId}`);
  if (normalize(cafe.note) !== normalize("кофейню")) {
    bugs.push(`cafe note «${cafe.note}» expected «кофейню»`);
  }
  for (const bad of ["зашёл", "зашел", "потратил", "мы зашли"]) {
    if (normalize(cafe.note).includes(normalize(bad))) {
      bugs.push(`cafe note still has «${bad}»`);
    }
  }
  const del = parse("заказал доставку еды на 15 руб");
  if (del.categoryId !== "food") bugs.push(`delivery cat ${del.categoryId} ≠ food`);
  if (normalize(del.note) !== "") bugs.push(`delivery note «${del.note}» not short`);
  // Weekday anchors — пт ≠ today unless today is Friday.
  const fri = detectDateAnchor("в пятницу кофе 10");
  if (fri?.offset !== offsetToWeekday(6)) {
    bugs.push(`пятницу offset ${fri?.offset} expected ${offsetToWeekday(6)}`);
  }
  const sat = detectDateAnchor("в субботу такси 20");
  if (sat?.offset !== offsetToWeekday(7)) {
    bugs.push(`субботу offset ${sat?.offset} expected ${offsetToWeekday(7)}`);
  }
  // Blind-fallback trap: without delivery force, empty keywords → housing.
  const ok = bugs.length === 0;
  if (!ok) failed += 1;
  results.push({ name: "delivery/filler unit checks", ok, bugs });
  console.log(`${ok ? "PASS" : "FAIL"}  delivery/filler unit checks`);
  if (!ok) for (const b of bugs) console.log(`      - ${b}`);
}

// Session cue unit checks (per-utterance; no cross-utterance leak).
{
  const bugs = [];
  if (detectSessionCurrency("моя валюта белорусский рубль") !== "byn") {
    bugs.push("BYN cue");
  }
  if (detectSessionCurrency("нахожусь в европе и моя валюта евро") !== "eur") {
    bugs.push("EUR cue");
  }
  if (detectSessionCurrency("моя валюта евро") !== "eur") {
    bugs.push("валюта евро");
  }
  // Bare «моя валюта» must NOT stamp BYN.
  if (detectSessionCurrency("моя валюта") !== null) {
    bugs.push("bare моя валюта must be null");
  }
  // Sequence: prior BYN utterance must not affect next EUR parse (per-utterance extract).
  const bynDrafts = parseMany(
    "в рб моя валюта белорусский рубль кофе 10 руб"
  );
  const eurDrafts = parseMany(
    "нахожусь в европе и моя валюта евро продукты 30 евро"
  );
  if (bynDrafts[0]?.currency !== "byn") bugs.push("seq BYN");
  if (eurDrafts[0]?.currency !== "eur") {
    bugs.push(`seq EUR got ${eurDrafts[0]?.currency}`);
  }
  const ok = bugs.length === 0;
  if (!ok) failed += 1;
  results.push({ name: "session currency cues + no leak", ok, bugs });
  console.log(`${ok ? "PASS" : "FAIL"}  session currency cues + no leak`);
  if (!ok) for (const b of bugs) console.log(`      - ${b}`);
}

let multiChecked = 0;
for (const c of multiCases) {
  multiChecked += 1;
  const drafts = parseMany(c.input);
  const bugs = [];
  if (drafts.length !== c.expect.length) {
    bugs.push(`count ${drafts.length} expected ${c.expect.length}`);
  }
  const n = Math.min(drafts.length, c.expect.length);
  for (let i = 0; i < n; i++) {
    const d = drafts[i];
    const e = c.expect[i];
    if (e.amount !== undefined && d.amount !== e.amount) {
      bugs.push(`[${i}] amount got ${d.amount} expected ${e.amount}`);
    }
    if (e.categoryId && d.categoryId !== e.categoryId) {
      bugs.push(`[${i}] category got ${d.categoryId} expected ${e.categoryId}`);
    }
    if (Object.prototype.hasOwnProperty.call(e, "currency") && d.currency !== e.currency) {
      bugs.push(`[${i}] currency got ${d.currency} expected ${e.currency}`);
    }
    if (Object.prototype.hasOwnProperty.call(e, "dayOffset") && d.dayOffset !== e.dayOffset) {
      bugs.push(`[${i}] dayOffset got ${d.dayOffset} expected ${e.dayOffset}`);
    }
    if (Object.prototype.hasOwnProperty.call(e, "dayPart") && d.dayPart !== e.dayPart) {
      bugs.push(`[${i}] dayPart got ${d.dayPart} expected ${e.dayPart}`);
    }
    if (Object.prototype.hasOwnProperty.call(e, "frequency") && d.frequency !== e.frequency) {
      bugs.push(`[${i}] frequency got ${d.frequency} expected ${e.frequency}`);
    }
    if (Object.prototype.hasOwnProperty.call(e, "type") && d.type !== e.type) {
      bugs.push(`[${i}] type got ${d.type} expected ${e.type}`);
    }
    if (
      Object.prototype.hasOwnProperty.call(e, "subscriptionBrand") &&
      d.subscriptionBrand !== e.subscriptionBrand
    ) {
      bugs.push(
        `[${i}] brand got ${d.subscriptionBrand} expected ${e.subscriptionBrand}`
      );
    }
    if (Object.prototype.hasOwnProperty.call(e, "note") && normalize(d.note) !== normalize(e.note)) {
      bugs.push(`[${i}] note got «${d.note}» expected «${e.note}»`);
    }
  }
  if (c.forbidNoteIncludes) {
    for (const d of drafts) {
      const noteNorm = normalize(d.note);
      const noteTokens = new Set(noteNorm.split(/\s+/).filter(Boolean));
      for (const bad of c.forbidNoteIncludes) {
        const b = normalize(bad);
        if (!b) continue;
        const hit = b.length <= 2 ? noteTokens.has(b) : noteNorm.includes(b);
        if (hit) bugs.push(`note leaked «${bad}»: «${d.note}»`);
      }
    }
  }
  const ok = bugs.length === 0;
  if (!ok) failed += 1;
  results.push({ name: c.name, ok, draft: drafts, bugs });
  console.log(`${ok ? "PASS" : "FAIL"}  ${c.name}`);
  if (!ok) {
    console.log(`      drafts: ${JSON.stringify(drafts)}`);
    for (const b of bugs) console.log(`      - ${b}`);
  }
}

console.log("\n---");
console.log(
  `Total: ${results.length}, passed: ${results.length - failed}, failed: ${failed} (incl. ${multiChecked} multi)`
);
if (failed > 0) {
  process.exit(1);
}
console.log("Self-test gate PASSED (logic).");
console.log("BLOCKER: No Xcode/Simulator on this Linux VM — device UI scenarios not executed.");
process.exit(0);
