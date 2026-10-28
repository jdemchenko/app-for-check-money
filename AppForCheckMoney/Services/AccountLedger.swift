import Foundation

/// Pure ledger math — balances, FX totals, goal progress. Covered by self-tests.
enum AccountLedger {
    struct BalanceLine: Equatable {
        let accountId: String
        let name: String
        let currency: AppCurrency
        /// Balance in the account's own currency.
        let native: Double
        /// Same balance converted to display currency.
        let display: Double
    }

    struct Totals: Equatable {
        let lines: [BalanceLine]
        let displayCurrency: AppCurrency
        var totalDisplay: Double { lines.reduce(0) { $0 + $1.display } }
    }

    static func balance(
        account: MoneyAccount,
        transactions: [MoneyTransaction]
    ) -> Double {
        let mine = transactions.filter { tx in
            if !tx.accountId.isEmpty { return tx.accountId == account.id }
            // Legacy rows without accountId land on the default cash BYN wallet.
            return account.id == AccountIDs.cashBYN
        }
        let signed = mine.reduce(0.0) { partial, tx in
            partial + CurrencyConverter.convert(tx.signedAmount, from: tx.currency, to: account.currency)
        }
        return ((account.openingBalance + signed) * 100).rounded() / 100
    }

    static func totals(
        accounts: [MoneyAccount],
        transactions: [MoneyTransaction],
        displayCurrency: AppCurrency
    ) -> Totals {
        let active = accounts.filter { !$0.isArchived }.sorted { $0.sortOrder < $1.sortOrder }
        let lines: [BalanceLine] = active.map { account in
            let native = balance(account: account, transactions: transactions)
            let display = CurrencyConverter.convert(native, from: account.currency, to: displayCurrency)
            return BalanceLine(
                accountId: account.id,
                name: account.name,
                currency: account.currency,
                native: native,
                display: (display * 100).rounded() / 100
            )
        }
        return Totals(lines: lines, displayCurrency: displayCurrency)
    }

    static func goalProgress(
        goal: MoneyGoal,
        accounts: [MoneyAccount],
        transactions: [MoneyTransaction]
    ) -> (current: Double, ratio: Double) {
        guard let account = accounts.first(where: { $0.id == goal.accountId }) else {
            return (0, 0)
        }
        var current = balance(account: account, transactions: transactions)
        if account.currency != goal.currency {
            current = CurrencyConverter.convert(current, from: account.currency, to: goal.currency)
        }
        current = (current * 100).rounded() / 100
        return (current, goal.progress(currentBalance: current))
    }
}
