"use client";

import type { ReactNode } from "react";
import { BottomNav } from "./bottom-nav";
import { cn } from "@/lib/utils";

export function PageShell({
  children,
  className,
}: {
  children: ReactNode;
  className?: string;
}) {
  return (
    <div className="relative flex min-h-dvh flex-col">
      <div className="atmosphere" aria-hidden />
      <main
        className={cn(
          "relative z-10 mx-auto flex w-full max-w-lg flex-1 flex-col px-4 pb-28 pt-[max(1rem,env(safe-area-inset-top))] md:max-w-2xl md:px-6",
          className,
        )}
      >
        {children}
      </main>
      <BottomNav />
    </div>
  );
}

export function LargeTitle({
  title,
  subtitle,
  trailing,
}: {
  title: string;
  subtitle?: string;
  trailing?: ReactNode;
}) {
  return (
    <header className="mb-5 flex items-end justify-between gap-3 animate-rise">
      <div className="min-w-0">
        <h1 className="text-[34px] font-bold leading-[1.05] tracking-tight text-[var(--label-primary)]">
          {title}
        </h1>
        {subtitle ? (
          <p className="mt-1 text-[15px] text-[var(--label-secondary)]">
            {subtitle}
          </p>
        ) : null}
      </div>
      {trailing}
    </header>
  );
}
