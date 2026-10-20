# CheckMoney (AppForCheckMoney)

Native **SwiftUI** personal money tracker for iPhone and iPad — expenses and income with manual entry, voice drafts, and keyword auto-categorization. Data stays on-device via **SwiftData**. No backend, no auth.

> This repository is an **independent** iOS app. It is not related to Fitil.

## Features

- **Manual entry** — amount, expense/income, category, optional note, date
- **Voice entry** — `SFSpeechRecognizer` + microphone → editable draft → confirm to save  
  Graceful fallback when speech/mic is unavailable or permission is denied
- **Categories** — seeded defaults (Food, Transport, Housing, Salary, …); **auto-assign** from note/voice keywords with **manual override**
- **Screens** — Home (month balance + recent), Add (manual / voice), Categories, History (search + filters)
- **System appearance** — follows Light/Dark Mode (no forced theme)
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

Speech recognition often needs a **physical device** (or a Simulator with a working mic input). If voice is unavailable, the Add → Voice tab shows a clear fallback and manual entry still works.

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
