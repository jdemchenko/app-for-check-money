# CheckMoney (AppForCheckMoney)

Native **SwiftUI** personal money tracker for iPhone, iPad, and **Apple Watch** — expenses and income with manual entry, voice drafts, and keyword auto-categorization. Data stays on-device via **SwiftData** (phone). Watch is a **paired companion**: hold-to-dictate → shared NLP → WatchConnectivity sync. No App Groups, no backend, no auth.

> This repository is an **independent** iOS app. It is not related to Fitil.

## Features

- **Manual entry** — amount, expense/income, category, optional note, date
- **Voice entry** — `SFSpeechRecognizer` + microphone; Home **quick entry** autosaves on a confident parse (amount + category). Low-confidence cases get a one-tap confirm with manual category override. Full Add → Voice flow remains for manual editing.
- **Categories** — seeded defaults (Food, Transport, Housing, Salary, …); **auto-assign** from note/voice keywords (RU/EN synonyms, АЗС/заправка/gas station, …) with **manual override**; new/edited categories **auto-suggest marker keywords** from the name (editable before save)
- **Screens** — Home (balance + floating glass mic + recent), History, Categories; manual Add as a sheet from Home
- **UI** — Liquid Glass–inspired materials (`.ultraThinMaterial` / specular rims / soft depth), minimal chrome, system Light/Dark
- **Currency** — each transaction stores its own currency; Settings has **display** (totals via approximate BYN-pivot rates) and **entry default** (new ops). Changing Settings never rewrites past amounts. Voice «руб» → entry default (BYN); dollars/euros stamp USD/EUR.
- **Stats** — week / month / all overview + spend by category (converted to display currency)
- **Apple Watch** — Hold-to-dictate companion (one breath → parse amount/category/currency → sync to iPhone). Minimal UI; phone SwiftData is source of truth. Sync: Documents cache + WatchConnectivity (no App Groups). **Today spend** complication.
- **App icon** — minimal checkmark glass; Default / Dark / Tinted Home Screen Appearances; Watch 1024×1024 icon; no in-app picker
- **System appearance** — Light/Dark; restrained ADA-inspired materials
- **Localization** — English + Russian (`en` / `ru` `.lproj`); UI language follows the device locale

## Requirements

- macOS with **Xcode 26+** recommended for watchOS 26 devices (iOS 18 / watchOS 11+ SDKs)
- iOS **18.0+** Simulator or device; watchOS **11.0+** companion (runs on watchOS **26.6**)
- Same Signing **Team** on iPhone + Watch targets. App Groups are **not used**. Simulator works with automatic signing.

## Open & run

1. Clone this repo on a Mac.
2. Open `AppForCheckMoney.xcodeproj` in Xcode.
3. Select the **AppForCheckMoney** scheme and an iOS 18+ Simulator (or your device).
4. Set the **same Team** under Signing & Capabilities on **AppForCheckMoney**, **CheckMoneyWatch**, and **CheckMoneyWatchWidgets** (`PRODUCT_BUNDLE_IDENTIFIER` is `com.jdemchenko.AppForCheckMoney`). Do **not** add App Groups.
5. Press **Run** (⌘R).

### Apple Watch (companion — same product)

**Одно приложение с компаньоном на часах.** Не отдельный Watch‑продукт.

**Только так:** scheme **AppForCheckMoney** → **iPhone** → **Run**.  
Build log must show `Watch companion OK → …/PlugIns/CheckMoneyWatch.app`. Then iPhone **Watch** app → **Available Apps** → **CheckMoney** (or auto-install). Tap mic → dictate → syncs to iPhone via WCSession.

Watch-only Run installs an **orphan** companion: iPhone Watch app will remove it. Always delete Watch-only CheckMoney + the iPhone app, Clean, then iPhone Run so Available Apps is the only path.

Build log must include `app-id=…watchkitapp` (not empty entitlements). After Run: trust the Personal Team developer on iPhone (Settings → General → VPN & Device Management); enable Developer Mode on Watch if prompted. Personal Team is not a hard block — packaging must stay PlugIns + CodeSignOnCopy (never nested `codesign --force`).

`CheckMoneyWatch` scheme = emergency debug only (same companion binary — not a second App Store / Watch Store app). Full guide: agent-store `docs/apple-watch.md`.

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
AppForCheckMoney.xcodeproj/          # Xcode project + AppForCheckMoney / CheckMoneyWatch schemes
AppForCheckMoney/                   # iPhone / iPad app (SwiftData)
  Services/PhoneWatchSync.swift     # Push snapshot + merge Watch pending adds
Shared/                             # SyncModels, LocalSyncStore, SharedVoiceParser (iOS + Watch)
CheckMoneyWatch/                    # watchOS companion UI
CheckMoneyWatchWidgets/             # Today spend complication
```

## Privacy (Info.plist)

- `NSMicrophoneUsageDescription`
- `NSSpeechRecognitionUsageDescription`

## Design notes

UI follows Apple HIG: `NavigationStack`, large titles, grouped lists, SF Symbols, and `.regularMaterial` cards. When building with a newer SDK that ships Liquid Glass APIs (iOS 26+), those can be adopted behind availability checks without changing the data layer.

## License

Private / personal use unless otherwise stated.
