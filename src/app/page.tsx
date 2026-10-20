"use client";

import { useMemo, useState, useEffect } from "react";
import Link from "next/link";
import { Inbox, Wallet } from "lucide-react";
import { EmptyState, ErrorState, LoadingState } from "@/components/empty-state";
import { GlassPanel } from "@/components/glass";
import { LargeTitle, PageShell } from "@/components/page-shell";
import { useApp } from "@/components/providers/app-provider";
import { TransactionRow } from "@/components/transaction-row";
import { categoryDisplayName } from "@/lib/category-name";
import { formatMoney } from "@/lib/format";
import { t } from "@/lib/i18n";
import {
  computeBalance,
  filterMonth,
  monthBounds,
} from "@/lib/storage";

export default function HomePage() {
  const { locale, ready, error, reload, transactions, categories } = useApp();
  const [bounds, setBounds] = useState<{ from: string; to: string } | null>(
    null,
  );

  useEffect(() => {
    setBounds(monthBounds());
  }, []);

  const monthTx = useMemo(() => {
    if (!bounds) return [];
    return filterMonth(transactions, bounds.from, bounds.to);
  }, [transactions, bounds]);

  const totals = useMemo(() => computeBalance(monthTx), [monthTx]);

  const recent = useMemo(
    () =>
      [...transactions]
        .sort((a, b) => b.createdAt.localeCompare(a.createdAt))
        .slice(0, 8),
    [transactions],
  );

  const byId = useMemo(
    () => new Map(categories.map((c) => [c.id, c])),
    [categories],
  );

  if (!ready || !bounds) {
    return (
      <PageShell>
        <LoadingState label={t(locale, "loading")} />
      </PageShell>
    );
  }

  if (error) {
    return (
      <PageShell>
        <ErrorState
          label={t(locale, "error")}
          retryLabel={t(locale, "retry")}
          onRetry={reload}
        />
      </PageShell>
    );
  }

  return (
    <PageShell>
      <LargeTitle
        title={t(locale, "appName")}
        subtitle={t(locale, "thisMonth")}
      />

      <GlassPanel className="mb-6 animate-rise delay-1">
        <p className="text-[13px] font-medium uppercase tracking-[0.04em] text-[var(--label-secondary)]">
          {t(locale, "balance")}
        </p>
        <p
          className={`mt-1 text-[40px] font-bold tracking-tight tabular-nums ${
            totals.balance >= 0
              ? "text-[var(--label-primary)]"
              : "text-[var(--accent-red)]"
          }`}
        >
          {formatMoney(totals.balance, locale)}
        </p>
        <div className="mt-4 grid grid-cols-2 gap-3">
          <div className="rounded-[16px] bg-[color-mix(in_oklab,var(--accent-green)_14%,transparent)] px-3 py-2.5">
            <p className="text-[12px] text-[var(--label-secondary)]">
              {t(locale, "income")}
            </p>
            <p className="text-[17px] font-semibold tabular-nums text-[var(--accent-green)]">
              {formatMoney(totals.income, locale)}
            </p>
          </div>
          <div className="rounded-[16px] bg-[color-mix(in_oklab,var(--accent-red)_12%,transparent)] px-3 py-2.5">
            <p className="text-[12px] text-[var(--label-secondary)]">
              {t(locale, "expense")}
            </p>
            <p className="text-[17px] font-semibold tabular-nums text-[var(--accent-red)]">
              {formatMoney(totals.expense, locale)}
            </p>
          </div>
        </div>
      </GlassPanel>

      <div className="mb-3 flex items-center justify-between animate-rise delay-2">
        <h2 className="text-[20px] font-semibold tracking-tight text-[var(--label-primary)]">
          {t(locale, "recent")}
        </h2>
        <Link
          href="/history"
          className="text-[15px] font-medium text-[var(--accent-blue)]"
        >
          {t(locale, "seeAll")}
        </Link>
      </div>

      <GlassPanel className="animate-rise delay-3">
        {recent.length === 0 ? (
          <EmptyState
            icon={Inbox}
            title={t(locale, "emptyHome")}
            description={t(locale, "voiceHint")}
          />
        ) : (
          <ul className="divide-y divide-black/5 dark:divide-white/8">
            {recent.map((tx) => {
              const cat = byId.get(tx.categoryId);
              return (
                <li key={tx.id}>
                  <TransactionRow
                    tx={tx}
                    category={cat}
                    locale={locale}
                    categoryName={categoryDisplayName(cat, locale)}
                  />
                </li>
              );
            })}
          </ul>
        )}
      </GlassPanel>

      {recent.length === 0 ? (
        <Link
          href="/add"
          className="mt-4 inline-flex items-center justify-center gap-2 self-center rounded-full bg-[var(--accent-blue)] px-5 py-3 text-[15px] font-semibold text-white shadow-[0_8px_24px_rgba(10,132,255,0.35)] transition active:scale-[0.98]"
        >
          <Wallet className="size-4" />
          {t(locale, "add")}
        </Link>
      ) : null}
    </PageShell>
  );
}
