import type { Category, TransactionType } from "./types";

/** Score categories by keyword hits in free text; returns best match or null. */
export function autoAssignCategory(
  text: string,
  categories: Category[],
  preferredType?: TransactionType | null,
): Category | null {
  const normalized = text.toLowerCase().trim();
  if (!normalized) return null;

  let best: { category: Category; score: number } | null = null;

  for (const category of categories) {
    if (preferredType && category.type !== "both" && category.type !== preferredType) {
      continue;
    }

    let score = 0;
    for (const keyword of category.keywords) {
      const k = keyword.toLowerCase().trim();
      if (!k) continue;
      if (normalized.includes(k)) {
        // Longer keywords win ties
        score += Math.max(1, k.length / 3);
      }
    }

    if (score > 0 && (!best || score > best.score)) {
      best = { category, score };
    }
  }

  return best?.category ?? null;
}

export function categoriesForType(
  categories: Category[],
  type: TransactionType,
): Category[] {
  return categories.filter((c) => c.type === type || c.type === "both");
}
