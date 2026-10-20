import { DEFAULT_CATEGORIES, STORAGE_KEY } from "./defaults";
import type { AppData, Category, Transaction } from "./types";

function emptyData(): AppData {
  return {
    version: 1,
    categories: structuredClone(DEFAULT_CATEGORIES),
    transactions: [],
  };
}

export function loadAppData(): AppData {
  if (typeof window === "undefined") return emptyData();
  try {
    const raw = window.localStorage.getItem(STORAGE_KEY);
    if (!raw) return emptyData();
    const parsed = JSON.parse(raw) as AppData;
    if (!parsed || parsed.version !== 1 || !Array.isArray(parsed.transactions)) {
      return emptyData();
    }
    // Ensure defaults exist if user wiped categories
    const categories =
      Array.isArray(parsed.categories) && parsed.categories.length > 0
        ? parsed.categories
        : structuredClone(DEFAULT_CATEGORIES);
    return { version: 1, categories, transactions: parsed.transactions };
  } catch {
    return emptyData();
  }
}

export function saveAppData(data: AppData): void {
  if (typeof window === "undefined") return;
  window.localStorage.setItem(STORAGE_KEY, JSON.stringify(data));
}

export function computeBalance(transactions: Transaction[]): {
  balance: number;
  income: number;
  expense: number;
} {
  let income = 0;
  let expense = 0;
  for (const tx of transactions) {
    if (tx.type === "income") income += tx.amount;
    else expense += tx.amount;
  }
  return { balance: income - expense, income, expense };
}

export function monthBounds(d = new Date()): { from: string; to: string } {
  const y = d.getFullYear();
  const m = d.getMonth();
  const from = `${y}-${String(m + 1).padStart(2, "0")}-01`;
  const last = new Date(y, m + 1, 0).getDate();
  const to = `${y}-${String(m + 1).padStart(2, "0")}-${String(last).padStart(2, "0")}`;
  return { from, to };
}

export function filterMonth(
  transactions: Transaction[],
  from: string,
  to: string,
): Transaction[] {
  return transactions.filter((tx) => tx.date >= from && tx.date <= to);
}

export function upsertCategory(categories: Category[], next: Category): Category[] {
  const idx = categories.findIndex((c) => c.id === next.id);
  if (idx === -1) return [...categories, next];
  const copy = [...categories];
  copy[idx] = next;
  return copy;
}
