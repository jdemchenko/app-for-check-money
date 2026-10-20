"use client";

import type { Category, Transaction } from "@/lib/types";
import type { Locale } from "@/lib/i18n";
import { formatDayLabel, formatSignedMoney } from "@/lib/format";
import { CategoryGlyph } from "./category-icon";

export function TransactionRow({
  tx,
  category,
  locale,
  categoryName,
  onClick,
}: {
  tx: Transaction;
  category?: Category;
  locale: Locale;
  categoryName: string;
  onClick?: () => void;
}) {
  const amountClass =
    tx.type === "income"
      ? "text-[var(--accent-green)]"
      : "text-[var(--label-primary)]";

  return (
    <button
      type="button"
      onClick={onClick}
      className="flex w-full items-center gap-3 rounded-[16px] px-1 py-2.5 text-left transition hover:bg-black/[0.03] active:scale-[0.995] dark:hover:bg-white/[0.04]"
    >
      <CategoryGlyph
        icon={category?.icon ?? "circle"}
        color={category?.color ?? "#8E8E93"}
      />
      <div className="min-w-0 flex-1">
        <p className="truncate text-[16px] font-medium tracking-tight text-[var(--label-primary)]">
          {categoryName}
        </p>
        <p className="truncate text-[13px] text-[var(--label-secondary)]">
          {tx.note?.trim() || formatDayLabel(tx.date, locale)}
        </p>
      </div>
      <div className="text-right">
        <p className={`text-[16px] font-semibold tabular-nums ${amountClass}`}>
          {formatSignedMoney(tx.amount, tx.type, locale)}
        </p>
        {tx.note?.trim() ? (
          <p className="text-[12px] text-[var(--label-tertiary)]">
            {formatDayLabel(tx.date, locale)}
          </p>
        ) : null}
      </div>
    </button>
  );
}
