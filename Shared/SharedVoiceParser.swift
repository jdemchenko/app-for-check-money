import Foundation

struct SharedVoiceDraft: Equatable {
    var amount: Double?
    var typeRaw: String?
    var categoryId: String?
    var note: String
    var rawText: String
    /// True when a category keyword actually matched (not a blind fallback).
    var categoryMatchedByKeyword: Bool
    /// Explicit foreign currency from speech (USD/EUR/…).
    /// `nil` when the user said «руб» / bare amount — use entry default (BYN).
    /// Session «в рб» / белорусский stamps `byn` for bare «руб».
    var currencyRaw: String?
    /// `weekly` / `monthly` when speech asked for a recurring rule; otherwise `nil`.
    var frequencyRaw: String?
    /// Calendar day offset vs today: `0` today, `-1` yesterday, `nil` = unspecified.
    var dayOffset: Int?
    /// Optional part of day from speech: `morning` / `evening`.
    var dayPart: String?
    /// Detected subscription brand id (`apple_music`, `spotify`, …) for confirm UI.
    var subscriptionBrandRaw: String?

    /// Happy-path autosave: amount + keyword category, not recurring.
    var isAutosaveReady: Bool {
        guard frequencyRaw == nil else { return false }
        guard let amount, amount > 0 else { return false }
        return categoryMatchedByKeyword && categoryId != nil
    }

    var isRecurring: Bool { frequencyRaw != nil }
}

enum SharedVoiceParser {
    /// Unicode-safe token boundary (JS `\b` breaks on Cyrillic).
    private static let wb = #"(?<![0-9A-Za-zА-Яа-яЁё])"#
    private static let wa = #"(?![0-9A-Za-zА-Яа-яЁё])"#

    private static let expenseCues = try! NSRegularExpression(
        pattern: wb + #"(spent|spend|paid|pay|bought|buy|потратил|потратила|потрачено|оплатил|оплатила|купил|купила|заказал|заказала|расход|закинул|закинула|пополнил|пополнила|добавь|добавьте|добавить|итого)"# + wa,
        options: [.caseInsensitive]
    )
    private static let incomeCues = try! NSRegularExpression(
        pattern: wb + #"(got|received|earned|salary|income|получил|получила|зарплат[аыуеой]|доход|заработал|заработала)"# + wa,
        options: [.caseInsensitive]
    )

    /// Any currency *token* (amount unit or commodity mention).
    /// Includes «белорусских рублей» (бел… + руб with letters between).
    private static let currencyTokenPattern =
        #"(руб(?:л(?:ей|я|ь|ями)?)?|rubles?|byn|br|белорусск(?:их|ий|ого|ом|ими)?\s+руб(?:л(?:ей|я|ь|ями)?)?|бел(?:\.?\s*)?руб(?:л(?:ей|я|ь)?)?|dollars?|usd|eur|gbp|доллар(?:ов|а|ы)?|евро|фунт(?:ов|а|ы|ами|е|ом)?(?:\s+стерлинг\w*)?|pounds?|₽|\$|€|£)"#

    /// Currency words stripped from notes only when they were the **amount unit**.
    private static let currencyWords = try! NSRegularExpression(
        pattern: #"(?i)"# + wb + currencyTokenPattern + wa,
        options: []
    )

    /// Amount digit/decimal, optionally glued thousands with spaces.
    private static let amountNumberPattern = #"(\d+(?:\s+\d{3})*(?:[.,]\d{1,2})?)"#

    /// «покупка долларов», «купил доллары», «bought dollars» — commodity, not tx currency.
    private static let commodityCurrency = try! NSRegularExpression(
        pattern: #"(?i)"# + wb
            + #"(?:покупк[ауие]|купил[аи]?|bought|buying|purchase[sd]?|buy)"#
            + #"\s+"#
            + currencyTokenPattern
            + wa,
        options: []
    )

    private static let leftoverPrepositions = try! NSRegularExpression(
        pattern: #"(?i)"# + wb + #"(на|за|для|про|из|от|по|и|a|an|the|for|on|at|to|of)"# + wa,
        options: []
    )

    private static let noteCommands: [String] = [
        #"(?i)в\s+скобочк(?:ах|и)\s+напиши\s*[,:\-]?\s*(.+)$"#,
        #"(?i)в\s+скобках\s+напиши\s*[,:\-]?\s*(.+)$"#,
        #"(?i)в\s+скобочк(?:ах|и)\s*[,:\-]?\s*(.+)$"#,
        #"(?i)в\s+скобках\s*[,:\-]?\s*(.+)$"#,
        #"(?i)(?:заметка|комментарий|note|comment)\s*[,:\-]?\s*(.+)$"#,
        #"(?i)напиши\s*[,:\-]?\s*(.+)$"#,
        #"(?i)write\s+(?:down\s+)?(.+)$"#,
        #"(?i)in\s+parentheses\s*[,:\-]?\s*(.+)$"#,
    ]

    private static let fillerWords = try! NSRegularExpression(
        pattern: #"(?i)\b(пожалуйста|please|точка|point|ээ+|эм+|hmm+|uh+|um+)\b"#,
        options: []
    )

    /// Recurring cues — monthly first (longer phrases before shorter).
    private static let monthlyRecurring = try! NSRegularExpression(
        pattern: #"(?i)"# + wb
            + #"(every\s+month|each\s+month|monthly|per\s+month|раз\s+в\s+месяц|каждый\s+месяц|каждую\s+месяц|ежемесячно|раз\s+в\s+мес)"#
            + wa,
        options: []
    )
    private static let weeklyRecurring = try! NSRegularExpression(
        pattern: #"(?i)"# + wb
            + #"(every\s+week|each\s+week|weekly|per\s+week|раз\s+в\s+недел[юи]|каждую\s+неделю|каждый\s+недел[юи]|еженедельно)"#
            + wa,
        options: []
    )

    /// Currency unit after a digit — used to find amount boundaries without «и»/comma.
    private static let amountCurrencyUnit =
        #"(?:₽|\$|€|£|руб(?:л(?:ей|я|ь|ями)?)?|rubles?|byn|br|dollars?|usd|eur|gbp|доллар(?:ов|а|ы)?|евро|фунт(?:ов|а|ы|ами|е|ом)?|pounds?)"#

    /// Amount+unit spans for «15 € … 30 $ …» splitting (keeps category words with each amount).
    private static let amountSpan = try! NSRegularExpression(
        pattern: #"(?i)\d+(?:[.,]\d{1,2})?\s*"# + amountCurrencyUnit
            + #"|"# + amountCurrencyUnit + #"\s*\d+(?:[.,]\d{1,2})?"#,
        options: []
    )

    /// Split multi-expense utterances: «кофе 5 и такси 12», «coffee 5 and taxi 12».
    private static let multiSplit = try! NSRegularExpression(
        pattern: #"(?i)(?:,\s*|\s+и\s+|\s+and\s+)(?=(?:[^0-9]{0,40})?\d)"#,
        options: []
    )

    /// Narrative clause boundaries: потом / затем / оплатил / заказал / date / weekday anchors.
    /// Use `wa` (not JS/`\b`) so Cyrillic tokens match.
    private static let narrativeSplit = try! NSRegularExpression(
        pattern: #"(?i)(?:\s+потом\s+|\s+затем\s+|\s+после\s+(?:этого|того)\s+|(?<=[\p{L}\d.])\s+(?=оплатил[аи]?"# + wa + #")|(?<=[\p{L}\d.])\s+(?=заказал[аи]?"# + wa + #")|(?<=[\p{L}\d.])\s+(?=утром"# + wa + #")|(?<=[\p{L}\d.])\s+(?=вечером"# + wa + #")|(?<=[\p{L}\d.])\s+(?=сегодня"# + wa + #")|(?<=[\p{L}\d.])\s+(?=вчера"# + wa + #")|(?<=[\p{L}\d.])\s+(?=позавчера"# + wa + #")|(?<=[\p{L}\d.])\s+(?=во?\s+(?:понедельник|вторник|сред[ауеы]|четверг|пятниц[уыае]|суббот[уыае]|воскресень[еяю]|пн|вт|ср|чт|пт|сб|вс)"# + wa + #")|(?<=[\p{L}\d.])\s+(?=(?:понедельник|вторник|сред[ауеы]|четверг|пятниц[уыае]|суббот[уыае]|воскресень[еяю])"# + wa + #"))"#,
        options: []
    )

