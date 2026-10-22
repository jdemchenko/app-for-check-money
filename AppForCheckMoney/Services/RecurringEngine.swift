import Foundation
import SwiftData

enum RecurringEngine {
    /// Creates due transactions (catch-up loop, max 24 per rule) and advances `nextFireDate`.
    @discardableResult
    static func applyDue(in context: ModelContext, now: Date = .now) -> Int {
        let descriptor = FetchDescriptor<RecurringRule>(
            predicate: #Predicate { $0.isActive == true }
        )
        let rules = (try? context.fetch(descriptor)) ?? []
        var created = 0
        for rule in rules {
            var guardCount = 0
            while rule.nextFireDate <= now, guardCount < 24 {
                let tx = MoneyTransaction(
                    amount: rule.amount,
                    type: rule.type,
                    categoryId: rule.categoryId,
                    note: rule.note,
                    date: rule.nextFireDate,
                    createdAt: now,
                    source: .manual,
                    currency: rule.currency,
                    paymentMethod: rule.paymentMethod
                )
                context.insert(tx)
                rule.advanceNextFire()
                created += 1
                guardCount += 1
            }
        }
        if created > 0 {
            try? context.save()
        }
        return created
    }
}
