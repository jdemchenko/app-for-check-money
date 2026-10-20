export type TransactionType = "expense" | "income";

export type Category = {
  id: string;
  nameRu: string;
  nameEn: string;
  type: TransactionType | "both";
  keywords: string[];
  color: string;
  icon: string;
  isDefault: boolean;
};

export type Transaction = {
  id: string;
  amount: number;
  type: TransactionType;
  categoryId: string;
  note?: string;
  date: string; // YYYY-MM-DD
  createdAt: string; // ISO
  source: "manual" | "voice";
};

export type AppData = {
  version: 1;
  categories: Category[];
  transactions: Transaction[];
};

export type VoiceDraft = {
  amount: number | null;
  type: TransactionType | null;
  categoryId: string | null;
  note: string;
  rawText: string;
};

export type HistoryFilters = {
  type: TransactionType | "all";
  categoryId: string | "all";
  from: string | null;
  to: string | null;
  query: string;
};
