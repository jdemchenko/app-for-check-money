#!/usr/bin/env node
/**
 * Durable Telegram Bot API long-poll bridge.
 * Token from TELEGRAM_BOT_TOKEN only — never logged in full.
 *
 * Scripted Russian replies for deposit / status / TE-2 / help.
 * Unknown questions → append to TELEGRAM_INBOX_FILE and reply with escalate note.
 */

import {
  readFileSync,
  writeFileSync,
  appendFileSync,
  existsSync,
  mkdirSync,
} from "node:fs";
import { resolve, dirname } from "node:path";

const API = "https://api.telegram.org";
const ONCE = process.argv.includes("--once");
const POLL_TIMEOUT_SEC = 25;

const DEFAULT_STORE =
  process.env.CURSOR_PROJECT_STORE ||
  "/cursor/stores/bc-01a177a1-f21e-77ce-af41-f6f83ca48221";
const INBOX_FILE =
  process.env.TELEGRAM_INBOX_FILE ||
  resolve(DEFAULT_STORE, "internal/telegram-inbox.md");
const PUBKEY_FILE =
  process.env.SOLANA_PUBKEY_FILE ||
  resolve(DEFAULT_STORE, "internal/secrets/solana-usdc-deposit.pubkey");
const OFFSET_FILE =
  process.env.TELEGRAM_OFFSET_FILE ||
  resolve(DEFAULT_STORE, "internal/telegram-bridge.offset");

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
if (process.env.TELEGRAM_ENV_FILE) loadDotEnv(process.env.TELEGRAM_ENV_FILE);

const token = process.env.TELEGRAM_BOT_TOKEN?.trim();
if (!token) {
  console.error("Missing TELEGRAM_BOT_TOKEN (env or .env).");
  process.exit(1);
}

const tokenHint = `${token.slice(0, 4)}…${token.slice(-4)}`;

function publicAddress() {
  if (process.env.SOLANA_DEPOSIT_ADDRESS?.trim()) {
    return process.env.SOLANA_DEPOSIT_ADDRESS.trim();
  }
  if (existsSync(PUBKEY_FILE)) {
    return readFileSync(PUBKEY_FILE, "utf8").trim();
  }
  return "(адрес ещё не создан)";
}

async function api(method, body) {
  const url = `${API}/bot${token}/${method}`;
  const res = await fetch(url, {
    method: body ? "POST" : "GET",
    headers: body ? { "Content-Type": "application/json" } : undefined,
    body: body ? JSON.stringify(body) : undefined,
  });
  const data = await res.json();
  if (!data.ok) {
    throw new Error(`${method} failed: ${data.description || res.statusText}`);
  }
  return data.result;
}

function normalize(text) {
  return String(text || "")
    .trim()
    .toLowerCase()
    .replace(/ё/g, "е");
}

/**
 * @returns {"start"|"help"|"deposit"|"token"|"wrong_chain"|"silence"|"status"|"te2"|"withdraw"|"tx"|"unknown"}
 */
function classify(text) {
  const t = normalize(text);
  if (!t) return "unknown";
  if (
    t === "/start" ||
    t === "start" ||
    t === "старт" ||
    t.startsWith("/start")
  ) {
    return "start";
  }
  if (
    /не отвеч|почему молч|ты жив|мост.*онлайн|слышишь|алло|ау\b/.test(t)
  ) {
    return "silence";
  }
  if (
    /^(help|помощь|меню|commands|команды)\/?$/.test(t) ||
    t === "/help" ||
    t.includes("что умеешь") ||
    t.includes("что ты")
  ) {
    return "help";
  }
  if (
    /(?:^|[^а-яa-z])(верни|вернуть|верните|возврат|вывод|withdraw)(?:[^а-яa-z]|$)|обратно|отправить.*(мне|обратно)|сможешь.*средств/.test(
      t
    )
  ) {
    return "withdraw";
  }
  if (
    /неверн.*(сеть|чейн)|wrong chain|другая сеть|не solana|сеть\s*eth|в eth|в bsc|в tron|polygon|arbitrum/.test(
      t
    )
  ) {
    return "wrong_chain";
  }
  // Must-USDC / can I send SOL / other tokens — before generic deposit
  if (
    /обязательн.*usdc|именно usdc|только usdc|не usdc|не\s*usdc|вместо usdc|другой токен|другим токен|можно.*sol\b|выслать sol|отправить sol|шлю sol|sol[,?]? не|usdt|btc|eth\b|ethereum|erc-?20|bep-?20|tron|trc-?20|монета\s*sol|удобн.*\bsol\b|\bsol\b.*удоб|предпочит.*sol|хочу\s*sol|лучше\s*sol/.test(
      t
    ) ||
    (/\bsol\b/.test(t) &&
      /(слать|отправ|высл|можно|вместо|не usdc|монет|удобн|предпочит)/.test(t))
  ) {
    return "token";
  }
  if (
    /deposit|депозит|адрес|кошелек|кошелёк|wallet|usdc|solana|куда слать|куда отправ|перевод/.test(
      t
    )
  ) {
    return "deposit";
  }
  if (
    /статус|status|баланс|balance|пришло|получил|подтвержд|check|провер/.test(t)
  ) {
    return "status";
  }
  if (
    /te-?2|план|plan|выраст|заработ|24\s*ч|сутки|что дальше|next|стратег/.test(
      t
    )
  ) {
    return "te2";
  }
  // Solana signatures are base58 ~88 chars; also accept "tx" / "signature" / "hash"
  if (
    /^(tx|txid|hash|signature|подпись|хэш|хеш)\b/.test(t) ||
    /^[1-9A-HJ-NP-Za-km-z]{64,88}$/.test(String(text).trim())
  ) {
    return "tx";
  }
  return "unknown";
}