    /// Letters for stems — NSRegularExpression `\w` is ASCII-only, so Cyrillic endings need this.
    private static let letter = #"[а-яёА-ЯЁa-zA-Z]"#

    /// Food-delivery / food-order cue — always Еда, never housing/freelance.
    /// Must match «доставку еды» / «заказал доставку» (Cyrillic endings).
    private static let foodDeliveryCue = try! NSRegularExpression(
        pattern: #"(?i)"# + wb
            + #"(?:доставк\#(letter)*\s+ед\#(letter)*|ед\#(letter)*\s+доставк\#(letter)*|заказ\#(letter)*\s+(?:доставк\#(letter)*|ед\#(letter)*)|order(?:ed)?\s+food|food\s+order|food\s+delivery|delivery\s+food|доставк\#(letter)*)"#
            + wa,
        options: []
    )

    /// Meal / eating cue — «поесть», «сходил поесть» → Еда (never housing).
    private static let foodMealCue = try! NSRegularExpression(
        pattern: #"(?i)"# + wb
            + #"(?:поесть|поел[аи]?|поем|поедим|поужина\#(letter)*|пообеда\#(letter)*|обеда\#(letter)*|ужина\#(letter)*|завтрака\#(letter)*|сходил[аи]?\s+поесть|ходили\s+поесть|went\s+(?:to\s+)?(?:eat|lunch|dinner)|had\s+(?:lunch|dinner|breakfast))"#
            + wa,
        options: []
    )

    /// Fuel / car fill-up — «заправила машину» → Транспорт (never housing).
    private static let fuelCue = try! NSRegularExpression(
        pattern: #"(?i)"# + wb
            + #"(?:заправ\#(letter)*|бензин\#(letter)*|топлив\#(letter)*|дизел\#(letter)*|азс|gas\s*station|petrol|diesel|fuel(?:ed|ling)?|заправ\#(letter)*\s+машин\#(letter)*|машин\#(letter)*\s+заправ\#(letter)*)"#
            + wa,
        options: []
    )

    /// Beauty salon — «салон» → Красота (never Еда / housing).
    private static let beautySalonCue = try! NSRegularExpression(
        pattern: #"(?i)"# + wb
            + #"(?:салон\#(letter)*|salon|маникюр\#(letter)*|педикюр\#(letter)*|парикмахер\#(letter)*|стрижк\#(letter)*|beauty\s*salon)"#
            + wa,
        options: []
    )

    /// Narrative filler stripped from notes («мы зашли», «потратил», «ещё/так/привет»…).
    private static let noteNarrativeFiller = try! NSRegularExpression(
        pattern: #"(?i)"# + wb
            + #"(?:мы\s+)?(?:зашли|зашёл|зашел|зашла|зайти)\s+в"#
            + #"|"# + wb + #"(?:мы\s+)?(?:зашли|зашёл|зашел|зашла)"#
            + #"|"# + wb + #"(?:потратил\#(letter)*|потрачено|ездил\#(letter)*|попил\#(letter)*|купил\#(letter)*|оплатил\#(letter)*|сходил\#(letter)*|ходил\#(letter)*)"#
            + #"|"# + wb + #"(?:ещё|еще|так|привет|слушай|короче|типа|ну)"#
            + wa,
        options: []
    )

    /// Session cues — matched **in order** (EUR / USD before BYN). Bare «моя валюта» alone is NOT BYN.
    private static let sessionEUR = try! NSRegularExpression(
        pattern: #"(?i)"# + wb
            + #"(?:моя\s+валюта\s+евро|валюта\s+евро|в\s+европ\w*|в\s+еврозоне|europe|eurozone|(?:default|entry)\s+eur)"#
            + wa,
        options: []
    )
    private static let sessionUSD = try! NSRegularExpression(
        pattern: #"(?i)"# + wb
            + #"(?:моя\s+валюта\s+(?:доллар\w*|usd)|валюта\s+(?:доллар\w*|usd)|в\s+сша|in\s+the\s+usa|(?:default|entry)\s+usd)"#
            + wa,
        options: []
    )
    private static let sessionBYN = try! NSRegularExpression(
        pattern: #"(?i)"# + wb
            + #"(?:моя\s+валюта\s+(?:бел\w*|byn|br|руб\w*)|валюта\s+(?:бел\w*|byn|br)|в\s+рб|белорусск\w*|бел\.?\s*руб|byn\b|br\b)"#
            + wa,
        options: []
    )

    private static let companionStrip = try! NSRegularExpression(
        pattern: #"(?i)"# + wb
            + #"(?:вместе\s+)?с\s+[А-ЯЁа-яё][а-яёА-Яа-яЁё]{1,40}"#
            + wa,
        options: []
    )

    private static let subscriptionCue = try! NSRegularExpression(
        pattern: #"(?i)"# + wb
            + #"(?:подписк\#(letter)*(?:\s+(?:на\s+)?(?:программ\#(letter)*|сервис\#(letter)*|приложен\#(letter)*))?|subscription|netflix|spotify|яндекс\s*(?:music|plus|плюс|музык\w*)|yandex\s*(?:music|plus)|apple\s*music|\bapple\b|эпл\s*мьюзик|эппл\s*мьюзик|эпл\s*music|youtube\s*premium|youtube\s*music)"#
            + wa,
        options: []
    )

    /// Brand detectors — longer / more specific first.
    private static let subscriptionBrands: [(id: String, pattern: NSRegularExpression)] = [
        ("apple_music", try! NSRegularExpression(
            pattern: #"(?i)"# + wb + #"(?:apple\s*music|эпл\s*мьюзик|эппл\s*мьюзик|эпл\s*music)"# + wa, options: []
        )),
        ("youtube_premium", try! NSRegularExpression(
            pattern: #"(?i)"# + wb + #"(?:youtube\s*premium|youtube\s*music|ютюб\s*премиум|ютуб\s*премиум)"# + wa, options: []
        )),
        ("yandex_music", try! NSRegularExpression(
            pattern: #"(?i)"# + wb + #"(?:яндекс\s*music|yandex\s*music|яндекс\s*музык\w*)"# + wa, options: []
        )),
        ("yandex_plus", try! NSRegularExpression(
            pattern: #"(?i)"# + wb + #"(?:яндекс\s*(?:plus|плюс)|yandex\s*plus)"# + wa, options: []
        )),
        ("netflix", try! NSRegularExpression(
            pattern: #"(?i)"# + wb + #"netflix"# + wa, options: []
        )),
        ("spotify", try! NSRegularExpression(
            pattern: #"(?i)"# + wb + #"spotify"# + wa, options: []
        )),
        ("apple_music", try! NSRegularExpression(
            // Bare «Apple» near подписк* — last resort after Music-specific patterns.
            pattern: #"(?i)"# + wb + #"apple"# + wa, options: []
        )),
    ]

    private static let dateYesterday = try! NSRegularExpression(
        pattern: #"(?i)"# + wb + #"вчера"# + wa, options: []
    )
    /// «вечером вчерашнего дня» / «вчерашний вечер».
    private static let dateYesterdayGenitive = try! NSRegularExpression(
        pattern: #"(?i)"# + wb
            + #"(?:вечером\s+вчерашнего(?:\s+дня)?|утром\s+вчерашнего(?:\s+дня)?|вчерашн(?:его|ий|яя|ее|им)\s+(?:дня|день|вечер\w*|утр\w*))"#
            + wa,
        options: []
    )
    private static let dateDayBefore = try! NSRegularExpression(
        pattern: #"(?i)"# + wb + #"позавчера"# + wa, options: []
    )
    private static let dateToday = try! NSRegularExpression(
        pattern: #"(?i)"# + wb + #"сегодня"# + wa, options: []
    )
    private static let dayPartMorning = try! NSRegularExpression(
        pattern: #"(?i)"# + wb + #"(?:утром|с\s+утра|morning)"# + wa, options: []
    )
    private static let dayPartEvening = try! NSRegularExpression(
        pattern: #"(?i)"# + wb + #"(?:вечером|evening|tonight)"# + wa, options: []
    )

