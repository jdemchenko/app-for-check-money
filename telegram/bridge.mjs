#!/usr/bin/env node
/**
 * Minimal Telegram Bot API long-poll bridge.
 * Token from TELEGRAM_BOT_TOKEN only — never logged in full.
 */

import { readFileSync, existsSync } from "node:fs";
import { resolve } from "node:path";

const API = "https://api.telegram.org";
const ONCE = process.argv.includes("--once");
const POLL_TIMEOUT_SEC = 25;

function loadDotEnv(path) {
  if (!existsSync(path)) return;
  for (const line of readFileSync(path, "utf8").split("\n")) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith("#")) continue;
    const eq = trimmed.indexOf("=");
    if (eq < 0) continue;
    const key = trimmed.slice(0, eq).trim();
    let val = trimmed.slice(eq + 1).trim();
    if (
      (val.startsWith('"') && val.endsWith('"')) ||
      (val.startsWith("'") && val.endsWith("'"))
    ) {
      val = val.slice(1, -1);
    }
    if (!(key in process.env)) process.env[key] = val;
  }
}

loadDotEnv(resolve(process.cwd(), ".env"));
const storeEnv = process.env.TELEGRAM_ENV_FILE;
if (storeEnv) loadDotEnv(storeEnv);

const token = process.env.TELEGRAM_BOT_TOKEN?.trim();
if (!token) {
  console.error("Missing TELEGRAM_BOT_TOKEN (env or .env).");
  process.exit(1);
}

const tokenHint = `${token.slice(0, 4)}…${token.slice(-4)}`;

async function api(method, body) {
  const url = `${API}/bot${token}/${method}`;
  const res = await fetch(url, {
    method: body ? "POST" : "GET",
    headers: body ? { "Content-Type": "application/json" } : undefined,
    body: body ? JSON.stringify(body) : undefined,
  });
  const data = await res.json();
  if (!data.ok) {
    const desc = data.description || res.statusText;
    throw new Error(`${method} failed: ${desc}`);
  }
  return data.result;
}

function isStart(text) {
  if (!text) return false;
  const t = text.trim().toLowerCase();
  return t === "/start" || t === "start" || t === "старт" || t.startsWith("/start");
}

function replyText(text) {
  if (isStart(text)) {
    return (
      "Bridge is live ✅\n\n" +
      "Your message reached the app-for-check-money Telegram relay. " +
      "Send any text and I will echo it back for now."
    );
  }
  return `Bridge echo: ${text}`;
}

async function handleUpdate(update) {
  const msg = update.message || update.edited_message;
  if (!msg?.chat?.id) return;
  const chatId = msg.chat.id;
  const text = msg.text || msg.caption || "";
  const from = msg.from?.username || msg.from?.id || "unknown";
  console.log(
    JSON.stringify({
      event: "inbound",
      update_id: update.update_id,
      chat_id: chatId,
      from,
      text: String(text).slice(0, 120),
    })
  );
  if (!text) return;
  const out = replyText(text);
  await api("sendMessage", {
    chat_id: chatId,
    text: out,
    reply_parameters: { message_id: msg.message_id },
  });
  console.log(JSON.stringify({ event: "replied", chat_id: chatId }));
}

async function ensureNoWebhook() {
  const info = await api("getWebhookInfo");
  if (info.url) {
    console.log(JSON.stringify({ event: "clear_webhook", had_url: true }));
    await api("deleteWebhook", { drop_pending_updates: false });
  }
}

async function main() {
  const me = await api("getMe");
  console.log(
    JSON.stringify({
      event: "started",
      bot: me.username,
      bot_id: me.id,
      token_hint: tokenHint,
      mode: ONCE ? "once" : "poll",
    })
  );
  await ensureNoWebhook();

  let offset = 0;
  for (;;) {
    const updates = await api("getUpdates", {
      offset,
      timeout: POLL_TIMEOUT_SEC,
      allowed_updates: ["message", "edited_message"],
    });
    for (const u of updates) {
      offset = Math.max(offset, u.update_id + 1);
      try {
        await handleUpdate(u);
      } catch (err) {
        console.error(
          JSON.stringify({
            event: "handle_error",
            message: String(err?.message || err),
          })
        );
      }
    }
    if (ONCE && updates.length > 0) {
      console.log(JSON.stringify({ event: "once_done" }));
      break;
    }
  }
}

main().catch((err) => {
  console.error(JSON.stringify({ event: "fatal", message: String(err?.message || err) }));
  process.exit(1);
});
