"use client";

import { useMemo, useState } from "react";
import { Filter, Search, Trash2 } from "lucide-react";
import { toast } from "sonner";
import { EmptyState, LoadingState } from "@/components/empty-state";
import { GlassPanel } from "@/components/glass";
import { LargeTitle, PageShell } from "@/components/page-shell";
import { useApp } from "@/components/providers/app-provider";
import { TransactionRow } from "@/components/transaction-row";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import {
  Sheet,
  SheetContent,
  SheetFooter,
  SheetHeader,
  SheetTitle,
} from "@/components/ui/sheet";
import { categoryDisplayName } from "@/lib/category-name";
import { formatDayLabel } from "@/lib/format";
import { t } from "@/lib/i18n";
import type { HistoryFilters, TransactionType } from "@/lib/types";

const initialFilters: HistoryFilters = {
  type: "all",
  categoryId: "all",
  from: null,
  to: null,
  query: "",
};

export default function HistoryPage() {
  const {
    locale,
    ready,
    transactions,
    categories,
    deleteTransaction,
  } = useApp();
  const [filters, setFilters] = useState<HistoryFilters>(initialFilters);
  const [sheetOpen, setSheetOpen] = useState(false);
  const [selectedId, setSelectedId] = useState<string | null>(null);

  const byId = useMemo(
    () => new Map(categories.map((c) => [c.id, c])),
    [categories],
  );

  const filtered = useMemo(() => {
    const q = filters.query.trim().toLowerCase();
    return [...transactions]
      .filter((tx) => {
        if (filters.type !== "all" && tx.type !== filters.type) return false;
        if (filters.categoryId !== "all" && tx.categoryId !== filters.categoryId)
          return false;
        if (filters.from && tx.date < filters.from) return false;
        if (filters.to && tx.date > filters.to) return false;
        if (q) {
          const cat = byId.get(tx.categoryId);
          const hay = `${tx.note ?? ""} ${categoryDisplayName(cat, locale)}`.toLowerCase();
          if (!hay.includes(q) && !String(tx.amount).includes(q)) return false;
        }
        return true;
      })
      .sort((a, b) => {
        if (a.date !== b.date) return b.date.localeCompare(a.date);
        return b.createdAt.localeCompare(a.createdAt);
      });
  }, [transactions, filters, byId, locale]);

  const grouped = useMemo(() => {
    const map = new Map<string, typeof filtered>();
    for (const tx of filtered) {
      const list = map.get(tx.date) ?? [];
      list.push(tx);
      map.set(tx.date, list);
    }
    return [...map.entries()];
  }, [filtered]);

  const selected = selectedId
    ? transactions.find((tx) => tx.id === selectedId)
    : null;

  if (!ready) {
    return (
      <PageShell>
        <LoadingState label={t(locale, "loading")} />
      </PageShell>
    );
  }

  return (
    <PageShell>
      <LargeTitle
        title={t(locale, "history")}
        trailing={
          <button
            type="button"
            onClick={() => setSheetOpen(true)}
            className="rounded-full bg-[var(--fill-tertiary)] p-2.5 text-[var(--label-secondary)]"
            aria-label={t(locale, "filters")}
          >
            <Filter className="size-4" />
          </button>
        }
      />

      <div className="relative mb-4 animate-rise">
        <Search className="pointer-events-none absolute left-3.5 top-1/2 size-4 -translate-y-1/2 text-[var(--label-tertiary)]" />
        <Input
          value={filters.query}
          onChange={(e) =>
            setFilters((f) => ({ ...f, query: e.target.value }))
          }
          placeholder={t(locale, "search")}
          className="h-12 rounded-[16px] border-0 bg-[var(--fill-tertiary)] pl-10 shadow-none"
        />
      </div>

      {grouped.length === 0 ? (
        <GlassPanel>
          <EmptyState
            icon={Search}
            title={t(locale, "emptyHistory")}
            description={t(locale, "noTransactions")}
          />
        </GlassPanel>
      ) : (
        <div className="space-y-5 animate-rise delay-1">
          {grouped.map(([day, items]) => (
            <section key={day}>
              <h2 className="mb-2 px-1 text-[13px] font-semibold uppercase tracking-[0.04em] text-[var(--label-secondary)]">
                {formatDayLabel(day, locale)}
              </h2>
              <GlassPanel className="divide-y divide-black/5 p-2 dark:divide-white/8">
                {items.map((tx) => {
                  const cat = byId.get(tx.categoryId);
                  return (
                    <TransactionRow
                      key={tx.id}
                      tx={tx}
                      category={cat}
                      locale={locale}
                      categoryName={categoryDisplayName(cat, locale)}
                      onClick={() => setSelectedId(tx.id)}
                    />
                  );
                })}
              </GlassPanel>
            </section>
          ))}
        </div>
      )}

      <Sheet open={sheetOpen} onOpenChange={setSheetOpen}>
        <SheetContent
          side="bottom"
          className="rounded-t-[28px] border-0 bg-[var(--surface-elevated)]"
        >
          <SheetHeader>
            <SheetTitle>{t(locale, "filters")}</SheetTitle>
          </SheetHeader>
          <div className="space-y-4 px-4 pb-2">
            <TypeFilter
              value={filters.type}
              locale={locale}
              onChange={(type) => setFilters((f) => ({ ...f, type }))}
            />
            <div className="space-y-1.5">
              <p className="text-[13px] font-medium text-[var(--label-secondary)]">
                {t(locale, "category")}
              </p>
              <select
                className="h-11 w-full rounded-[14px] bg-[var(--fill-tertiary)] px-3 text-[15px]"
                value={filters.categoryId}
                onChange={(e) =>
                  setFilters((f) => ({
                    ...f,
                    categoryId: e.target.value,
                  }))
                }
              >
                <option value="all">{t(locale, "all")}</option>
                {categories.map((c) => (
                  <option key={c.id} value={c.id}>
                    {categoryDisplayName(c, locale)}
                  </option>
                ))}
              </select>
            </div>
            <div className="grid grid-cols-2 gap-3">
              <div className="space-y-1.5">
                <p className="text-[13px] font-medium text-[var(--label-secondary)]">
                  {t(locale, "from")}
                </p>
                <Input
                  type="date"
                  value={filters.from ?? ""}
                  onChange={(e) =>
                    setFilters((f) => ({
                      ...f,
                      from: e.target.value || null,
                    }))
                  }
                  className="rounded-[14px] border-0 bg-[var(--fill-tertiary)]"
                />
              </div>
              <div className="space-y-1.5">
                <p className="text-[13px] font-medium text-[var(--label-secondary)]">
                  {t(locale, "to")}
                </p>
                <Input
                  type="date"
                  value={filters.to ?? ""}
                  onChange={(e) =>
                    setFilters((f) => ({
                      ...f,
                      to: e.target.value || null,
                    }))
                  }
                  className="rounded-[14px] border-0 bg-[var(--fill-tertiary)]"
                />
              </div>
            </div>
          </div>
          <SheetFooter className="flex-row gap-2">
            <Button
              type="button"
              variant="ghost"
              className="flex-1 rounded-full"
              onClick={() => setFilters(initialFilters)}
            >
              {t(locale, "resetFilters")}
            </Button>
            <Button
              type="button"
              className="flex-1 rounded-full bg-[var(--accent-blue)] text-white"
              onClick={() => setSheetOpen(false)}
            >
              {t(locale, "confirm")}
            </Button>
          </SheetFooter>
        </SheetContent>
      </Sheet>

      <Sheet
        open={Boolean(selected)}
        onOpenChange={(open) => !open && setSelectedId(null)}
      >
        <SheetContent
          side="bottom"
          className="rounded-t-[28px] border-0 bg-[var(--surface-elevated)]"
        >
          <SheetHeader>
            <SheetTitle>
              {selected
                ? categoryDisplayName(byId.get(selected.categoryId), locale)
                : ""}
            </SheetTitle>
          </SheetHeader>
          {selected ? (
            <div className="space-y-2 px-4 pb-4 text-[15px] text-[var(--label-secondary)]">
              <p>
                {selected.note?.trim() || "—"} · {formatDayLabel(selected.date, locale)}
              </p>
              <Button
                type="button"
                variant="ghost"
                className="mt-2 w-full rounded-full text-[var(--accent-red)]"
                onClick={() => {
                  deleteTransaction(selected.id);
                  setSelectedId(null);
                  toast.success(t(locale, "deleted"));
                }}
              >
                <Trash2 className="mr-2 size-4" />
                {t(locale, "delete")}
              </Button>
            </div>
          ) : null}
        </SheetContent>
      </Sheet>
    </PageShell>
  );
}

function TypeFilter({
  value,
  locale,
  onChange,
}: {
  value: TransactionType | "all";
  locale: "ru" | "en";
  onChange: (v: TransactionType | "all") => void;
}) {
  const opts: Array<TransactionType | "all"> = ["all", "expense", "income"];
  return (
    <div className="space-y-1.5">
      <p className="text-[13px] font-medium text-[var(--label-secondary)]">
        {t(locale, "type")}
      </p>
      <div className="grid grid-cols-3 gap-1.5">
        {opts.map((opt) => (
          <button
            key={opt}
            type="button"
            onClick={() => onChange(opt)}
            className={`rounded-[12px] py-2.5 text-[13px] font-semibold ${
              value === opt
                ? "bg-[var(--accent-blue)] text-white"
                : "bg-[var(--fill-tertiary)] text-[var(--label-secondary)]"
            }`}
          >
            {opt === "all"
              ? t(locale, "all")
              : opt === "expense"
                ? t(locale, "expenses")
                : t(locale, "incomes")}
          </button>
        ))}
      </div>
    </div>
  );
}
