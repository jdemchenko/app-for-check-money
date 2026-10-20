import type { Category } from "./types";
import type { Locale } from "./i18n";

export function categoryDisplayName(category: Category | undefined, locale: Locale): string {
  if (!category) return locale === "ru" ? "Без категории" : "Uncategorized";
  return locale === "ru" ? category.nameRu : category.nameEn;
}
