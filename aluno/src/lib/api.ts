/** Em produção usa a mesma origem (nginx → /api). Em dev, defina NEXT_PUBLIC_API_URL. */
import type { MediaType, WeekDay } from "./workout";
import {
  SLUG_KEY,
  TOKEN_KEY,
  readStorageItem,
  removeStorageItem,
  writeStorageItem,
} from "./auth-storage";

export const API_URL = (process.env.NEXT_PUBLIC_API_URL ?? "").replace(/\/$/, "");

export type { WeekDay, MediaType } from "./workout";
export { weekDayLabels, weekDayShort, weekDayOrder } from "./workout";

export type UserRole = "INSTRUTOR" | "ALUNO";

export type RatingLevel = "MUITO_BOM" | "BOM" | "FACIL" | "RUIM" | "MUITO_RUIM";

export interface User {
  id: string;
  email: string;
  name: string;
  phone?: string;
  role: UserRole;
  instructorId?: string;
}

export interface Exercise {
  id: string;
  name: string;
  description?: string;
  sets?: number;
  reps?: number;
  duration?: string;
  videoUrl?: string;
  mediaType?: MediaType;
  variationNotes?: string;
  notes?: string;
  sortOrder: number;
}

export interface WorkoutDay {
  id: string;
  weekDay: WeekDay;
  muscleGroup?: string;
  notes?: string;
  restDay: boolean;
  sortOrder: number;
  exercises: Exercise[];
  activeSessionId?: string;
  completedThisWeek: boolean;
}

export interface WorkoutProgram {
  id: string;
  title: string;
  description?: string;
  active: boolean;
  createdAt: string;
  student: User;
  days: WorkoutDay[];
}

export interface SetLog {
  id: string;
  exerciseId: string;
  setNumber: number;
  completedAt: string;
  elapsedMs?: number;
}

export interface WorkoutSession {
  id: string;
  workoutDayId: string;
  startedAt: string;
  completedAt?: string;
  totalDurationSeconds?: number;
  rating?: RatingLevel;
  comment?: string;
  setLogs: SetLog[];
}

export interface StudentStats {
  daysCompletedThisWeek: number;
  totalWorkoutsCompleted: number;
  currentStreak: number;
  completedWeekDays: string[];
}

export interface SessionComplete {
  session: WorkoutSession;
  stats: StudentStats;
  message: string;
}

export interface Workout {
  id: string;
  title: string;
  description?: string;
  status: "RASCUNHO" | "ATIVO" | "CONCLUIDO";
  scheduledDate?: string;
  createdAt: string;
  student: User;
  exercises: Exercise[];
}

export interface Suggestion {
  id: string;
  message: string;
  category?: string;
  status: "PENDENTE" | "LIDA" | "RESPONDIDA";
  response?: string;
  createdAt: string;
  respondedAt?: string;
  student: User;
}

export interface Feedback {
  id: string;
  workoutId: string;
  rating: RatingLevel;
  completed: boolean;
  comment?: string;
  createdAt: string;
  student: User;
}

const LEGACY_TOKEN_KEY = "academia_token";
const LEGACY_SLUG_KEY = "academia_slug";

export function getAcademySlug(): string {
  if (typeof window === "undefined") return "";
  return readStorageItem(SLUG_KEY, LEGACY_SLUG_KEY) ?? "";
}

export function setAcademySlug(slug: string) {
  writeStorageItem(SLUG_KEY, slug.trim().toLowerCase(), LEGACY_SLUG_KEY);
}

export function getToken(): string | null {
  if (typeof window === "undefined") return null;
  return readStorageItem(TOKEN_KEY, LEGACY_TOKEN_KEY);
}

export function setToken(token: string) {
  writeStorageItem(TOKEN_KEY, token, LEGACY_TOKEN_KEY);
}

export function clearToken() {
  removeStorageItem(TOKEN_KEY, LEGACY_TOKEN_KEY);
}

export function getDeviceId(): string {
  const storageKey = "academia_device_id";
  const cookieName = "academia_device_id";

  const readCookie = (name: string) => {
    const match = document.cookie.match(new RegExp(`(?:^|; )${name}=([^;]*)`));
    return match ? decodeURIComponent(match[1]) : null;
  };

  const cookieDomain = () => {
    const host = window.location.hostname;
    if (host === "localhost" || host.endsWith(".localhost")) return undefined;
    if (host.endsWith("focodev.com.br")) return ".focodev.com.br";
    return undefined;
  };

  const writeCookie = (name: string, value: string) => {
    const domain = cookieDomain();
    let cookie = `${name}=${encodeURIComponent(value)}; path=/; max-age=31536000; samesite=lax`;
    if (domain) cookie += `; domain=${domain}`;
    document.cookie = cookie;
  };

  const fromCookie = readCookie(cookieName);
  if (fromCookie) {
    localStorage.setItem(storageKey, fromCookie);
    return fromCookie;
  }

  let id = localStorage.getItem(storageKey);
  if (!id) {
    id = crypto.randomUUID();
  }
  localStorage.setItem(storageKey, id);
  writeCookie(cookieName, id);
  return id;
}

export async function api<T>(
  path: string,
  options: RequestInit = {}
): Promise<T> {
  const token = getToken();
  const headers: Record<string, string> = {
    "Content-Type": "application/json",
    ...(options.headers as Record<string, string>),
  };
  if (token) headers.Authorization = `Bearer ${token}`;

  const response = await fetch(`${API_URL}${path}`, { ...options, headers });
  const data = await response.json().catch(() => ({}));

  if (!response.ok) {
    const message =
      typeof data.message === "string"
        ? data.message
        : Object.values(data as Record<string, unknown>)
            .filter((value): value is string => typeof value === "string")
            .join(" · ") || "Erro na requisição";
    throw new Error(message);
  }
  return data as T;
}

export const ratingLabels: Record<RatingLevel, string> = {
  MUITO_BOM: "Muito bom",
  BOM: "Bom",
  FACIL: "Fácil",
  RUIM: "Ruim",
  MUITO_RUIM: "Muito ruim",
};

export function mediaUrl(url?: string): string {
  if (!url) return "";
  return url.startsWith("http") ? url : `${API_URL}${url}`;
}

export function formatDuration(seconds?: number): string {
  if (!seconds) return "0:00";
  const m = Math.floor(seconds / 60);
  const s = seconds % 60;
  return `${m}:${s.toString().padStart(2, "0")}`;
}

export function formatElapsed(ms?: number): string {
  if (!ms) return "—";
  if (ms < 1000) return `${ms}ms`;
  const sec = Math.round(ms / 1000);
  if (sec < 60) return `${sec}s`;
  return formatDuration(sec);
}
