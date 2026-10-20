import { format, isToday, isYesterday, parseISO } from "date-fns";
import { enUS, ru } from "date-fns/locale";
import type { Locale } from "./i18n";
import { t } from "./i18n";

export function formatMoney(amount: number, locale: Locale): string {
  const currency = locale === "ru" ? "RUB" : "USD";
  try {
    return new Intl.NumberFormat(locale === "ru" ? "ru-RU" : "en-US", {
      style: "currency",
      currency,
      maximumFractionDigits: 2,
    }).format(amount);
  } catch {
    return `${amount.toFixed(2)} ${t(locale, "currency")}`;
  }
}

export function formatSignedMoney(
  amount: number,
  type: "expense" | "income",
  locale: Locale,
): string {
  const sign = type === "expense" ? "−" : "+";
  return `${sign}${formatMoney(amount, locale)}`;
}

export function formatDayLabel(isoDate: string, locale: Locale): string {
  const date = parseISO(isoDate);
  if (isToday(date)) return t(locale, "today");
  if (isYesterday(date)) return t(locale, "yesterday");
  return format(date, locale === "ru" ? "d MMMM yyyy" : "MMM d, yyyy", {
    locale: locale === "ru" ? ru : enUS,
  });
}

export function todayISO(): string {
  const d = new Date();
  const y = d.getFullYear();
  const m = String(d.getMonth() + 1).padStart(2, "0");
  const day = String(d.getDate()).padStart(2, "0");
  return `${y}-${m}-${day}`;
}
