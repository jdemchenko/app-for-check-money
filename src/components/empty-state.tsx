import { cn } from "@/lib/utils";
import type { LucideIcon } from "lucide-react";

export function EmptyState({
  icon: Icon,
  title,
  description,
  className,
}: {
  icon: LucideIcon;
  title: string;
  description?: string;
  className?: string;
}) {
  return (
    <div
      className={cn(
        "flex flex-col items-center justify-center gap-3 px-6 py-16 text-center animate-fade-in",
        className,
      )}
    >
      <div className="flex size-14 items-center justify-center rounded-full bg-[var(--fill-tertiary)] text-[var(--label-secondary)]">
        <Icon className="size-6" strokeWidth={1.6} />
      </div>
      <div className="space-y-1">
        <p className="text-[17px] font-semibold tracking-tight text-[var(--label-primary)]">
          {title}
        </p>
        {description ? (
          <p className="max-w-xs text-[15px] text-[var(--label-secondary)]">
            {description}
          </p>
        ) : null}
      </div>
    </div>
  );
}

export function LoadingState({ label }: { label: string }) {
  return (
    <div className="flex flex-1 flex-col items-center justify-center gap-3 py-24 animate-fade-in">
      <div className="size-8 animate-pulse rounded-full bg-[var(--fill-tertiary)]" />
      <p className="text-[15px] text-[var(--label-secondary)]">{label}</p>
    </div>
  );
}

export function ErrorState({
  label,
  retryLabel,
  onRetry,
}: {
  label: string;
  retryLabel: string;
  onRetry: () => void;
}) {
  return (
    <div className="flex flex-1 flex-col items-center justify-center gap-4 px-6 py-24 text-center animate-fade-in">
      <p className="text-[17px] font-medium text-[var(--label-primary)]">{label}</p>
      <button
        type="button"
        onClick={onRetry}
        className="rounded-full bg-[var(--accent-blue)] px-5 py-2.5 text-[15px] font-semibold text-white transition active:scale-[0.98]"
      >
        {retryLabel}
      </button>
    </div>
  );
}