    /// Gregorian `weekday` (1=Sun … 7=Sat) → RU weekday / abbr patterns.
    private static let weekdayCues: [(weekday: Int, pattern: NSRegularExpression)] = [
        (2, try! NSRegularExpression(
            pattern: #"(?i)"# + wb + #"(?:понедельн\#(letter)*|пн)"# + wa, options: []
        )),
        (3, try! NSRegularExpression(
            pattern: #"(?i)"# + wb + #"(?:вторник\#(letter)*|вт)"# + wa, options: []
        )),
        (4, try! NSRegularExpression(
            pattern: #"(?i)"# + wb + #"(?:сред[аеуы]|ср)"# + wa, options: []
        )),
        (5, try! NSRegularExpression(
            pattern: #"(?i)"# + wb + #"(?:четверг\#(letter)*|чт)"# + wa, options: []
        )),
        (6, try! NSRegularExpression(
            pattern: #"(?i)"# + wb + #"(?:пятниц\#(letter)*|пт)"# + wa, options: []
        )),
        (7, try! NSRegularExpression(
            pattern: #"(?i)"# + wb + #"(?:суббот\#(letter)*|сб)"# + wa, options: []
        )),
        (1, try! NSRegularExpression(
            pattern: #"(?i)"# + wb + #"(?:воскресень\#(letter)*|вс)"# + wa, options: []
        )),
    ]

    /// Category-signal words that must never become a stored note by themselves.
    private static let noteSuppress: Set<String> = Set([
        // Food signals (not venue details)
        "еда", "food", "продукт", "продукты", "grocery", "groceries", "кофе",
        "coffee", "обед", "lunch", "ужин", "dinner", "завтрак", "breakfast",
        "пицца", "pizza", "бургер", "burger", "снек", "snack", "ресторан",
        "restaurant", "кафе", "cafe", "столовая", "супермаркет", "supermarket",
        // Transport / fuel signals
        "транспорт", "transport", "азс", "azs", "заправка", "бензин", "топливо",
        "gas", "fuel", "petrol", "diesel", "дизель", "gas station", "petrol station",
        "такси", "taxi", "метро", "metro", "subway", "автобус", "bus", "парковка",
        "parking", "station", "uber", "яндекс", "yandex", "поезд", "train",
        // Other category labels / signals
        // Category *labels* only — keep descriptive phrases (аренда квартиры, проезд…) as notes.
        "жильё", "жилье", "housing",
        "еда", "food", "продукты",
        "транспорт", "transport",
        "здоровье", "health",
        "одежда", "clothing", "clothes",
        "развлечения", "entertainment",
        "связь", "техника",
        "накопления", "savings",
        "другое", "other", "разное", "misc",
        "зарплата", "зарплату", "зарплаты", "salary", "зп", "оклад", "wage",
        "paycheck", "аванс",
        "фриланс", "freelance",
        "подарок", "подарки", "gift", "gifts",
        "доход", "income", "перевод", "transfer", "возврат", "refund",
        // Amount-unit руб only — keep «долларов» / «dollars» when they are what was bought.
        "рублей", "рубль", "рубля", "ruble", "rubles", "byn", "br",
        "копеек", "копейки", "копейка",
        "косметика", "cosmetics", "красота", "beauty",
        "категория", "category",
        "на", "за", "для", "и", "я", "получил", "получила", "потратил", "потратила",
        "закинул", "закинула", "пополнил", "купил", "купила", "заказал", "заказала",
        "добавь", "кажется",
        "сегодня", "вчера", "позавчера", "утром", "вечером",
        "вчерашнего", "вчерашний", "дня", "день",
        "это", "будет", "свой", "свою",
        "got", "received", "spent", "paid", "bought", "ordered",
        "зашёл", "зашла", "зашел", "зашли", "мы", "попил", "попила",
        "ездил", "ездила", "в",
        "ещё", "еще", "так", "привет", "слушай", "короче", "типа", "ну",
        "сходил", "сходила", "ходил", "ходила", "поесть", "поел", "поела",
        "заправила", "заправил", "заправка", "машину", "машина",
        "понедельник", "вторник", "среда", "среду", "четверг", "пятница", "пятницу",
        "суббота", "субботу", "воскресенье", "пн", "вт", "ср", "чт", "пт", "сб", "вс",
        "салон", "подписку", "подписка", "программу", "программа",
        // Delivery stems — category signal, not a stored note
        "доставка", "доставку", "доставк", "еды", "еду", "едой", "delivery",
        // NOTE: keep «аренда квартиры», «проезд», «телефон», «долларов» OUT — descriptions
    ].map { TextNormalizer.normalize($0) })

    static func parseAmount(from text: String) -> Double? {
        if let fromWords = AmountWords.parse(from: text) {
            return fromWords
        }
        var cleaned = text
        cleaned = cleaned.replacingOccurrences(
            of: #"(\d)\s+(\d{3})\b"#,
            with: "$1$2",
            options: .regularExpression
        )
        cleaned = cleaned.replacingOccurrences(of: ",", with: ".")

        let patterns = [
            #"(?i)(\d+(?:[.,]\d{1,2})?)\s*(?:₽|\$|€|£|руб(?:л(?:ей|я|ь)?)?|rubles?|byn|br|dollars?|usd|eur|gbp|фунт(?:ов|а|ы)?|pounds?)"#,
            #"(?i)(?:₽|\$|€|£|руб(?:л(?:ей|я|ь)?)?|rubles?|byn|br|dollars?|usd|eur|gbp|фунт(?:ов|а|ы)?|pounds?)\s*(\d+(?:[.,]\d{1,2})?)"#,
            #"(\d+(?:[.,]\d{1,2})?)"#,
        ]
        for pattern in patterns {
            if let match = firstCapture(pattern: pattern, in: cleaned) {
                let normalized = match.replacingOccurrences(of: ",", with: ".")
                if let value = Double(normalized), value > 0 {
                    return (value * 100).rounded() / 100
                }
            }
        }
        return nil
    }

    static func inferType(from text: String) -> String? {
        let range = NSRange(text.startIndex..., in: text)
        if incomeCues.firstMatch(in: text, options: [], range: range) != nil {
            return "income"
        }
        if expenseCues.firstMatch(in: text, options: [], range: range) != nil {
            return "expense"
        }
        return nil
    }

    /// Currency for the **amount unit** wins.
    /// «900 рублей, покупка долларов» → `nil` (entry default BYN), not USD from trailing «долларов».
    /// «руб» / «рублей» near the amount → `nil` (never market RUB unless Settings entry is RUB).
    static func inferCurrency(from text: String) -> String? {
        if let attached = currencyAttachedToAmount(in: text) {
            return attached.currencyRaw
        }
        return looseForeignCurrency(in: text)
    }

    /// `nil` app currency means entry default; `found` distinguishes «руб» (resolved) from no unit.
    private struct AmountCurrencyResolve {
        /// `nil` = entry default (руб); non-nil = stamp USD/EUR/BYN.
        let currencyRaw: String?
    }

    /// Currency token glued to the numeric amount (before or after).
    private static func currencyAttachedToAmount(in text: String) -> AmountCurrencyResolve? {
        let patterns = [
            #"(?i)"# + amountNumberPattern + #"\s*"# + currencyTokenPattern,
            #"(?i)"# + currencyTokenPattern + #"\s*"# + amountNumberPattern,
        ]
        let nsRange = NSRange(text.startIndex..., in: text)
        var best: (location: Int, token: String)?
        for pattern in patterns {
            guard let re = try? NSRegularExpression(pattern: pattern, options: []) else { continue }
            for match in re.matches(in: text, options: [], range: nsRange) {
                // Token is group 2 in amount→currency, group 1 in currency→amount.
                let tokenRange: NSRange
                if match.numberOfRanges >= 3 {
                    // Both patterns have 2 captures; detect which group is the currency token.
                    let g1 = Range(match.range(at: 1), in: text).map { String(text[$0]) } ?? ""
                    let g2 = Range(match.range(at: 2), in: text).map { String(text[$0]) } ?? ""
                    let token: String
                    if looksLikeCurrencyToken(g1) {
                        token = g1
                        tokenRange = match.range(at: 1)
                    } else {
                        token = g2
                        tokenRange = match.range(at: 2)
                    }
                    _ = tokenRange
                    let loc = match.range.location
                    if best == nil || loc < best!.location {
                        best = (loc, token)
                    }
                }
            }
        }
        // Spelled amount + unit: «тысяча … рублей» (no digits).
        if best == nil, let spelledToken = currencyAfterSpelledAmount(in: text) {
            return resolveCurrencyToken(spelledToken)
        }
        guard let token = best?.token else { return nil }
        return resolveCurrencyToken(token)
    }