function replyFor(kind, text) {
  const addr = publicAddress();
  switch (kind) {
    case "start":
      return (
        "Мост снова онлайн ✅\n\n" +
        "Я отвечаю по делу: депозит USDC (Solana), статус, план TE-2.\n" +
        "Команды: помощь · депозит · статус · план · возврат\n" +
        "Если писали, пока мост молчал — пришлите вопрос ещё раз."
      );
    case "silence":
      return (
        "Мост снова онлайн, пиши сюда ✅\n\n" +
        "Иногда поллер останавливается между сессиями агента — уже перезапущен.\n" +
        "По депозиту: только USDC в сети Solana (~$10).\n" +
        `Адрес: ${addr}`
      );
    case "help":
      return (
        "Помощь:\n" +
        "• «депозит» / «адрес» — куда слать ~$10 USDC\n" +
        "• «обязательно USDC?» — да, SOL/USDT/ETH не принимаем на этот адрес\n" +
        "• «статус» — ждём ли перевод\n" +
        "• «план» — легальный TE-2 на 24ч\n" +
        "• «верни» — возврат на ваш Solana-адрес\n" +
        "• signature транзакции после перевода\n\n" +
        "Только легальные шаги. Без скама и чужих счетов."
      );
    case "token":
      return (
        "Да — для этого эксперимента нужен именно USDC в сети Solana.\n\n" +
        "❌ Не отправляйте: SOL, USDT, ETH, ERC-20, BSC, Tron и др.\n" +
        "✅ Только SPL USDC (Solana), около $10.\n\n" +
        `Адрес:\n${addr}\n\n` +
        "Другой токен/сеть на этот адрес = высокий риск потери. " +
        "Если удобнее SOL — сначала сконвертируйте в USDC (Solana), потом шлите сюда."
      );
    case "wrong_chain":
      return (
        "Только сеть Solana.\n\n" +
        "Не используйте Ethereum, BSC, Tron, Polygon и т.п. — " +
        "неверная сеть обычно означает безвозвратную потерю.\n\n" +
        `Адрес (Solana / USDC):\n${addr}`
      );
    case "deposit":
      return (
        "Депозит:\n" +
        "• Сеть: Solana\n" +
        "• Токен: именно USDC (SPL) — не SOL и не другие токены\n" +
        "• Сумма: около $10 USDC\n\n" +
        `Адрес:\n${addr}\n\n` +
        "⚠️ Неверная сеть / другой токен = потеря средств.\n" +
        "После перевода пришлите signature (hash) транзакции."
      );
    case "status":
      return (
        "Статус:\n" +
        "• Мост: работает\n" +
        "• Кошелёк: создан (публичный адрес выдан)\n" +
        "• Депозит: ждём ваш перевод USDC в Solana и signature\n" +
        "• TE-2: план готов, исполнение только после подтверждённого депозита и вашего явного «да» на сделку\n\n" +
        `Адрес: ${addr}`
      );
    case "te2":
      return (
        "План TE-2 (легально, ~$10 USDC, 24ч) — без гарантии прибыли:\n" +
        "1) Подтвердить депозит USDC (Solana).\n" +
        "2) Вы выбираете рельс: Jupiter spot / ваш CEX spot / hold.\n" +
        "3) Каждая сделка — только после вашего явного согласия.\n" +
        "4) В конце: старт/финиш USDC, комиссии, P/L.\n\n" +
        "Исключено: скам, фейковые магазины, чужие аккаунты, манипуляции рынка."
      );
    case "withdraw":
      return (
        "Возврат средств: да, по вашему явному запросу в этом чате.\n\n" +
        "Напишите «верни» + ваш Solana-адрес для USDC и сумму " +
        "(весь остаток или часть). После подтверждения отправлю USDC " +
        "в той же сети и пришлю signature.\n\n" +
        "Пока депозит не пришёл — возвращать нечего."
      );
    case "tx":
      return (
        "Принял candidate signature/hash. Зафиксирую и проверю на Solscan.\n" +
        `Текст: ${String(text).trim().slice(0, 120)}\n` +
        "Если это не signature — пришлите его отдельно одной строкой."
      );
    default:
      return null;
  }
}

