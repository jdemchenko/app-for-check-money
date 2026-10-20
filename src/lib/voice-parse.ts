import { autoAssignCategory } from "./categorize";
import type { Category, TransactionType, VoiceDraft } from "./types";

const EXPENSE_CUES =
  /\b(spent|spend|paid|pay|bought|buy|потратил|потратила|потрачено|оплатил|оплатила|купил|купила|расход)\b/i;
const INCOME_CUES =
  /\b(got|received|earned|salary|income|получил|получила|зарплата|доход|заработал|заработала)\b/i;

/** Extract a monetary amount from speech / free text (RU + EN). */
export function parseAmount(text: string): number | null {
  const cleaned = text
    .replace(/(\d)\s+(\d{3})\b/g, "$1$2") // 80 000 → 80000
    .replace(/,/g, ".");

  // Prefer patterns with currency cues
  const withCurrency =
    cleaned.match(
      /(?:₽|руб(?:л(?:ей|я|ь)?)?|rubles?|\$|usd|eur|€)?\s*(\d+(?:\.\d{1,2})?)\s*(?:₽|руб(?:л(?:ей|я|ь)?)?|rubles?|\$|usd|eur|€)?/i,
    ) ?? cleaned.match(/(\d+(?:\.\d{1,2})?)/);

  if (!withCurrency?.[1]) return null;
  const value = Number.parseFloat(withCurrency[1]);
  if (!Number.isFinite(value) || value <= 0) return null;
  return Math.round(value * 100) / 100;
}

export function inferType(text: string): TransactionType | null {
  if (INCOME_CUES.test(text)) return "income";
  if (EXPENSE_CUES.test(text)) return "expense";
  return null;
}

export function parseVoiceText(
  rawText: string,
  categories: Category[],
): VoiceDraft {
  const amount = parseAmount(rawText);
  let type = inferType(rawText);

  const matched = autoAssignCategory(rawText, categories, type);
  if (!type && matched) {
    type = matched.type === "both" ? "expense" : matched.type;
  }
  if (!type) type = "expense";

  const category =
    matched ??
    autoAssignCategory(rawText, categories, type) ??
    categories.find((c) => c.type === type || c.type === "both") ??
    null;

  // Note = text without amount-ish tokens for readability
  const note = rawText
    .replace(/\d[\d\s.,]*/g, " ")
    .replace(/\s+/g, " ")
    .trim();

  return {
    amount,
    type,
    categoryId: category?.id ?? null,
    note,
    rawText,
  };
}
