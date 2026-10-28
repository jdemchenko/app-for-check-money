import Foundation

enum CSVExport {
    /// UTF-8 CSV with BOM for Excel-friendly RU/EN sheets.
    static func makeCSV(
        transactions: [MoneyTransaction],
        categories: [MoneyCategory],
        from: Date?,
        to: Date?
    ) -> String {
        let catMap = Dictionary(uniqueKeysWithValues: categories.map { ($0.id, $0) })
        let cal = Calendar.current
        let filtered = transactions.filter { tx in
            if let from {
                if tx.date < cal.startOfDay(for: from) { return false }
            }
            if let to {
                let end = cal.date(bySettingHour: 23, minute: 59, second: 59, of: to) ?? to
                if tx.date > end { return false }
            }
            return true
        }
        .sorted { $0.date < $1.date }

        let df = ISO8601DateFormatter()
        df.formatOptions = [.withFullDate]

        var lines: [String] = [
            "date,type,amount,currency,category,account,payment,note,id"
        ]
        for tx in filtered {
            let cat = catMap[tx.categoryId]?.displayName() ?? tx.categoryId
            let note = (tx.note ?? "")
                .replacingOccurrences(of: "\"", with: "\"\"")
            let payment = tx.paymentMethod == .unspecified ? "" : tx.paymentMethod.rawValue
            let account = tx.accountId.isEmpty ? AccountIDs.cashBYN : tx.accountId
            let row = [
                df.string(from: tx.date),
                tx.type.rawValue,
                String(format: "%.2f", tx.amount),
                tx.currency.code,
                escape(cat),
                escape(account),
                payment,
                "\"\(note)\"",
                tx.id,
            ].joined(separator: ",")
            lines.append(row)
        }
        // BOM helps Excel detect UTF-8
        return "\u{FEFF}" + lines.joined(separator: "\n")
    }

    private static func escape(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") {
            return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return value
    }

    static func writeTempFile(csv: String, name: String = "CheckMoney.csv") throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        guard let data = csv.data(using: .utf8) else {
            throw CocoaError(.fileWriteInapplicableStringEncoding)
        }
        try data.write(to: url, options: .atomic)
        return url
    }
}
