# app-for-check-money

Minimal **Telegram Bot API** long-poll bridge. The repo was an empty placeholder; this adds a small Node relay so Telegram messages get replies.

## What it does

- Long-polls `getUpdates` (no public webhook URL required).
- On `/start`, `Start`, or `Старт`, replies that the bridge is live.
- Echoes other text messages.

There is no money movement, payments, or trading logic yet.

## Run locally

```bash
cp .env.example .env
# put TELEGRAM_BOT_TOKEN in .env (never commit it)
npm run bridge
```

One-shot (exit after the first handled update):

```bash
npm run bridge:once
```

Optional: point at a secrets file instead of `.env`:

```bash
TELEGRAM_ENV_FILE=/path/to/telegram.env npm run bridge
```

## Talk to the bot

1. Open the bot in Telegram (username from BotFather / `getMe`).
2. Send `Старт`, `/start`, or any text.
3. You should get a live confirmation or an echo.

## Secrets

- Token lives only in env / a gitignored secrets file.
- Never commit `.env` or paste the full token into PRs/logs.
