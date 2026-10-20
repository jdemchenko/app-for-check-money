"use client";

import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useState,
  type ReactNode,
} from "react";
import { DEFAULT_CATEGORIES } from "@/lib/defaults";
import { detectLocale, type Locale } from "@/lib/i18n";
import { loadAppData, saveAppData } from "@/lib/storage";
import type { AppData, Category, Transaction } from "@/lib/types";

type AppContextValue = {
  locale: Locale;
  ready: boolean;
  error: string | null;
  categories: Category[];
  transactions: Transaction[];
  reload: () => void;
  addTransaction: (tx: Omit<Transaction, "id" | "createdAt">) => Transaction;
  updateTransaction: (id: string, patch: Partial<Transaction>) => void;
  deleteTransaction: (id: string) => void;
  addCategory: (cat: Omit<Category, "id" | "isDefault">) => Category;
  updateCategory: (id: string, patch: Partial<Category>) => void;
  deleteCategory: (id: string) => void;
  restoreDefaultCategories: () => void;
};

const AppContext = createContext<AppContextValue | null>(null);

function uid(): string {
  if (typeof crypto !== "undefined" && "randomUUID" in crypto) {
    return crypto.randomUUID();
  }
  return `id-${Date.now()}-${Math.random().toString(36).slice(2, 9)}`;
}

export function AppProvider({ children }: { children: ReactNode }) {
  const [locale, setLocale] = useState<Locale>("ru");
  const [ready, setReady] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [data, setData] = useState<AppData>({
    version: 1,
    categories: DEFAULT_CATEGORIES,
    transactions: [],
  });

  const persist = useCallback((next: AppData) => {
    setData(next);
    try {
      saveAppData(next);
      setError(null);
    } catch {
      setError("storage");
    }
  }, []);

  const reload = useCallback(() => {
    try {
      setLocale(detectLocale());
      setData(loadAppData());
      setError(null);
      setReady(true);
    } catch {
      setError("load");
      setReady(true);
    }
  }, []);

  useEffect(() => {
    reload();
  }, [reload]);

  const addTransaction = useCallback(
    (tx: Omit<Transaction, "id" | "createdAt">) => {
      const full: Transaction = {
        ...tx,
        id: uid(),
        createdAt: new Date().toISOString(),
      };
      persist({
        ...data,
        transactions: [full, ...data.transactions],
      });
      return full;
    },
    [data, persist],
  );

  const updateTransaction = useCallback(
    (id: string, patch: Partial<Transaction>) => {
      persist({
        ...data,
        transactions: data.transactions.map((t) =>
          t.id === id ? { ...t, ...patch } : t,
        ),
      });
    },
    [data, persist],
  );

  const deleteTransaction = useCallback(
    (id: string) => {
      persist({
        ...data,
        transactions: data.transactions.filter((t) => t.id !== id),
      });
    },
    [data, persist],
  );

  const addCategory = useCallback(
    (cat: Omit<Category, "id" | "isDefault">) => {
      const full: Category = { ...cat, id: uid(), isDefault: false };
      persist({ ...data, categories: [...data.categories, full] });
      return full;
    },
    [data, persist],
  );

  const updateCategory = useCallback(
    (id: string, patch: Partial<Category>) => {
      persist({
        ...data,
        categories: data.categories.map((c) =>
          c.id === id ? { ...c, ...patch } : c,
        ),
      });
    },
    [data, persist],
  );

  const deleteCategory = useCallback(
    (id: string) => {
      persist({
        ...data,
        categories: data.categories.filter((c) => c.id !== id),
      });
    },
    [data, persist],
  );

  const restoreDefaultCategories = useCallback(() => {
    const custom = data.categories.filter((c) => !c.isDefault);
    const defaults = structuredClone(DEFAULT_CATEGORIES);
    persist({ ...data, categories: [...defaults, ...custom] });
  }, [data, persist]);

  const value = useMemo<AppContextValue>(
    () => ({
      locale,
      ready,
      error,
      categories: data.categories,
      transactions: data.transactions,
      reload,
      addTransaction,
      updateTransaction,
      deleteTransaction,
      addCategory,
      updateCategory,
      deleteCategory,
      restoreDefaultCategories,
    }),
    [
      locale,
      ready,
      error,
      data.categories,
      data.transactions,
      reload,
      addTransaction,
      updateTransaction,
      deleteTransaction,
      addCategory,
      updateCategory,
      deleteCategory,
      restoreDefaultCategories,
    ],
  );

  return <AppContext.Provider value={value}>{children}</AppContext.Provider>;
}

export function useApp(): AppContextValue {
  const ctx = useContext(AppContext);
  if (!ctx) throw new Error("useApp must be used within AppProvider");
  return ctx;
}
