# CheckMoney (AppForCheckMoney)

Native **SwiftUI** personal money tracker for iPhone and iPad — expenses and income with manual entry, voice drafts, and keyword auto-categorization. Data stays on-device via **SwiftData**. No backend, no auth.

> This repository is an **independent** iOS app. It is not related to Fitil.

## Features

- **Manual entry** — amount, expense/income, category, optional note, date
- **Voice entry** — `SFSpeechRecognizer` + microphone; Home **quick entry** autosaves on a confident parse (amount + category). Low-confidence cases get a one-tap confirm with manual category override. Full Add → Voice flow remains for manual editing.
- **Categories** — seeded defaults (Food, Transport, Housing, Salary, …); **auto-assign** from note/voice keywords (RU/EN synonyms, АЗС/заправка/gas station, …) with **manual override**; new/edited categories **auto-suggest marker keywords** from the name (editable before save)
- **Screens** — Home (balance + floating glass mic + recent), History, Categories; manual Add as a sheet from Home
- **UI** — Liquid Glass–inspired materials (`.ultraThinMaterial` / specular rims / soft depth), minimal chrome, system Light/Dark
- **Currency** — each transaction stores its own currency; Settings has **display** (totals via approximate BYN-pivot rates) and **entry default** (new ops). Changing Settings never rewrites past amounts. Voice «руб» → entry default (BYN); dollars/euros stamp USD/EUR.
- **Stats** — week / month / all overview + spend by category (converted to display currency)
- **App icon** — minimal checkmark glass; Default / Dark / Tinted Home Screen Appearances; no in-app picker
- **System appearance** — Light/Dark; restrained ADA-inspired materials
- **Localization** — English + Russian (`en` / `ru` `.lproj`); UI language follows the device locale

## Requirements

- macOS with **Xcode 16+** (iOS 18 SDK)
- iOS **18.0+** Simulator or device
- Apple Developer team (for device runs / signing). Simulator works with automatic signing and an empty team in many setups.

## Open & run

1. Clone this repo on a Mac.
2. Open `AppForCheckMoney.xcodeproj` in Xcode.
3. Select the **AppForCheckMoney** scheme and an iOS 18+ Simulator (or your device).
4. Set your **Team** under Signing & Capabilities if deploying to a device (`PRODUCT_BUNDLE_IDENTIFIER` is `com.jdemchenko.AppForCheckMoney`).
5. Press **Run** (⌘R).

### Voice on Simulator

Speech recognition often needs a **physical device** (or a Simulator with a working mic input). If voice is unavailable, Home quick entry / Add → Voice show a clear fallback and manual entry still works.

### Logic self-test (no Xcode)

Parse + category matcher examples (RU/EN) can be checked on any machine with Node:

```bash
node scripts/voice-selftest.mjs
node scripts/keyword-suggest-selftest.mjs
node scripts/currency-selftest.mjs
```

## Project structure

```
AppForCheckMoney.xcodeproj/          # Xcode project + shared scheme
AppForCheckMoney/
  AppForCheckMoneyApp.swift         # @main + SwiftData container
  Models/                           # MoneyTransaction, MoneyCategory, SeedData
  Services/                         # Speech, voice parse, category match, L10n
  Views/                            # Home, Add, Categories, History + components
  Resources/                        # Info.plist, en/ru Localizable.strings
  Assets.xcassets/
```

## Privacy (Info.plist)

- `NSMicrophoneUsageDescription`
- `NSSpeechRecognitionUsageDescription`

## Design notes

UI follows Apple HIG: `NavigationStack`, large titles, grouped lists, SF Symbols, and `.regularMaterial` cards. When building with a newer SDK that ships Liquid Glass APIs (iOS 26+), those can be adopted behind availability checks without changing the data layer.

## License

Private / personal use unless otherwise stated.
