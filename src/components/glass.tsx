import { cn } from "@/lib/utils";
import type { HTMLAttributes } from "react";

export function GlassPanel({
  className,
  ...props
}: HTMLAttributes<HTMLDivElement>) {
  return (
    <div
      className={cn(
        "glass-panel rounded-[22px] border border-white/40 p-4 shadow-[0_8px_32px_rgba(15,23,42,0.06)] dark:border-white/10 dark:shadow-[0_8px_32px_rgba(0,0,0,0.35)]",
        className,
      )}
      {...props}
    />
  );
}

export function SoftSurface({
  className,
  ...props
}: HTMLAttributes<HTMLDivElement>) {
  return (
    <div
      className={cn(
        "rounded-[20px] bg-[color-mix(in_oklab,var(--surface)_88%,transparent)] p-4",
        className,
      )}
      {...props}
    />
  );
}