function ensureInboxHeader() {
  mkdirSync(dirname(INBOX_FILE), { recursive: true });
  if (!existsSync(INBOX_FILE)) {
    writeFileSync(
      INBOX_FILE,
      "---\n" +
        "cursor:\n" +
        '  subagentId: "bc-3dc9cf50-8f96-5939-a538-75689d835b22"\n' +
        "---\n\n" +
        "# Telegram inbox (escalated unknown questions)\n\n" +
        "Worker/parent: review and answer via bot when needed.\n\n"
    );
  }
}

function escalateUnknown({ chatId, from, text, updateId }) {
  ensureInboxHeader();
  const ts = new Date().toISOString();
  const block =
    `## ${ts}\n` +
    `- chat_id: ${chatId}\n` +
    `- from: ${from}\n` +
    `- update_id: ${updateId}\n` +
    `- text: ${JSON.stringify(String(text).slice(0, 2000))}\n` +
    `- status: pending\n\n`;
  appendFileSync(INBOX_FILE, block);
  // Notify flag for parent/worker polling
  const flag = resolve(dirname(INBOX_FILE), "telegram-inbox.notify");
  writeFileSync(
    flag,
    JSON.stringify({ at: ts, chat_id: chatId, preview: String(text).slice(0, 160) }) +
      "\n"
  );
  console.log(
    JSON.stringify({ event: "escalated", chat_id: chatId, inbox: INBOX_FILE })
  );
  return (
    "Записал вопрос координатору ✅\n\n" +
    `Вы написали: «${String(text).slice(0, 240)}»\n\n` +
    "Пока могу сразу ответить на: депозит · статус · план · помощь.\n" +
    "Переформулируйте в одну из тем — или ждите ответа по эскалации."
  );
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
  if (!text) {
    await api("sendMessage", {
      chat_id: chatId,
      text: "Пока понимаю только текст. Напишите: депозит · статус · план · помощь",
      reply_parameters: { message_id: msg.message_id },
    });
    return;
  }

  const kind = classify(text);
  let out = replyFor(kind, text);
  if (!out) {
    out = escalateUnknown({
      chatId,
      from,
      text,
      updateId: update.update_id,
    });
  } else if (kind === "tx") {
    // Also capture tx candidates in inbox for verification
    ensureInboxHeader();
    appendFileSync(
      INBOX_FILE,
      `## ${new Date().toISOString()} (tx candidate)\n` +
        `- chat_id: ${chatId}\n` +
        `- from: ${from}\n` +
        `- text: ${JSON.stringify(String(text).trim())}\n` +
        `- status: needs_solscan_check\n\n`
    );
  }

  await api("sendMessage", {
    chat_id: chatId,
    text: out,
    reply_parameters: { message_id: msg.message_id },
  });
  console.log(
    JSON.stringify({ event: "replied", chat_id: chatId, kind })
  );
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
      pid: process.pid,
      address: publicAddress(),
      inbox: INBOX_FILE,
    })
  );
  await ensureNoWebhook();

  let offset = 0;
  if (existsSync(OFFSET_FILE)) {
    const raw = readFileSync(OFFSET_FILE, "utf8").trim();
    const n = Number(raw);
    if (Number.isFinite(n) && n >= 0) offset = n;
  }
  console.log(JSON.stringify({ event: "offset_loaded", offset }));

  for (;;) {
    let updates;
    try {
      updates = await api("getUpdates", {
        offset,
        timeout: POLL_TIMEOUT_SEC,
        allowed_updates: ["message", "edited_message"],
      });
    } catch (err) {
      console.error(
        JSON.stringify({
          event: "poll_error",
          message: String(err?.message || err),
        })
      );
      await new Promise((r) => setTimeout(r, 3000));
      continue;
    }
    for (const u of updates) {
      offset = Math.max(offset, u.update_id + 1);
      try {
        mkdirSync(dirname(OFFSET_FILE), { recursive: true });
        writeFileSync(OFFSET_FILE, String(offset));
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
  console.error(
    JSON.stringify({ event: "fatal", message: String(err?.message || err) })
  );
  process.exit(1);
});
