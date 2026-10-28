# CheckMoney (AppForCheckMoney)

Native **SwiftUI** personal money tracker for iPhone, iPad, and **Apple Watch** — expenses and income with manual entry, voice drafts, and keyword auto-categorization. Data stays on-device via **SwiftData** (phone). Watch is a **paired companion**: hold-to-dictate → shared NLP → WatchConnectivity sync. No App Groups entitlement (Personal Team–safe). Widget snapshot uses **Keychain Sharing** (`keychain-access-groups`) so today/balance can update without a paid App Group. No backend / auth. **iCloud/CloudKit** needs a paid Apple Developer team (Personal Team stays local).

> This repository is an **independent** iOS app. It is not related to Fitil.

**Launch candidate:** marketing **1.3**, build **27** — optimized for **iOS 26** Liquid Glass (dual-path fallback to iOS 18+). See agent-store `docs/ios26-ready.md`.

## Features

- **Manual entry** — amount, expense/income, category, optional note, date, payment method (cash/card)
- **Voice entry** — `SFSpeechRecognizer` + microphone; Home **quick entry** autosaves on a confident parse (amount + category). Low-confidence cases get a one-tap confirm with manual category override. Full Add → Voice flow remains for manual editing.
- **Multi-expense voice** — «кофе 5 и такси 12» → QuietConfirmPanel batch save
- **Voice → recurring** — «Netflix 10 every month» / «аренда 200 каждый месяц» → confirm → `RecurringRule`
- **App Intents / Siri** — «Add expense» + «Log expense from text» (Shortcuts; no paid team)
- **Share / paste** — URL scheme `checkmoney://draft?text=…`, open CSV/text documents, Home **Paste text draft**
- **Categories** — seeded defaults; keyword auto-assign (RU/EN); custom categories; built-ins locked delete
- **Screens** — Home (FX ledger total + month cashflow + budget bars + glass mic), Stats (cashflow insights), History (search / account filter / CSV), Categories, Ledger hub (accounts / goals / debts / spaces)
- **Accounts** — multi-currency wallets; live/cached FX totals; txs belong to an account
- **Goals & debts** — goals linked to accounts; I-owe / owed-to-me with settle
- **Budget** — monthly + **per-category** + **per-account** limits
- **Recurring** — weekly/monthly rules auto-post when due; day-before local reminder
- **App lock** — Face ID / Touch ID / device passcode gate
- **Daily reminder** — optional local notification (Settings)
- **Privacy** — on-device ledger; honest Settings copy; shared sync needs paid Developer / iCloud (local spaces shell meanwhile)
- **Onboarding** — one screen (hold-to-talk + BYN default)
- **iPhone widget** — today / balance / budget / 7-day bars via Keychain Sharing
- **iCloud** — best-effort toggle; CloudKit requires paid team
- **UI** — quiet Liquid Glass: iOS 26 `glassEffect` on panels/mic/controls; materials fallback on earlier iOS; system Light/Dark
- **Currency** — per-transaction; display + entry default; voice «руб» → entry default (BYN)
- **Stats** — week / month / all + daily bars + category % + quiet insights (vs last, daily avg, largest)
- **Apple Watch** — dictate companion + today complication (**Available Apps install work is paused**)
- **Localization** — English + Russian

## Requirements

- macOS with **Xcode 26+** (iOS 26 / watchOS 26 SDKs) required to compile `glassEffect` paths
- Runtime: iOS **18.0+** (best on **iOS 26**); watchOS **11.0+** companion
- Same Signing **Team** (`3G9UZZBWW9` Personal Team in project) on iPhone + Watch + widgets. Do **not** add App Groups on Personal Team.

## Open & run

1. Clone this repo on a Mac.
2. `git pull origin cursor/app-for-check-money-50c5`
3. Open `AppForCheckMoney.xcodeproj` in Xcode.
4. Select scheme **AppForCheckMoney** → iOS 18+ Simulator or device.
5. Same Team on all targets; leave App Groups off on Personal Team.
6. **Product → Clean Build Folder**, then **Run** (⌘R).

### Mac verify (launch candidate)

After install, smoke:

1. Onboarding → Home hold-to-talk: `кофе 5` autosave; `кофе 5 и такси 12` batch confirm; `аренда 200 каждый месяц` recurring confirm.
2. Settings → category budget for Food → appears under monthly bar on Home.
3. Stats → Insights strip (vs last / daily avg / largest).
4. History → search amount/note; export CSV; import CSV (re-import own export).
5. Home → Paste text draft (clipboard `20 dollars food`).
6. Shortcuts / Siri: **Add expense** with amount.
7. Lock on → background → reopen asks biometrics.
8. Widget: add CheckMoney large — 7-day bars update after a save.
9. Optional: Settings → daily reminder → allow notifications.

Watch Available Apps: **do not block launch** (paused); only re-check if this tip broke packaging.

### Voice on Simulator

Speech often needs a **physical device**. Manual / paste / intents still work.

### Logic self-test (no Xcode)

```bash
node scripts/voice-selftest.mjs
node scripts/keyword-suggest-selftest.mjs
node scripts/currency-selftest.mjs
node scripts/csv-import-selftest.mjs
```

## Promo — Threads frames

Dark **1080×1920** carousel PNGs (minimal copy, UI mockups):

```bash
cd Promo && npm install && npx playwright install chromium && npm run export:threads
```

Preview: `npm run dev` → http://127.0.0.1:47321 (`?export=1` for clean frames).  
Output: agent-store `media/promo-threads/`. Details: `Promo/README.md`.

## Project structure

```
AppForCheckMoney.xcodeproj/
AppForCheckMoney/                   # iPhone / iPad (SwiftData)
  Services/                         # Voice, CSV import/export, intents, reminder, lock…
Shared/                             # SharedVoiceParser, AmountWords, widget snapshot
CheckMoneyPhoneWidgets/             # Home Screen widget (Keychain Sharing)
CheckMoneyWatch/                    # watchOS companion
CheckMoneyWatchWidgets/
Promo/                              # Threads 1080×1920 export frames (Vite + Playwright)
```

## Privacy (Info.plist)

- `NSMicrophoneUsageDescription`
- `NSSpeechRecognitionUsageDescription`
- `NSFaceIDUsageDescription`
- URL scheme `checkmoney://` + document types for CSV/text

## Post-launch (skipped for 1.1)

- Receipt OCR / Vision
- Pro / IAP, shared spaces, paid Developer, seed-rename lock
- Watch Available Apps packaging push

## License

Private / personal use unless otherwise stated.
