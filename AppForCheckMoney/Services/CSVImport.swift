import Foundation

struct CSVImportRow: Equatable {
    var date: Date
    var type: TransactionType
    var amount: Double
    var currency: AppCurrency
    var categoryName: String
    var payment: PaymentMethod
    var note: String?
}

enum CSVImportError: LocalizedError {
    case empty
    case noRows
    case unreadable

    var errorDescription: String? {
        switch self {
        case .empty: return L10n.string("import.empty")
        case .noRows: return L10n.string("import.noRows")
        case .unreadable: return L10n.string("import.failed")
        }
    }
}

/// Flexible CSV import: CheckMoney export + CoinKeeper-like / generic sheets.
enum CSVImport {
    static func parse(text: String) throws -> [CSVImportRow] {
        var raw = text
        if raw.hasPrefix("\u{FEFF}") {
            raw.removeFirst()
        }
        let lines = raw
            .components(separatedBy: CharacterSet.newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !lines.isEmpty else { throw CSVImportError.empty }

        let delimiter = detectDelimiter(lines[0])
        let headerCells = splitCSVLine(lines[0], delimiter: delimiter).map { normalizeHeader($0) }
        let hasHeader = headerCells.contains(where: { isHeaderToken($0) })
        let mapping = columnMapping(headerCells, hasHeader: hasHeader)
        let dataLines = hasHeader ? Array(lines.dropFirst()) : lines
        guard !dataLines.isEmpty else { throw CSVImportError.noRows }

        var rows: [CSVImportRow] = []
        for line in dataLines {
            let cells = splitCSVLine(line, delimiter: delimiter)
            guard let row = row(from: cells, map: mapping) else { continue }
            rows.append(row)
        }
        guard !rows.isEmpty else { throw CSVImportError.noRows }
        return rows
    }

    static func parseFile(url: URL) throws -> [CSVImportRow] {
        let data = try Data(contentsOf: url)
        guard let text = String(data: data, encoding: .utf8)
            ?? String(data: data, encoding: String.Encoding(rawValue: 2145)) // windows-1251
        else { throw CSVImportError.unreadable }
        return try parse(text: text)
    }

    // MARK: - Mapping

    private struct ColumnMap {
        var date: Int?
        var type: Int?
        var amount: Int?
        var currency: Int?
        var category: Int?
        var payment: Int?
        var note: Int?
    }

    private static func columnMapping(_ headers: [String], hasHeader: Bool) -> ColumnMap {
        var map = ColumnMap()
        guard hasHeader else {
            // CheckMoney export without relying on header order fallback:
            // date,type,amount,currency,category,payment,note,id
            map.date = 0
            map.type = 1
            map.amount = 2
            map.currency = 3
            map.category = 4
            map.payment = 5
            map.note = 6
            return map
        }
        for (idx, h) in headers.enumerated() {
            if map.date == nil, matches(h, ["date", "дата", "datetime", "time"]) { map.date = idx }
            else if map.type == nil, matches(h, ["type", "тип", "income/expense", "направление"]) { map.type = idx }
            else if map.amount == nil, matches(h, ["amount", "сумма", "sum", "value", "money"]) { map.amount = idx }
            else if map.currency == nil, matches(h, ["currency", "валюта", "curr"]) { map.currency = idx }
            else if map.category == nil, matches(h, ["category", "категория", "cat"]) { map.category = idx }
            else if map.payment == nil, matches(h, ["payment", "оплата", "method", "account", "счет", "счёт", "wallet"]) {
                map.payment = idx
            } else if map.note == nil, matches(h, ["note", "notes", "comment", "description", "описание", "комментарий", "memo"]) {
                map.note = idx
            }
        }
        // CoinKeeper-ish: often Date; Category; Amount — treat col0 date, last numeric as amount.
        if map.amount == nil { map.amount = headers.count > 2 ? 2 : 1 }
        if map.date == nil { map.date = 0 }
        if map.category == nil, headers.count > 1 { map.category = 1 }
        return map
    }

    private static func row(from cells: [String], map: ColumnMap) -> CSVImportRow? {
        guard let amountIdx = map.amount, amountIdx < cells.count else { return nil }
        guard let amount = parseAmount(cells[amountIdx]), amount != 0 else { return nil }

        let date: Date = {
            if let i = map.date, i < cells.count, let d = parseDate(cells[i]) { return d }
            return Calendar.current.startOfDay(for: .now)
        }()

        var type: TransactionType = amount < 0 ? .expense : .expense
        if let i = map.type, i < cells.count {
            type = parseType(cells[i], amount: amount)
        } else if amount < 0 {
            type = .expense
        }

        let absAmount = abs(amount)
        let currency: AppCurrency = {
            if let i = map.currency, i < cells.count {
                return parseCurrency(cells[i])
            }
            return .byn
        }()

        let categoryName: String = {
            if let i = map.category, i < cells.count {
                let name = cells[i].trimmingCharacters(in: .whitespacesAndNewlines)
                if !name.isEmpty { return name }
            }
            return ""
        }()

        let payment: PaymentMethod = {
            if let i = map.payment, i < cells.count {
                return parsePayment(cells[i])
            }
            return .unspecified
        }()

        let note: String? = {
            if let i = map.note, i < cells.count {
                let n = cells[i].trimmingCharacters(in: .whitespacesAndNewlines)
                return n.isEmpty ? nil : n
            }
            return nil
        }()

        return CSVImportRow(
            date: date,
            type: type,
            amount: absAmount,
            currency: currency,
            categoryName: categoryName,
            payment: payment,
            note: note
        )
    }

    // MARK: - Parsers

    private static func parseAmount(_ raw: String) -> Double? {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        s = s.replacingOccurrences(of: " ", with: "")
        s = s.replacingOccurrences(of: "\u{00A0}", with: "")
        // EU: 1.234,56 → 1234.56
        if s.contains(","), s.contains(".") {
            s = s.replacingOccurrences(of: ".", with: "")
            s = s.replacingOccurrences(of: ",", with: ".")
        } else {
            s = s.replacingOccurrences(of: ",", with: ".")
        }
        s = s.replacingOccurrences(of: #"[^\d.\-]"#, with: "", options: .regularExpression)
        return Double(s)
    }

    private static func parseDate(_ raw: String) -> Date? {
        let s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withFullDate, .withDashSeparatorInDate]
        if let d = iso.date(from: String(s.prefix(10))) { return d }

        let formats = [
            "yyyy-MM-dd", "dd.MM.yyyy", "dd/MM/yyyy", "MM/dd/yyyy",
            "yyyy.MM.dd", "dd-MM-yyyy", "yyyy/MM/dd",
        ]
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = TimeZone.current
        for f in formats {
            df.dateFormat = f
            if let d = df.date(from: String(s.prefix(f.count + 2))) { return d }
        }
        return nil
    }

    private static func parseType(_ raw: String, amount: Double) -> TransactionType {
        let t = raw.lowercased()
        if t.contains("income") || t.contains("доход") || t == "+" || t.contains("in") {
            return .income
        }
        if t.contains("expense") || t.contains("расход") || t == "-" || t.contains("out") {
            return .expense
        }
        return amount < 0 ? .expense : .expense
    }

    private static func parseCurrency(_ raw: String) -> AppCurrency {
        let t = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if t.contains("usd") || t == "$" || t.contains("dollar") { return .usd }
        if t.contains("eur") || t == "€" || t.contains("euro") { return .eur }
        if t.contains("rub") || t == "₽" || t.contains("руб") { return .rub }
        if t.contains("byn") || t == "br" || t.contains("бел") { return .byn }
        return AppCurrency.parse(t)
    }

    private static func parsePayment(_ raw: String) -> PaymentMethod {
        let t = raw.lowercased()
        if t.contains("cash") || t.contains("налич") || t.contains("cash") { return .cash }
        if t.contains("card") || t.contains("карт") || t.contains("visa") || t.contains("master") {
            return .card
        }
        return .unspecified
    }

    // MARK: - CSV helpers

    private static func detectDelimiter(_ line: String) -> Character {
        let semis = line.filter { $0 == ";" }.count
        let commas = line.filter { $0 == "," }.count
        let tabs = line.filter { $0 == "\t" }.count
        if semis >= commas && semis >= tabs && semis > 0 { return ";" }
        if tabs > commas && tabs > semis { return "\t" }
        return ","
    }

    private static func splitCSVLine(_ line: String, delimiter: Character) -> [String] {
        var result: [String] = []
        var current = ""
        var inQuotes = false
        for ch in line {
            if ch == "\"" {
                inQuotes.toggle()
                continue
            }
            if ch == delimiter && !inQuotes {
                result.append(current)
                current = ""
                continue
            }
            current.append(ch)
        }
        result.append(current)
        return result.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
    }

    private static func normalizeHeader(_ s: String) -> String {
        s.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "\"", with: "")
    }

    private static func isHeaderToken(_ h: String) -> Bool {
        matches(h, [
            "date", "дата", "type", "тип", "amount", "сумма", "category", "категория",
            "currency", "валюта", "note", "описание", "payment", "account", "счет",
        ])
    }

    private static func matches(_ value: String, _ keys: [String]) -> Bool {
        keys.contains { value == $0 || value.contains($0) }
    }
}
