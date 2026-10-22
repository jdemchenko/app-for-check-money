# CheckMoney — Threads promo

Dark **1080×1920** (9:16) export frames for Instagram/Threads carousels.  
Almost no copy — brand + one short line. UI mockups match CheckMoney quiet Liquid Glass (dark).

## Preview

```bash
cd Promo
npm install
npx playwright install chromium   # once
npm run dev
```

Open [http://127.0.0.1:47321](http://127.0.0.1:47321). Keys ← → / Space.

Export preview (no HUD): `http://127.0.0.1:47321/?export=1`

## Export PNGs

```bash
cd Promo
npm run export:threads
```

Writes to:

`/cursor/stores/bc-c8df8d63-d424-4cfc-a21e-e4b21386f06a/media/promo-threads/`

Override: `THREADS_OUT=./out npm run export:threads`

## Frames

| File | Idea |
|------|------|
| `01-hero.png` | Home mock + mic |
| `02-voice.png` | Hold-to-talk |
| `03-voice-flow.png` | Phrase → journal |
| `04-stats.png` | Week bars |
| `05-categories.png` | Category rings |
| `06-widget.png` | Home Screen widget |
| `07-lock.png` | Face ID |
| `08-cta.png` | Brand |

Desktop light “pitch deck” is no longer the primary deliverable.
