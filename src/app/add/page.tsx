"use client";

import { useEffect, useMemo, useState } from "react";
import { useRouter } from "next/navigation";
import { Mic, MicOff, Sparkles } from "lucide-react";
import { toast } from "sonner";
import { CategoryGlyph } from "@/components/category-icon";
import { GlassPanel } from "@/components/glass";
import { LargeTitle, PageShell } from "@/components/page-shell";
import { useApp } from "@/components/providers/app-provider";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import { useSpeech } from "@/hooks/use-speech";
import { autoAssignCategory, categoriesForType } from "@/lib/categorize";
import { categoryDisplayName } from "@/lib/category-name";
import { todayISO } from "@/lib/format";
import { t } from "@/lib/i18n";
import type { TransactionType, VoiceDraft } from "@/lib/types";
import { parseVoiceText } from "@/lib/voice-parse";
import { cn } from "@/lib/utils";

type Mode = "manual" | "voice";

export default function AddPage() {
  const router = useRouter();
  const { locale, categories, addTransaction } = useApp();
  const [mode, setMode] = useState<Mode>("manual");

  const [amount, setAmount] = useState("");
  const [type, setType] = useState<TransactionType>("expense");
  const [categoryId, setCategoryId] = useState("");
  const [note, setNote] = useState("");
  const [date, setDate] = useState("");
  const [autoFlag, setAutoFlag] = useState(false);

  useEffect(() => {
    setDate((prev) => prev || todayISO());
  }, []);

  const [draft, setDraft] = useState<VoiceDraft | null>(null);
  const speech = useSpeech(locale);

  const available = useMemo(
    () => categoriesForType(categories, type),
    [categories, type],
  );

  useEffect(() => {
    if (!categoryId || !available.some((c) => c.id === categoryId)) {
      setCategoryId(available[0]?.id ?? "");
    }
  }, [available, categoryId]);

  // Auto-assign from note keywords when typing manually
  useEffect(() => {
    if (mode !== "manual") return;
    const text = `${note}`.trim();
    if (!text) {
      setAutoFlag(false);
      return;
    }
    const match = autoAssignCategory(text, categories, type);
    if (match && match.id !== categoryId) {
      setCategoryId(match.id);
      setAutoFlag(true);
    }
  }, [note, type, categories, mode, categoryId]);

  useEffect(() => {
    if (!speech.transcript) return;
    const parsed = parseVoiceText(speech.transcript, categories);
    setDraft(parsed);
    if (parsed.amount != null) setAmount(String(parsed.amount));
    if (parsed.type) setType(parsed.type);
    if (parsed.categoryId) {
      setCategoryId(parsed.categoryId);
      setAutoFlag(true);
    }
    if (parsed.note) setNote(parsed.note);
  }, [speech.transcript, categories]);

  function save(source: "manual" | "voice") {
    const value = Number.parseFloat(amount.replace(",", "."));
    if (!Number.isFinite(value) || value <= 0) {
      toast.error(t(locale, "requiredAmount"));
      return;
    }
    if (!categoryId) {
      toast.error(t(locale, "requiredCategory"));
      return;
    }
    addTransaction({
      amount: Math.round(value * 100) / 100,
      type,
      categoryId,
      note: note.trim() || undefined,
      date,
      source,
    });
    toast.success(t(locale, "saved"));
    router.push("/");
  }

  return (
    <PageShell>
      <LargeTitle title={t(locale, "add")} />

      <div className="mb-4 flex rounded-full bg-[var(--fill-tertiary)] p-1 animate-rise">
        {(["manual", "voice"] as const).map((m) => (
          <button
            key={m}
            type="button"
            onClick={() => setMode(m)}
            className={cn(
              "flex-1 rounded-full py-2.5 text-[15px] font-semibold transition",
              mode === m
                ? "bg-[var(--surface-elevated)] text-[var(--label-primary)] shadow-sm"
                : "text-[var(--label-secondary)]",
            )}
          >
            {t(locale, m)}
          </button>
        ))}
      </div>

      {mode === "voice" ? (
        <GlassPanel className="mb-4 animate-rise delay-1">
          {!speech.supported ? (
            <p className="text-[15px] leading-relaxed text-[var(--label-secondary)]">
              {t(locale, "voiceUnsupported")}
            </p>
          ) : (
            <div className="flex flex-col items-center gap-4 py-2">
              <p className="text-center text-[15px] text-[var(--label-secondary)]">
                {t(locale, "voiceHint")}
              </p>
              <button
                type="button"
                onClick={() => (speech.listening ? speech.stop() : speech.start())}
                className={cn(
                  "flex size-24 items-center justify-center rounded-full transition",
                  speech.listening
                    ? "animate-mic bg-[var(--accent-red)] text-white shadow-[0_12px_32px_rgba(255,69,58,0.4)]"
                    : "bg-[var(--accent-blue)] text-white shadow-[0_12px_32px_rgba(10,132,255,0.35)] active:scale-[0.97]",
                )}
                aria-pressed={speech.listening}
              >
                {speech.listening ? (
                  <MicOff className="size-9" />
                ) : (
                  <Mic className="size-9" />
                )}
              </button>
              <p className="text-[15px] font-medium text-[var(--label-primary)]">
                {speech.listening ? t(locale, "listening") : t(locale, "tapToSpeak")}
              </p>
              {speech.transcript ? (
                <p className="w-full rounded-[16px] bg-[var(--fill-tertiary)] px-3 py-2 text-center text-[14px] text-[var(--label-secondary)]">
                  “{speech.transcript}”
                </p>
              ) : null}
              {speech.error && speech.error !== "unsupported" ? (
                <p className="text-[13px] text-[var(--accent-red)]">{speech.error}</p>
              ) : null}
            </div>
          )}
        </GlassPanel>
      ) : null}

      {(mode === "manual" || draft || amount) && (
        <GlassPanel className="space-y-4 animate-rise delay-2">
          {draft && mode === "voice" ? (
            <div className="flex items-center gap-2 rounded-[14px] bg-[color-mix(in_oklab,var(--accent-blue)_12%,transparent)] px-3 py-2 text-[13px] text-[var(--accent-blue)]">
              <Sparkles className="size-3.5 shrink-0" />
              <span>
                {t(locale, "voiceDraft")}: {t(locale, "voiceParsed")}
              </span>
              <button
                type="button"
                className="ml-auto font-semibold"
                onClick={() => {
                  setDraft(null);
                  setAmount("");
                  setNote("");
                  setAutoFlag(false);
                }}
              >
                {t(locale, "clearDraft")}
              </button>
            </div>
          ) : null}

          <div className="space-y-2">
            <Label htmlFor="amount">{t(locale, "amount")}</Label>
            <Input
              id="amount"
              inputMode="decimal"
              placeholder="0"
              value={amount}
              onChange={(e) => setAmount(e.target.value)}
              className="h-14 rounded-[16px] border-0 bg-[var(--fill-tertiary)] text-[28px] font-bold tabular-nums shadow-none focus-visible:ring-[var(--accent-blue)]"
            />
          </div>

          <div className="space-y-2">
            <Label>{t(locale, "type")}</Label>
            <div className="grid grid-cols-2 gap-2">
              {(["expense", "income"] as const).map((opt) => (
                <button
                  key={opt}
                  type="button"
                  onClick={() => {
                    setType(opt);
                    setAutoFlag(false);
                  }}
                  className={cn(
                    "rounded-[14px] py-3 text-[15px] font-semibold transition",
                    type === opt
                      ? opt === "expense"
                        ? "bg-[color-mix(in_oklab,var(--accent-red)_18%,transparent)] text-[var(--accent-red)]"
                        : "bg-[color-mix(in_oklab,var(--accent-green)_18%,transparent)] text-[var(--accent-green)]"
                      : "bg-[var(--fill-tertiary)] text-[var(--label-secondary)]",
                  )}
                >
                  {t(locale, opt === "expense" ? "expenses" : "incomes")}
                </button>
              ))}
            </div>
          </div>

          <div className="space-y-2">
            <div className="flex items-center justify-between">
              <Label>{t(locale, "category")}</Label>
              {autoFlag ? (
                <span className="rounded-full bg-[color-mix(in_oklab,var(--accent-blue)_14%,transparent)] px-2 py-0.5 text-[11px] font-semibold text-[var(--accent-blue)]">
                  {t(locale, "autoAssigned")}
                </span>
              ) : null}
            </div>
            <div className="grid max-h-48 grid-cols-1 gap-1.5 overflow-y-auto sm:grid-cols-2">
              {available.map((cat) => {
                const selected = cat.id === categoryId;
                return (
                  <button
                    key={cat.id}
                    type="button"
                    onClick={() => {
                      setCategoryId(cat.id);
                      setAutoFlag(false);
                    }}
                    className={cn(
                      "flex items-center gap-2 rounded-[14px] px-2.5 py-2 text-left transition",
                      selected
                        ? "bg-[color-mix(in_oklab,var(--accent-blue)_14%,transparent)] ring-1 ring-[var(--accent-blue)]/40"
                        : "bg-[var(--fill-tertiary)]",
                    )}
                  >
                    <CategoryGlyph icon={cat.icon} color={cat.color} size="sm" />
                    <span className="truncate text-[14px] font-medium">
                      {categoryDisplayName(cat, locale)}
                    </span>
                  </button>
                );
              })}
            </div>
          </div>

          <div className="space-y-2">
            <Label htmlFor="note">{t(locale, "note")}</Label>
            <Textarea
              id="note"
              rows={2}
              placeholder={t(locale, "notePlaceholder")}
              value={note}
              onChange={(e) => setNote(e.target.value)}
              className="rounded-[16px] border-0 bg-[var(--fill-tertiary)] shadow-none focus-visible:ring-[var(--accent-blue)]"
            />
          </div>

          <div className="space-y-2">
            <Label htmlFor="date">{t(locale, "date")}</Label>
            <Input
              id="date"
              type="date"
              value={date}
              onChange={(e) => setDate(e.target.value)}
              className="h-12 rounded-[16px] border-0 bg-[var(--fill-tertiary)] shadow-none"
            />
          </div>

          <Button
            type="button"
            onClick={() => save(mode === "voice" ? "voice" : "manual")}
            className="h-12 w-full rounded-full bg-[var(--accent-blue)] text-[16px] font-semibold text-white hover:bg-[var(--accent-blue)]/90"
          >
            {mode === "voice" ? t(locale, "confirm") : t(locale, "save")}
          </Button>
        </GlassPanel>
      )}
    </PageShell>
  );
}
