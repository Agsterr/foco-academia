import type { MediaType } from "@/lib/api";

export interface RecentMedia {
  url: string;
  mediaType: MediaType;
  name: string;
  usedAt: number;
}

const STORAGE_KEY = "instrutor-recent-media";
const MAX_ITEMS = 12;

export function getRecentMedia(): RecentMedia[] {
  if (typeof window === "undefined") return [];
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (!raw) return [];
    const items = JSON.parse(raw) as RecentMedia[];
    return Array.isArray(items) ? items.filter((item) => item.url && item.mediaType !== "NONE") : [];
  } catch {
    return [];
  }
}

export function addRecentMedia(item: Omit<RecentMedia, "usedAt">) {
  if (typeof window === "undefined") return;
  const next: RecentMedia = { ...item, usedAt: Date.now() };
  const existing = getRecentMedia().filter((entry) => entry.url !== next.url);
  localStorage.setItem(STORAGE_KEY, JSON.stringify([next, ...existing].slice(0, MAX_ITEMS)));
}

export function touchRecentMedia(url: string) {
  const items = getRecentMedia();
  const index = items.findIndex((item) => item.url === url);
  if (index < 0) return;
  const [item] = items.splice(index, 1);
  localStorage.setItem(STORAGE_KEY, JSON.stringify([{ ...item, usedAt: Date.now() }, ...items]));
}
