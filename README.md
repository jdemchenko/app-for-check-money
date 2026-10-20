# CheckMoney (AppForCheckMoney)

Personal money tracker for expenses and income — manual entry, voice drafts, and keyword auto-categorization. Data stays in the browser (`localStorage`). No auth, no backend.

## Features

- **Manual entry** — amount, expense/income, category, optional note, date
- **Voice entry** — Web Speech API parses spoken amounts/categories into a draft you confirm before saving; graceful fallback when unsupported
- **Categories** — defaults (Food, Transport, Housing, Salary, …); **auto-assign** from note/voice keywords with **manual override**
- **Screens** — Home (balance + recent), Add, Categories, History with filters
- **Design** — iOS / Liquid Glass inspired UI, light + dark via `prefers-color-scheme`, Russian/English from `navigator.language` (default Russian for `ru*`), respects `prefers-reduced-motion`

## Stack

- Next.js (App Router) + TypeScript
- Tailwind CSS + shadcn/ui
- Local persistence only

## Quick start

```bash
npm install
npm run dev
```

Open [http://localhost:43127](http://localhost:43127).

```bash
npm run build
npm start
```

## Voice & auto-categorize

1. On **Add → Voice**, tap the mic and say something like «Потратил 450 на кофе» or “Spent 12 on coffee”.
2. The app fills amount, type, and category (keywords such as *кофе* / *coffee* → Food). Confirm to save.
3. On **Manual**, typing keywords in the note field also auto-picks a category; you can override anytime.

## License

Private / personal use unless otherwise stated.
