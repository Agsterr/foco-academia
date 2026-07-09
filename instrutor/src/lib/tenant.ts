import { API_URL } from "./api";

const COMPLETE_SLUG = /^[a-z0-9]+-[a-z0-9]+$/;

export function isCompleteAcademySlug(slug: string): boolean {
  const normalized = slug.trim().toLowerCase();
  return normalized.length >= 6 && COMPLETE_SLUG.test(normalized);
}

export async function lookupAcademyName(slug: string, signal?: AbortSignal): Promise<string> {
  const normalized = slug.trim().toLowerCase();
  if (!isCompleteAcademySlug(normalized)) return "";

  const response = await fetch(
    `${API_URL}/api/tenants/${encodeURIComponent(normalized)}`,
    { signal },
  );
  if (!response.ok) return "";
  const data = (await response.json()) as { name?: string };
  return data.name ?? "";
}
