/** Splits items into chunks of at most `size` (Firestore batch limit is 500). */
export function chunk<T>(items: readonly T[], size = 500): T[][] {
  if (!Number.isInteger(size) || size < 1) throw new Error("size must be >= 1");
  const out: T[][] = [];
  for (let i = 0; i < items.length; i += size) out.push(items.slice(i, i + size));
  return out;
}
