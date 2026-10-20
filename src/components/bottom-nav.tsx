"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import {
  FolderOpen,
  Home,
  List,
  PlusCircle,
} from "lucide-react";
import { useApp } from "@/components/providers/app-provider";
import { t } from "@/lib/i18n";
import { cn } from "@/lib/utils";

const LINKS = [
  { href: "/", key: "home" as const, icon: Home },
  { href: "/add", key: "add" as const, icon: PlusCircle },
  { href: "/categories", key: "categories" as const, icon: FolderOpen },
  { href: "/history", key: "history" as const, icon: List },
];

export function BottomNav() {
  const pathname = usePathname();
  const { locale } = useApp();

  return (
    <nav className="pointer-events-none fixed inset-x-0 bottom-0 z-40 flex justify-center px-3 pb-[max(0.75rem,env(safe-area-inset-bottom))]">
      <div className="pointer-events-auto flex w-full max-w-lg items-stretch gap-1 rounded-[28px] border border-white/50 bg-[color-mix(in_oklab,var(--glass)_82%,transparent)] p-1.5 shadow-[0_12px_40px_rgba(15,23,42,0.12)] backdrop-blur-2xl dark:border-white/10 dark:shadow-[0_12px_40px_rgba(0,0,0,0.45)]">
        {LINKS.map(({ href, key, icon: Icon }) => {
          const active =
            href === "/" ? pathname === "/" : pathname.startsWith(href);
          return (
            <Link
              key={href}
              href={href}
              className={cn(
                "flex flex-1 flex-col items-center gap-0.5 rounded-[22px] px-2 py-2.5 text-[11px] font-medium transition",
                active
                  ? "bg-[var(--fill-secondary)] text-[var(--accent-blue)]"
                  : "text-[var(--label-secondary)] hover:text-[var(--label-primary)]",
              )}
            >
              <Icon
                className="size-5"
                strokeWidth={active ? 2.2 : 1.7}
              />
              <span>{t(locale, key)}</span>
            </Link>
          );
        })}
      </div>
    </nav>
  );
}
