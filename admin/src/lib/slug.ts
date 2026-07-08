/** Prévia do slug gerado no backend a partir do nome da academia. */
export function slugPreviewFromName(name: string): string {
  if (!name.trim()) return "";

  const normalized = name
    .trim()
    .toLowerCase()
    .normalize("NFD")
    .replace(/\p{M}/gu, "")
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-|-$/g, "");

  if (!normalized) return "academia";
  return normalized.length > 64 ? normalized.slice(0, 64) : normalized;
}