    private static func currencyAfterSpelledAmount(in text: String) -> String? {
        // If AmountWords finds a spelled amount, take the first currency token after number-words start.
        guard AmountWords.parse(from: text) != nil else { return nil }
        // Prefer «… рублей/dollars» when digits are absent near the unit.
        let hasDigitAmount = text.range(of: #"\d"#, options: .regularExpression) != nil
        if hasDigitAmount { return nil }
        let re = try! NSRegularExpression(
            pattern: #"(?i)"# + wb + currencyTokenPattern + wa,
            options: []
        )
        let range = NSRange(text.startIndex..., in: text)
        guard let match = re.firstMatch(in: text, options: [], range: range),
              let swift = Range(match.range, in: text)
        else { return nil }
        return String(text[swift])
    }

    private static func looksLikeCurrencyToken(_ s: String) -> Bool {
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if t.isEmpty { return false }
        if t.range(of: #"^\d"#, options: .regularExpression) != nil { return false }
        return true
    }

    private static func resolveCurrencyToken(_ raw: String) -> AmountCurrencyResolve {
        // Map symbols before normalize — TextNormalizer strips €/$/£/₽.
        var t = raw
            .replacingOccurrences(of: "$", with: " usd ")
            .replacingOccurrences(of: "€", with: " eur ")
            .replacingOccurrences(of: "£", with: " gbp ")
            .replacingOccurrences(of: "₽", with: " rub ")
        t = TextNormalizer.normalize(t)
        if t.contains("dollar") || t == "usd" || t.hasPrefix("доллар") || t.split(separator: " ").contains("usd") {
            return AmountCurrencyResolve(currencyRaw: "usd")
        }
        if t.contains("euro") || t == "eur" || t.hasPrefix("евро") || t.split(separator: " ").contains("eur") {
            return AmountCurrencyResolve(currencyRaw: "eur")
        }
        if t.contains("pound") || t == "gbp" || t.hasPrefix("фунт") || t.contains("стерлинг")
            || t.split(separator: " ").contains("gbp") {
            return AmountCurrencyResolve(currencyRaw: "gbp")
        }
        if t == "byn" || t == "br" || t.contains("бел") || t.contains("белорус") {
            return AmountCurrencyResolve(currencyRaw: "byn")
        }
        // «руб» / «рублей» / ruble → entry default (BYN), not market RUB
        return AmountCurrencyResolve(currencyRaw: nil)
    }

    /// Foreign currency mentioned when the amount had **no** unit — ignore commodity phrases.
    private static func looseForeignCurrency(in text: String) -> String? {
        var working = text
        let full = NSRange(working.startIndex..., in: working)
        working = commodityCurrency.stringByReplacingMatches(
            in: working,
            options: [],
            range: full,
            withTemplate: " "
        )
        let range = NSRange(working.startIndex..., in: working)
        let usd = try! NSRegularExpression(
            pattern: #"(?i)"# + wb + #"(dollars?|usd|доллар(?:ов|а|ы)?|\$)"# + wa,
            options: []
        )
        let eur = try! NSRegularExpression(
            pattern: #"(?i)"# + wb + #"(euros?|eur|евро|€)"# + wa,
            options: []
        )
        let gbp = try! NSRegularExpression(
            pattern: #"(?i)"# + wb + #"(pounds?|gbp|фунт(?:ов|а|ы|ами|е|ом)?(?:\s+стерлинг\w*)?|£)"# + wa,
            options: []
        )
        let byn = try! NSRegularExpression(
            pattern: #"(?i)"# + wb + #"(byn|br|белорусск\w*|бел(?:\.?\s*)?руб(?:л(?:ей|я|ь)?)?)"# + wa,
            options: []
        )
        if usd.firstMatch(in: working, options: [], range: range) != nil { return "usd" }
        if eur.firstMatch(in: working, options: [], range: range) != nil { return "eur" }
        if gbp.firstMatch(in: working, options: [], range: range) != nil { return "gbp" }
        if byn.firstMatch(in: working, options: [], range: range) != nil { return "byn" }
        return nil
    }

    /// One utterance → one or more drafts. Recurring stays a single draft with `frequencyRaw`
    /// when there is only one amount; long narratives use the clause segmenter.
    static func parseMany(
        rawText: String,
        categories: [SharedCategoryDTO]
    ) -> [SharedVoiceDraft] {
        let trimmed = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        let sessionCurrency = detectSessionCurrency(in: trimmed)
        let cleaned = stripCompanions(trimmed)
        let amountCount = countAmountMentions(in: cleaned)

        // Single-expense recurring («Netflix 10 every month») — keep as one draft.
        if amountCount <= 1, let frequency = detectFrequency(in: cleaned) ?? detectSubscription(in: cleaned) {
            var draft = parse(
                rawText: stripRecurringCues(cleaned),
                categories: categories,
                sessionCurrency: sessionCurrency,
                dayOffset: detectDateAnchor(in: cleaned)?.offset,
                dayPart: detectDateAnchor(in: cleaned)?.part
            )
            draft.frequencyRaw = frequency
            draft.rawText = trimmed
            return [draft]
        }

        let narrative = splitNarrative(cleaned)
        if narrative.count >= 2 {
            let drafts = materializeSegments(
                narrative,
                fullText: cleaned,
                categories: categories,
                sessionCurrency: sessionCurrency
            )
            if drafts.count >= 2 { return drafts }
        }

        let simple = splitMultiExpense(cleaned)
        if simple.count >= 2 {
            let drafts = materializeSegments(
                simple,
                fullText: cleaned,
                categories: categories,
                sessionCurrency: sessionCurrency
            )
            if drafts.count >= 2 { return drafts }
        }

        return [
            parse(
                rawText: cleaned,
                categories: categories,
                sessionCurrency: sessionCurrency,
                dayOffset: detectDateAnchor(in: cleaned)?.offset,
                dayPart: detectDateAnchor(in: cleaned)?.part
            )
        ]
    }

    static func parse(
        rawText: String,
        categories: [SharedCategoryDTO]
    ) -> SharedVoiceDraft {
        parse(
            rawText: rawText,
            categories: categories,
            sessionCurrency: detectSessionCurrency(in: rawText),
            dayOffset: detectDateAnchor(in: rawText)?.offset,
            dayPart: detectDateAnchor(in: rawText)?.part
        )
    }

    static func parse(
        rawText: String,
        categories: [SharedCategoryDTO],
        sessionCurrency: String?,
        dayOffset: Int?,
        dayPart: String?
    ) -> SharedVoiceDraft {
        let brand = detectSubscriptionBrand(in: rawText)
        let subscription = detectSubscription(in: rawText) ?? (brand != nil ? "monthly" : nil)
        let frequency = detectFrequency(in: rawText) ?? subscription
        let working = frequency != nil ? stripRecurringCues(rawText) : rawText

        let amount = parseAmount(from: working)
        var type = inferType(from: working)
        let delivery = isFoodDelivery(in: working) || isFoodDelivery(in: rawText)
        // Delivery / оплатил+подписка are always expenses — never freelance income.
        if delivery || subscription != nil {
            type = "expense"
        }
        // Explicit unit on the amount always wins; session fills bare / ambiguous only.
        var currency = inferCurrency(from: working)
        if currency == nil, let sessionCurrency {
            currency = sessionCurrency
        }

        var matched = SharedCategoryMatcher.autoAssign(
            text: working,
            categories: categories,
            preferredTypeRaw: type
        )
        if matched == nil {
            matched = SharedCategoryMatcher.autoAssign(
                text: working,
                categories: categories,
                preferredTypeRaw: nil
            )
        }

        if type == nil, let matched {
            type = matched.kindRaw == "both" ? "expense" : (
                matched.kindRaw == "income" ? "income" : "expense"
            )
        }
        if delivery || subscription != nil {
            type = "expense"
        }
        if type == nil { type = "expense" }

        // Re-score with final type preference, then unrestricted fallback.
        matched = SharedCategoryMatcher.autoAssign(
            text: working,
            categories: categories,
            preferredTypeRaw: type
        ) ?? SharedCategoryMatcher.autoAssign(
            text: working,
            categories: categories,
            preferredTypeRaw: nil
        )
        let meal = isFoodMeal(in: working) || isFoodMeal(in: rawText)
        let fuel = isFuelExpense(in: working) || isFuelExpense(in: rawText)
        let salon = isBeautySalon(in: working) || isBeautySalon(in: rawText)
        let hasSubCue = subscription != nil || brand != nil

        // Strong cues beat weak / housing misses (salon before meal so «салон» ≠ Еда).
        if salon, let beauty = categories.first(where: { $0.id == "beauty" }) {
            matched = beauty
        } else if delivery || meal, let food = categories.first(where: { $0.id == "food" }) {
            matched = food
        } else if fuel, let transport = categories.first(where: { $0.id == "transport" }) {
            matched = transport
        } else if matched?.id == "housing",
                  (delivery || meal || working.range(
                    of: #"доставк|еды|еду|заказ|поесть|поел"#,
                    options: [.regularExpression, .caseInsensitive]
                  ) != nil),
                  let food = categories.first(where: { $0.id == "food" }) {
            matched = food
        }
        // Any подписк* cue (incl. «подписку на программу» / $ / €) → Подписки, never housing.
        if hasSubCue {
            if let subs = categories.first(where: { $0.id == "subscriptions" }) {
                matched = subs
            } else if brand != nil, let entertainment = categories.first(where: { $0.id == "entertainment" }) {
                matched = entertainment
            }
        }

        let categoryMatchedByKeyword = matched != nil
        // Blind fallback is housing (sort 0) — never use it for meal/fuel/salon/sub/delivery.
        let categoryId: String? = {
            if delivery || meal {
                return matched?.id ?? categories.first(where: { $0.id == "food" })?.id
            }
            if fuel {
                return matched?.id ?? categories.first(where: { $0.id == "transport" })?.id
            }
            if salon {
                return matched?.id ?? categories.first(where: { $0.id == "beauty" })?.id
            }
            if hasSubCue {
                return matched?.id ?? categories.first(where: { $0.id == "subscriptions" })?.id
            }
            return matched?.id
                ?? SharedCategoryMatcher.categories(forRaw: type!, in: categories).first?.id
        }()

        var note = extractNote(
            from: working,
            matchedCategory: matched,
            allCategories: categories
        )
        if let brand, note.isEmpty || note.count < 3 {
            note = SubscriptionBrand.displayName(for: brand)
        } else if let brand {
            // Prefer clean brand label over leftover «подписку долларов …».
            note = SubscriptionBrand.displayName(for: brand)
        }

        return SharedVoiceDraft(
            amount: amount,
            typeRaw: type,
            categoryId: categoryId,
            note: note,
            rawText: rawText,
            categoryMatchedByKeyword: categoryMatchedByKeyword,
            currencyRaw: currency,
            frequencyRaw: frequency,
            dayOffset: dayOffset,
            dayPart: dayPart,
            subscriptionBrandRaw: brand
        )
    }

    // MARK: - Narrative segmenter

    private static func materializeSegments(
        _ segments: [String],
        fullText: String,
        categories: [SharedCategoryDTO],
        sessionCurrency: String?
    ) -> [SharedVoiceDraft] {
        // Date anchors apply forward until the next date cue.
        var activeOffset: Int? = nil
        var activePart: String? = nil
        var drafts: [SharedVoiceDraft] = []

        // Seed day from full text only when an explicit day word is present (вчера/сегодня/…).
        if let preamble = detectDateAnchor(in: fullText), preamble.dayExplicit {
            activeOffset = preamble.offset
            activePart = preamble.part
        }

        for segment in segments {
            if let anchor = detectDateAnchor(in: segment) {
                if anchor.dayExplicit, let offset = anchor.offset {
                    activeOffset = offset
                } else if activeOffset == nil, let offset = anchor.offset {
                    // Bare «утром»/«вечером» → today only when no day is active yet.
                    activeOffset = offset
                }
                // Bare day-part after «вчера» keeps yesterday and only updates morning/evening.
                if let part = anchor.part {
                    activePart = part
                }
            }
            var draft = parse(
                rawText: segment,
                categories: categories,
                sessionCurrency: sessionCurrency,
                dayOffset: activeOffset,
                dayPart: activePart
            )
            guard let amount = draft.amount, amount > 0 else { continue }
            // Prefer segment text as raw; keep subscription frequency / brand if detected.
            if draft.frequencyRaw == nil, let sub = detectSubscription(in: segment) {
                draft.frequencyRaw = sub
            }
            if draft.subscriptionBrandRaw == nil,
               let brand = detectSubscriptionBrand(in: segment) {
                draft.subscriptionBrandRaw = brand
                draft.frequencyRaw = draft.frequencyRaw ?? "monthly"
                draft.note = SubscriptionBrand.displayName(for: brand)
                if let subs = categories.first(where: { $0.id == "subscriptions" }) {
                    draft.categoryId = subs.id
                    draft.categoryMatchedByKeyword = true
                }
            }
            drafts.append(draft)
        }
        return drafts
    }

    /// Per-utterance session default. Explicit amount units always win later in `parse`.
    /// Priority: EUR → USD → BYN. Never treat bare «моя валюта» as BYN.
    static func detectSessionCurrency(in text: String) -> String? {
        let range = NSRange(text.startIndex..., in: text)
        if sessionEUR.firstMatch(in: text, options: [], range: range) != nil {
            return "eur"
        }
        if sessionUSD.firstMatch(in: text, options: [], range: range) != nil {
            return "usd"
        }
        if sessionBYN.firstMatch(in: text, options: [], range: range) != nil {
            return "byn"
        }
        return nil
    }

    static func stripCompanions(_ text: String) -> String {
        let full = NSRange(text.startIndex..., in: text)
        let stripped = companionStrip.stringByReplacingMatches(
            in: text, options: [], range: full, withTemplate: " "
        )
        return stripped
            .replacingOccurrences(of: #"\s{2,}"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func detectSubscription(in text: String) -> String? {
        let range = NSRange(text.startIndex..., in: text)
        if subscriptionCue.firstMatch(in: text, options: [], range: range) != nil {
            return "monthly"
        }
        if detectSubscriptionBrand(in: text) != nil {
            return "monthly"
        }
        return nil
    }

    /// Brand id for confirm UI logos (`apple_music`, `spotify`, …).
    static func detectSubscriptionBrand(in text: String) -> String? {
        let range = NSRange(text.startIndex..., in: text)
        for brand in subscriptionBrands {
            if brand.pattern.firstMatch(in: text, options: [], range: range) != nil {
                return brand.id
            }
        }
        return nil
    }

    /// «доставка еды» / «заказал доставку» — expense food, never freelance.
    static func isFoodDelivery(in text: String) -> Bool {
        let range = NSRange(text.startIndex..., in: text)
        return foodDeliveryCue.firstMatch(in: text, options: [], range: range) != nil
    }

    /// «поесть» / «сходил поесть» — Еда.
    static func isFoodMeal(in text: String) -> Bool {
        let range = NSRange(text.startIndex..., in: text)
        return foodMealCue.firstMatch(in: text, options: [], range: range) != nil
    }

    /// «заправила машину» / АЗС — Транспорт.
    static func isFuelExpense(in text: String) -> Bool {
        let range = NSRange(text.startIndex..., in: text)
        return fuelCue.firstMatch(in: text, options: [], range: range) != nil
    }

    /// «салон» — Красота.
    static func isBeautySalon(in text: String) -> Bool {
        let range = NSRange(text.startIndex..., in: text)
        return beautySalonCue.firstMatch(in: text, options: [], range: range) != nil
    }

    /// Days since the most recent `weekday` (1=Sun…7=Sat), including today → 0.
    static func offsetToWeekday(_ targetWeekday: Int, from date: Date = .now) -> Int {
        let today = Calendar.current.component(.weekday, from: date)
        var delta = today - targetWeekday
        if delta < 0 { delta += 7 }
        return -delta
    }

    struct DateAnchor {
        /// Calendar day offset; `nil` when only a day-part was spoken.
        var offset: Int?
        var part: String?
        /// True when вчера/сегодня/позавчера/вчерашнего was explicit (not bare утром).
        var dayExplicit: Bool
    }

    static func detectDateAnchor(in text: String) -> DateAnchor? {
        let range = NSRange(text.startIndex..., in: text)
        var part: String? = nil
        if dayPartMorning.firstMatch(in: text, options: [], range: range) != nil {
            part = "morning"
        } else if dayPartEvening.firstMatch(in: text, options: [], range: range) != nil {
            part = "evening"
        }

        // «вечером вчерашнего дня» before bare «вчера» / «вечером».
        if dateYesterdayGenitive.firstMatch(in: text, options: [], range: range) != nil {
            if part == nil {
                if text.range(of: #"вечер"#, options: [.regularExpression, .caseInsensitive]) != nil {
                    part = "evening"
                } else if text.range(of: #"утр"#, options: [.regularExpression, .caseInsensitive]) != nil {
                    part = "morning"
                }
            }
            return DateAnchor(offset: -1, part: part, dayExplicit: true)
        }
        if dateDayBefore.firstMatch(in: text, options: [], range: range) != nil {
            return DateAnchor(offset: -2, part: part, dayExplicit: true)
        }
        if dateYesterday.firstMatch(in: text, options: [], range: range) != nil {
            return DateAnchor(offset: -1, part: part, dayExplicit: true)
        }
        if dateToday.firstMatch(in: text, options: [], range: range) != nil {
            return DateAnchor(offset: 0, part: part, dayExplicit: true)
        }
        // Weekdays пн–вс / full names — most recent occurrence (incl. today).
        for cue in weekdayCues {
            if cue.pattern.firstMatch(in: text, options: [], range: range) != nil {
                return DateAnchor(
                    offset: offsetToWeekday(cue.weekday),
                    part: part,
                    dayExplicit: true
                )
            }
        }
        // Bare «утром» / «вечером» — day-part only; materialize keeps prior day when set.
        if part != nil {
            return DateAnchor(offset: 0, part: part, dayExplicit: false)
        }
        return nil
    }

    /// Display names + SF Symbols for subscription brands.
    enum SubscriptionBrand {
        static func displayName(for id: String) -> String {
            switch id {
            case "apple_music": return "Apple Music"
            case "yandex_music": return "Yandex Music"
            case "yandex_plus": return "Yandex Plus"
            case "spotify": return "Spotify"
            case "netflix": return "Netflix"
            case "youtube_premium": return "YouTube Premium"
            default: return id
            }
        }

        static func symbolName(for id: String) -> String {
            switch id {
            case "apple_music": return "applelogo"
            case "yandex_music", "yandex_plus": return "music.note.list"
            case "spotify": return "music.note"
            case "netflix": return "play.tv"
            case "youtube_premium": return "play.rectangle.fill"
            default: return "rectangle.stack.fill.badge.plus"
            }
        }
    }

    static func splitNarrative(_ text: String) -> [String] {
        let range = NSRange(text.startIndex..., in: text)
        let matches = narrativeSplit.matches(in: text, options: [], range: range)
        guard !matches.isEmpty else {
            // Fall back to simple multi-split markers inside narrative path.
            return splitMultiExpense(text)
        }

        var parts: [String] = []
        var start = text.startIndex
        for match in matches {
            guard let cut = Range(match.range, in: text) else { continue }
            let piece = String(text[start..<cut.lowerBound])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !piece.isEmpty { parts.append(piece) }
            // Keep the lookahead keyword (оплатил / сегодня / вчера) with the next clause.
            let matched = String(text[cut])
            let trimmedMatch = matched.trimmingCharacters(in: .whitespacesAndNewlines)
            // Splits that consume a conjunction (потом/затем) drop it; lookahead splits keep keyword.
            if trimmedMatch.isEmpty || ["потом", "затем"].contains(where: {
                trimmedMatch.lowercased().hasPrefix($0)
            }) || trimmedMatch.lowercased().hasPrefix("после") {
                start = cut.upperBound
            } else {
                // Zero-width-ish: match is whitespace before lookahead — start at upperBound
                // but the lookahead word remains in the tail.
                start = cut.upperBound
            }
        }
        let tail = String(text[start...]).trimmingCharacters(in: .whitespacesAndNewlines)
        if !tail.isEmpty { parts.append(tail) }

        // Flatten: each narrative clause may still hold comma/«и» multi-amounts
        // (e.g. «продукты 30 евро, подписка 3 доллара … были вчера»).
        var expanded: [String] = []
        for part in parts {
            let multi = splitMultiExpense(part)
            if multi.count >= 2 {
                expanded.append(contentsOf: multi)
            } else {
                expanded.append(part)
            }
        }

        // Keep date-only clauses («утром», «вчера я») so materialize can advance anchors.
        let withAmount = expanded.filter { parseAmount(from: $0) != nil }
        return withAmount.count >= 2 ? expanded : [text]
    }

    /// Rough count of distinct amount mentions (digits or spelled) for recurring gating.
    static func countAmountMentions(in text: String) -> Int {
        let digitRe = try! NSRegularExpression(pattern: #"\d+(?:[.,]\d{1,2})?"#, options: [])
        let range = NSRange(text.startIndex..., in: text)
        let digitCount = digitRe.numberOfMatches(in: text, options: [], range: range)
        // Spelled-only extras (e.g. «три доллара» with no digits nearby already counted).
        let spelledOnes = [
            "один", "одна", "два", "две", "три", "четыре", "пять", "шесть", "семь",
            "восемь", "девять", "десять", "one", "two", "three", "four", "five",
        ]
        var spelledHits = 0
        for word in spelledOnes {
            let re = try! NSRegularExpression(
                pattern: #"(?i)"# + wb + NSRegularExpression.escapedPattern(for: word) + wa,
                options: []
            )
            if re.firstMatch(in: text, options: [], range: range) != nil {
                spelledHits += 1
            }
        }
        // Prefer digit count when present; otherwise spelled count.
        if digitCount > 0 { return digitCount + max(0, spelledHits - 0) }
        return spelledHits
    }

    // MARK: - Recurring / multi

    static func detectFrequency(in text: String) -> String? {
        let range = NSRange(text.startIndex..., in: text)
        if monthlyRecurring.firstMatch(in: text, options: [], range: range) != nil {
            return "monthly"
        }
        if weeklyRecurring.firstMatch(in: text, options: [], range: range) != nil {
            return "weekly"
        }
        return nil
    }

    static func stripRecurringCues(_ text: String) -> String {
        var working = text
        let full = NSRange(working.startIndex..., in: working)
        working = monthlyRecurring.stringByReplacingMatches(
            in: working, options: [], range: full, withTemplate: " "
        )
        let full2 = NSRange(working.startIndex..., in: working)
        working = weeklyRecurring.stringByReplacingMatches(
            in: working, options: [], range: full2, withTemplate: " "
        )
        return working.replacingOccurrences(of: #"\s{2,}"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func splitMultiExpense(_ text: String) -> [String] {
        // Prefer comma/«и» first so «30 евро, подписка 3 доллара» keeps brand with the 3.
        let range = NSRange(text.startIndex..., in: text)
        let matches = multiSplit.matches(in: text, options: [], range: range)
        if !matches.isEmpty {
            var parts: [String] = []
            var start = text.startIndex
            for match in matches {
                guard let cut = Range(match.range, in: text) else { continue }
                let piece = String(text[start..<cut.lowerBound])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if !piece.isEmpty { parts.append(piece) }
                start = cut.upperBound
            }
            let tail = String(text[start...]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !tail.isEmpty { parts.append(tail) }

            let withAmount = parts.filter { parseAmount(from: $0) != nil }
            if withAmount.count >= 2 {
                var expanded: [String] = []
                for part in withAmount {
                    if let spanned = splitByAmountSpans(part) {
                        expanded.append(contentsOf: spanned)
                    } else {
                        expanded.append(part)
                    }
                }
                let ok = expanded.filter { parseAmount(from: $0) != nil }
                return ok.count >= 2 ? ok : withAmount
            }
        }

        if let spanned = splitByAmountSpans(text) {
            return spanned
        }
        return [text]
    }

    /// «15 € за продукты 30 $ за игрушки» — split on amount+unit spans, keep category words.
    private static func splitByAmountSpans(_ text: String) -> [String]? {
        let range = NSRange(text.startIndex..., in: text)
        let matches = amountSpan.matches(in: text, options: [], range: range)
        guard matches.count >= 2 else { return nil }

        var parts: [String] = []
        for i in 0..<matches.count {
            let startLoc = i == 0 ? 0 : matches[i].range.location
            let endLoc = i + 1 < matches.count
                ? matches[i + 1].range.location
                : (text as NSString).length
            let nsRange = NSRange(location: startLoc, length: endLoc - startLoc)
            guard let swift = Range(nsRange, in: text) else { continue }
            let piece = String(text[swift]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !piece.isEmpty { parts.append(piece) }
        }
        let withAmount = parts.filter { parseAmount(from: $0) != nil }
        guard withAmount.count >= 2 else { return nil }
        return withAmount
    }

    // MARK: - Note extraction

    static func extractNote(
        from rawText: String,
        matchedCategory: SharedCategoryDTO?,
        allCategories: [SharedCategoryDTO]
    ) -> String {
        // 1) Explicit note command → trailing detail only
        if let commanded = noteFromCommand(in: rawText) {
            return finalizeNote(commanded, matchedCategory: matchedCategory)
        }

        // 2) Comma / dash tail: if prefix alone still matches same category, tail is the note
        if let (prefix, tail) = splitTrailingDetail(rawText),
           let matchedCategory {
            let prefixMatch = SharedCategoryMatcher.autoAssign(
                text: prefix,
                categories: allCategories,
                preferredTypeRaw: matchedCategory.kindRaw == "both" ? nil : (
                    matchedCategory.kindRaw == "income" ? "income" : "expense"
                )
            )
            if prefixMatch?.id == matchedCategory.id {
                return finalizeNote(tail, matchedCategory: matchedCategory)
            }
        }

        // 3) Remainder after stripping amount / currency / cues / names / suppress signals
        var working = rawText
        for pattern in noteCommands {
            working = working.replacingOccurrences(of: pattern, with: " ", options: .regularExpression)
        }
        working = stripAmountsAndCurrency(working)
        working = stripCues(working)
        if let matchedCategory {
            working = stripKeyword(matchedCategory.nameRu, from: working)
            working = stripKeyword(matchedCategory.nameEn, from: working)
        }
        working = stripSuppressTokens(working)
        working = stripFiller(working)
        return finalizeNote(working, matchedCategory: matchedCategory)
    }

    private static func noteFromCommand(in text: String) -> String? {
        for pattern in noteCommands {
            if let capture = firstCapture(pattern: pattern, in: text) {
                let cleaned = cleanNoteFragment(capture)
                if !cleaned.isEmpty { return cleaned }
            }
        }
        return nil
    }

    private static func splitTrailingDetail(_ text: String) -> (prefix: String, tail: String)? {
        let separators = [",", " — ", " – ", " - "]
        var best: (prefix: String, tail: String)?
        for sep in separators {
            guard let range = text.range(of: sep, options: .backwards) else { continue }
            let prefix = String(text[..<range.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            let tail = String(text[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !prefix.isEmpty, !tail.isEmpty else { continue }
            // Prefer the rightmost short-ish separator split
            best = (prefix, tail)
            break
        }
        return best
    }

    private static func finalizeNote(_ text: String, matchedCategory: SharedCategoryDTO?) -> String {
        var s = stripAmountsAndCurrency(text)
        s = stripCues(s)
        s = stripFiller(s)
        if let matchedCategory {
            s = stripKeyword(matchedCategory.nameRu, from: s)
            s = stripKeyword(matchedCategory.nameEn, from: s)
            for keyword in matchedCategory.keywords.sorted(by: { $0.count > $1.count }) {
                // Keep detail-like keywords (кинотеатр) unless they're in noteSuppress
                let norm = TextNormalizer.normalize(keyword)
                if noteSuppress.contains(norm) {
                    s = stripKeyword(keyword, from: s)
                }
            }
        }
        s = leftoverPrepositions.stringByReplacingMatches(
            in: s,
            options: [],
            range: NSRange(s.startIndex..., in: s),
            withTemplate: " "
        )
        s = stripSuppressTokens(s)
        s = cleanNoteFragment(s)
        let normalized = TextNormalizer.normalize(s)
        if normalized.isEmpty { return "" }
        // Drop pure category-signal notes («заправка», «АЗС», «food»)
        if noteSuppress.contains(normalized) { return "" }
        let tokens = normalized.split(separator: " ").map(String.init)
        if !tokens.isEmpty, tokens.allSatisfy({ noteSuppress.contains($0) }) {
            return ""
        }
        return s
    }

    private static func stripAmountsAndCurrency(_ text: String) -> String {
        var working = text
        // Strip only the currency token attached to the amount (keep «долларов» in notes).
        let unitPatterns = [
            #"(?i)"# + amountNumberPattern + #"\s*"# + currencyTokenPattern,
            #"(?i)"# + currencyTokenPattern + #"\s*"# + amountNumberPattern,
        ]
        for pattern in unitPatterns {
            working = working.replacingOccurrences(of: pattern, with: " ", options: .regularExpression)
        }
        // Remaining bare digits (amount without a surviving unit token)
        working = working.replacingOccurrences(
            of: #"\d[\d\s.,]*"#,
            with: " ",
            options: .regularExpression
        )
        // Always drop lone «руб» leftovers; leave dollar/euro commodity words for the note.
        let rubOnly = try! NSRegularExpression(
            pattern: #"(?i)"# + wb + #"(руб(?:л(?:ей|я|ь|ями)?)?|rubles?|₽)"# + wa,
            options: []
        )
        working = rubOnly.stringByReplacingMatches(
            in: working,
            options: [],
            range: NSRange(working.startIndex..., in: working),
            withTemplate: " "
        )
        working = AmountWords.stripSpelled(from: working)
        return working
    }

    private static func stripCues(_ text: String) -> String {
        var working = expenseCues.stringByReplacingMatches(
            in: text,
            options: [],
            range: NSRange(text.startIndex..., in: text),
            withTemplate: " "
        )
        working = incomeCues.stringByReplacingMatches(
            in: working,
            options: [],
            range: NSRange(working.startIndex..., in: working),
            withTemplate: " "
        )
        return working
    }

    private static func stripFiller(_ text: String) -> String {
        var working = fillerWords.stringByReplacingMatches(
            in: text,
            options: [],
            range: NSRange(text.startIndex..., in: text),
            withTemplate: " "
        )
        working = noteNarrativeFiller.stringByReplacingMatches(
            in: working,
            options: [],
            range: NSRange(working.startIndex..., in: working),
            withTemplate: " "
        )
        return working
    }

    private static func stripSuppressTokens(_ text: String) -> String {
        var working = text
        for token in noteSuppress.sorted(by: { $0.count > $1.count }) {
            working = stripKeyword(token, from: working)
        }
        return working
    }

    private static func stripKeyword(_ keyword: String, from text: String) -> String {
        let k = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !k.isEmpty else { return text }
        // ё/е interchangeable so normalized suppress tokens hit spoken «зашёл».
        let flexible = k.map { ch -> String in
            switch ch {
            case "е", "ё": return "[её]"
            case "Е", "Ё": return "[ЕЁ]"
            case " ": return #"\s+"#
            default: return NSRegularExpression.escapedPattern(for: String(ch))
            }
        }.joined()
        let pattern = #"(?i)(?<![0-9A-Za-zА-Яа-яЁё])\#(flexible)(?![0-9A-Za-zА-Яа-яЁё])"#
        return text.replacingOccurrences(of: pattern, with: " ", options: .regularExpression)
    }

    private static func cleanNoteFragment(_ text: String) -> String {
        var s = text
        s = s.replacingOccurrences(of: #"[«»\"“”]"#, with: "", options: .regularExpression)
        s = s.replacingOccurrences(of: #"^[,\.\!\?;:\-\s]+"#, with: "", options: .regularExpression)
        s = s.replacingOccurrences(of: #"[,.\s]+$"#, with: "", options: .regularExpression)
        s = s.replacingOccurrences(of: #"\s{2,}"#, with: " ", options: .regularExpression)
        s = s.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.count <= 1, s.unicodeScalars.allSatisfy({ CharacterSet.punctuationCharacters.contains($0) }) {
            return ""
        }
        // Soft truncation — keep a short descriptive phrase, not the whole utterance.
        let maxChars = 42
        if s.count > maxChars {
            let words = s.split(separator: " ").map(String.init)
            var clipped: [String] = []
            var len = 0
            for w in words {
                let next = len + w.count + (clipped.isEmpty ? 0 : 1)
                if next > maxChars { break }
                clipped.append(w)
                len = next
            }
            s = clipped.isEmpty ? String(s.prefix(maxChars)) : clipped.joined(separator: " ")
        }
        return s
    }

    private static func firstCapture(pattern: String, in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return nil
        }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: range),
              match.numberOfRanges > 1,
              let swiftRange = Range(match.range(at: 1), in: text)
        else { return nil }
        return String(text[swiftRange])
    }
}

#if DEBUG
extension SharedVoiceParser {
    static func debugSelfCheck(categories: [SharedCategoryDTO]) -> [String] {
        var failures: [String] = []

        func check(
            _ label: String,
            _ raw: String,
            amount: Double,
            categoryId: String? = nil,
            note: String? = nil,
            currencyRaw: String? = nil,
            expectNilCurrency: Bool = false
        ) {
            let d = parse(rawText: raw, categories: categories)
            if d.amount != amount {
                failures.append("\(label) amount: got \(String(describing: d.amount)) expected \(amount)")
            }
            if let categoryId, d.categoryId != categoryId {
                failures.append("\(label) category: got \(String(describing: d.categoryId)) expected \(categoryId)")
            }
            if let note, TextNormalizer.normalize(d.note) != TextNormalizer.normalize(note) {
                failures.append("\(label) note: got «\(d.note)» expected «\(note)»")
            }
            if expectNilCurrency, d.currencyRaw != nil {
                failures.append("\(label) currency: got \(String(describing: d.currencyRaw)) expected nil")
            }
            if let currencyRaw, d.currencyRaw != currencyRaw {
                failures.append("\(label) currency: got \(String(describing: d.currencyRaw)) expected \(currencyRaw)")
            }
            let banned = ["рублей", "развлечения", "точка"]
            for b in banned where TextNormalizer.normalize(d.note).contains(TextNormalizer.normalize(b))
                && !(note.map { TextNormalizer.normalize($0).contains(TextNormalizer.normalize(b)) } ?? false) {
                failures.append("\(label) note contains filler «\(b)»")
            }
        }

        check(
            "ru-ent-cmd",
            "150 рублей развлечения, в скобочках напиши кинотеатр",
            amount: 150, categoryId: "entertainment", note: "кинотеатр"
        )
        check(
            "ru-ent-short",
            "150 рублей развлечения, кинотеатр",
            amount: 150, categoryId: "entertainment", note: "кинотеатр"
        )
        check(
            "en-food",
            "20 dollars food",
            amount: 20, categoryId: "food", note: ""
        )
        check(
            "ru-gas",
            "200 рублей АЗС, заправка",
            amount: 200, categoryId: "transport", note: ""
        )
        check(
            "en-gas",
            "200 dollars gas station",
            amount: 200, categoryId: "transport", note: ""
        )
        // DeepSeek free-form patterns
        check(
            "ds-phone",
            "20 рублей закинул на свой телефон",
            amount: 20, categoryId: "telecom", note: "телефон"
        )
        check(
            "ds-fare",
            "70 рублей это будет проезд на автобусе",
            amount: 70, categoryId: "transport", note: "проезд автобусе"
        )
        check(
            "ds-rent",
            "добавь тысяча тридцать пять рублей. Аренда квартиры.",
            amount: 1035, categoryId: "housing", note: "Аренда квартиры"
        )
        check(
            "ds-kopeks",
            "купил картошки гарнир огурцов итого 7 рублей 40 копеек",
            amount: 7.4, categoryId: "food", note: "картошки гарнир огурцов"
        )
        check(
            "fx-rub-wins",
            "900 рублей, покупка долларов",
            amount: 900, note: "покупка долларов", expectNilCurrency: true
        )
        check(
            "hybrid-tyscha",
            "тыща 200 руб подарки деньги ульяне",
            amount: 1200, categoryId: "gifts", expectNilCurrency: true
        )
        check(
            "hybrid-two-thousand",
            "две тысячи 50 рублей",
            amount: 2050, expectNilCurrency: true
        )

        let multi = parseMany(rawText: "кофе 5 и такси 12", categories: categories)
        if multi.count != 2 {
            failures.append("multi count: got \(multi.count) expected 2")
        } else {
            if multi[0].amount != 5 { failures.append("multi[0] amount") }
            if multi[1].amount != 12 { failures.append("multi[1] amount") }
            if multi[0].categoryId != "food" { failures.append("multi[0] category food") }
            if multi[1].categoryId != "transport" { failures.append("multi[1] category transport") }
        }

        let recurring = parseMany(
            rawText: "Netflix 10 dollars every month",
            categories: categories
        )
        if recurring.count != 1 || recurring.first?.frequencyRaw != "monthly" {
            failures.append("recurring monthly: \(String(describing: recurring.first?.frequencyRaw))")
        }
        if recurring.first?.amount != 10 {
            failures.append("recurring amount")
        }

        let weekly = parse(
            rawText: "аренда 200 каждый месяц",
            categories: categories
        )
        if weekly.frequencyRaw != "monthly" {
            failures.append("ru recurring monthly")
        }

        let ivan = parseMany(
            rawText: "Слушай я в рб моя валюта белорусский рубль и вчера я купил на 15 белорусских рублей кофе зашёл в кофейню попил оплатил подписку Яндекс Music три доллара потом я сходил за продуктами с Ульяной и купили мы продукты на 40 руб. сегодня утром я ездил на Каршеринг потратил 18 руб.",
            categories: categories
        )
        if ivan.count != 4 {
            failures.append("ivan count: got \(ivan.count) expected 4")
        } else {
            if ivan[0].amount != 15 || ivan[0].currencyRaw != "byn" || ivan[0].categoryId != "food" || ivan[0].dayOffset != -1 {
                failures.append("ivan[0] coffee: \(ivan[0])")
            }
            if ivan[1].amount != 3 || ivan[1].currencyRaw != "usd" || ivan[1].categoryId != "subscriptions" || ivan[1].frequencyRaw != "monthly" {
                failures.append("ivan[1] yandex: \(ivan[1])")
            }
            if ivan[2].amount != 40 || ivan[2].currencyRaw != "byn" || ivan[2].categoryId != "food" || ivan[2].dayOffset != -1 {
                failures.append("ivan[2] groceries: \(ivan[2])")
            }
            if ivan[3].amount != 18 || ivan[3].currencyRaw != "byn" || ivan[3].categoryId != "transport" || ivan[3].dayOffset != 0 || ivan[3].dayPart != "morning" {
                failures.append("ivan[3] carshare: \(ivan[3])")
            }
            for d in ivan where TextNormalizer.normalize(d.note).contains("ульян") {
                failures.append("ivan note leaked companion: \(d.note)")
            }
        }

        return failures
    }
}
#endif
