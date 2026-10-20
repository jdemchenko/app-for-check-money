import {
  Briefcase,
  Car,
  Circle,
  Clapperboard,
  Gift,
  Heart,
  Home,
  Laptop,
  ShoppingBag,
  Utensils,
  Wallet,
  type LucideIcon,
} from "lucide-react";
import { cn } from "@/lib/utils";

const ICONS: Record<string, LucideIcon> = {
  utensils: Utensils,
  car: Car,
  home: Home,
  "shopping-bag": ShoppingBag,
  heart: Heart,
  clapperboard: Clapperboard,
  circle: Circle,
  briefcase: Briefcase,
  laptop: Laptop,
  gift: Gift,
  wallet: Wallet,
};

export function CategoryGlyph({
  icon,
  color,
  size = "md",
  className,
}: {
  icon: string;
  color: string;
  size?: "sm" | "md" | "lg";
  className?: string;
}) {
  const Icon = ICONS[icon] ?? Circle;
  const dim =
    size === "sm" ? "size-8" : size === "lg" ? "size-12" : "size-10";
  const iconSize =
    size === "sm" ? "size-3.5" : size === "lg" ? "size-5" : "size-4";

  return (
    <div
      className={cn(
        "flex shrink-0 items-center justify-center rounded-full",
        dim,
        className,
      )}
      style={{ backgroundColor: `${color}22`, color }}
    >
      <Icon className={iconSize} strokeWidth={1.8} />
    </div>
  );
}
