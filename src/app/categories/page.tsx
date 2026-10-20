"use client";

import { useMemo, useState } from "react";
import { FolderOpen, Plus, RotateCcw, Trash2 } from "lucide-react";
import { toast } from "sonner";
import { CategoryGlyph } from "@/components/category-icon";
import { EmptyState } from "@/components/empty-state";
import { GlassPanel } from "@/components/glass";
import { LargeTitle, PageShell } from "@/components/page-shell";
import { useApp } from "@/components/providers/app-provider";
import { Button } from "@/components/ui/button";
import {
  Dialog,
  DialogContent,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { categoryDisplayName } from "@/lib/category-name";
import { t } from "@/lib/i18n";
import type { TransactionType } from "@/lib/types";

export default function CategoriesPage() {
  const {
    locale,
    categories,
    addCategory,
    updateCategory,
    deleteCategory,
    restoreDefaultCategories,
  } = useApp();

  const [open, setOpen] = useState(false);
  const [editingId, setEditingId] = useState<string | null>(null);
  const [nameRu, setNameRu] = useState("");
  const [nameEn, setNameEn] = useState("");
  const [type, setType] = useState<TransactionType | "both">("expense");
  const [keywords, setKeywords] = useState("");
  const [color, setColor] = useState("#0A84FF");

  const defaults = useMemo(
    () => categories.filter((c) => c.isDefault),
    [categories],
  );
  const custom = useMemo(
    () => categories.filter((c) => !c.isDefault),
    [categories],
  );

  function resetForm() {
    setEditingId(null);
    setNameRu("");
    setNameEn("");
    setType("expense");
    setKeywords("");
    setColor("#0A84FF");
  }

  function openCreate() {
    resetForm();
    setOpen(true);
  }

  function openEdit(id: string) {
    const cat = categories.find((c) => c.id === id);
    if (!cat) return;
    setEditingId(id);
    setNameRu(cat.nameRu);
    setNameEn(cat.nameEn);
    setType(cat.type);
    setKeywords(cat.keywords.join(", "));
    setColor(cat.color);
    setOpen(true);
  }

  function submit() {
    const kw = keywords
      .split(",")
      .map((s) => s.trim())
      .filter(Boolean);
    const ru = nameRu.trim();
    const en = nameEn.trim() || ru;
    if (!ru) {
      toast.error(t(locale, "categoryName"));
      return;
    }

    if (editingId) {
      updateCategory(editingId, {
        nameRu: ru,
        nameEn: en,
        type,
        keywords: kw,
        color,
      });
    } else {
      addCategory({
        nameRu: ru,
        nameEn: en,
        type,
        keywords: kw,
        color,
        icon: "circle",
      });
    }
    toast.success(t(locale, "saved"));
    setOpen(false);
    resetForm();
  }

  function renderList(
    title: string,
    list: typeof categories,
    allowDelete: boolean,
  ) {
    if (list.length === 0) return null;
    return (
      <section className="mb-5">
        <h2 className="mb-2 px-1 text-[13px] font-semibold uppercase tracking-[0.04em] text-[var(--label-secondary)]">
          {title}
        </h2>
        <GlassPanel className="divide-y divide-black/5 p-2 dark:divide-white/8">
          {list.map((cat) => (
            <div
              key={cat.id}
              className="flex items-center gap-3 px-2 py-2.5"
            >
              <button
                type="button"
                className="flex min-w-0 flex-1 items-center gap-3 text-left"
                onClick={() => openEdit(cat.id)}
              >
                <CategoryGlyph icon={cat.icon} color={cat.color} />
                <div className="min-w-0">
                  <p className="truncate text-[16px] font-medium text-[var(--label-primary)]">
                    {categoryDisplayName(cat, locale)}
                  </p>
                  <p className="truncate text-[12px] text-[var(--label-tertiary)]">
                    {cat.keywords.slice(0, 4).join(", ") || "—"}
                  </p>
                </div>
              </button>
              {allowDelete ? (
                <button
                  type="button"
                  aria-label={t(locale, "delete")}
                  className="rounded-full p-2 text-[var(--accent-red)] transition hover:bg-[color-mix(in_oklab,var(--accent-red)_12%,transparent)]"
                  onClick={() => {
                    deleteCategory(cat.id);
                    toast.success(t(locale, "deleted"));
                  }}
                >
                  <Trash2 className="size-4" />
                </button>
              ) : null}
            </div>
          ))}
        </GlassPanel>
      </section>
    );
  }

  return (
    <PageShell>
      <LargeTitle
        title={t(locale, "categories")}
        trailing={
          <div className="flex gap-2">
            <button
              type="button"
              onClick={() => {
                restoreDefaultCategories();
                toast.success(t(locale, "saved"));
              }}
              className="rounded-full bg-[var(--fill-tertiary)] p-2.5 text-[var(--label-secondary)]"
              aria-label={t(locale, "restoreDefaults")}
              title={t(locale, "restoreDefaults")}
            >
              <RotateCcw className="size-4" />
            </button>
            <button
              type="button"
              onClick={openCreate}
              className="rounded-full bg-[var(--accent-blue)] p-2.5 text-white"
              aria-label={t(locale, "addCategory")}
            >
              <Plus className="size-4" />
            </button>
          </div>
        }
      />

      {categories.length === 0 ? (
        <EmptyState icon={FolderOpen} title={t(locale, "emptyCategories")} />
      ) : (
        <div className="animate-rise delay-1">
          {renderList(t(locale, "defaultCategories"), defaults, false)}
          {renderList(t(locale, "customCategories"), custom, true)}
        </div>
      )}

      <Dialog open={open} onOpenChange={setOpen}>
        <DialogContent className="rounded-[24px] border-0 bg-[var(--surface-elevated)] sm:max-w-md">
          <DialogHeader>
            <DialogTitle>
              {editingId ? t(locale, "edit") : t(locale, "addCategory")}
            </DialogTitle>
          </DialogHeader>
          <div className="space-y-3 py-2">
            <div className="space-y-1.5">
              <Label>{t(locale, "nameRu")}</Label>
              <Input
                value={nameRu}
                onChange={(e) => setNameRu(e.target.value)}
                className="rounded-[14px] border-0 bg-[var(--fill-tertiary)]"
              />
            </div>
            <div className="space-y-1.5">
              <Label>{t(locale, "nameEn")}</Label>
              <Input
                value={nameEn}
                onChange={(e) => setNameEn(e.target.value)}
                className="rounded-[14px] border-0 bg-[var(--fill-tertiary)]"
              />
            </div>
            <div className="space-y-1.5">
              <Label>{t(locale, "type")}</Label>
              <div className="grid grid-cols-3 gap-1.5">
                {(["expense", "income", "both"] as const).map((opt) => (
                  <button
                    key={opt}
                    type="button"
                    onClick={() => setType(opt)}
                    className={`rounded-[12px] py-2 text-[13px] font-semibold ${
                      type === opt
                        ? "bg-[var(--accent-blue)] text-white"
                        : "bg-[var(--fill-tertiary)] text-[var(--label-secondary)]"
                    }`}
                  >
                    {t(
                      locale,
                      opt === "expense"
                        ? "expenses"
                        : opt === "income"
                          ? "incomes"
                          : "both",
                    )}
                  </button>
                ))}
              </div>
            </div>
            <div className="space-y-1.5">
              <Label>{t(locale, "keywords")}</Label>
              <Input
                value={keywords}
                onChange={(e) => setKeywords(e.target.value)}
                placeholder={t(locale, "keywordsHint")}
                className="rounded-[14px] border-0 bg-[var(--fill-tertiary)]"
              />
            </div>
            <div className="space-y-1.5">
              <Label>Color</Label>
              <Input
                type="color"
                value={color}
                onChange={(e) => setColor(e.target.value)}
                className="h-12 cursor-pointer rounded-[14px] border-0 bg-[var(--fill-tertiary)] p-1"
              />
            </div>
          </div>
          <DialogFooter>
            <Button
              type="button"
              variant="ghost"
              onClick={() => setOpen(false)}
            >
              {t(locale, "cancel")}
            </Button>
            <Button
              type="button"
              onClick={submit}
              className="rounded-full bg-[var(--accent-blue)] text-white"
            >
              {t(locale, "save")}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </PageShell>
  );
}
