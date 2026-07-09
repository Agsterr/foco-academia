/** Em produção usa a mesma origem (nginx → /api). Em dev, defina NEXT_PUBLIC_API_URL. */
export const API_URL = (process.env.NEXT_PUBLIC_API_URL ?? "").replace(/\/$/, "");

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
  notes?: string;
  sortOrder: number;
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

export interface Dashboard {
  totalStudents: number;
  activeWorkouts: number;
  pendingSuggestions: number;
}

const TOKEN_KEY = "academia_token";
const ACADEMY_SLUG_KEY = "academia_slug";

export function getAcademySlug(): string {
  if (typeof window === "undefined") return "";
  return localStorage.getItem(ACADEMY_SLUG_KEY) ?? "";
}

export function setAcademySlug(slug: string) {
  localStorage.setItem(ACADEMY_SLUG_KEY, slug.trim().toLowerCase());
}

export function getToken(): string | null {
  if (typeof window === "undefined") return null;
  return localStorage.getItem(TOKEN_KEY);
}

export function setToken(token: string) {
  localStorage.setItem(TOKEN_KEY, token);
}

export function clearToken() {
  localStorage.removeItem(TOKEN_KEY);
}

export function getDeviceId(): string {
  const key = "academia_device_id";
  let id = localStorage.getItem(key);
  if (!id) {
    id = crypto.randomUUID();
    localStorage.setItem(key, id);
  }
  return id;
}

export async function api<T>(
  path: string,
  options: RequestInit = {}
): Promise<T> {
  const token = getToken();
  const headers: Record<string, string> = {
    ...(options.headers as Record<string, string>),
  };

  if (!(options.body instanceof FormData)) {
    headers["Content-Type"] = "application/json";
  }
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

export async function uploadMedia(file: File): Promise<string> {
  const form = new FormData();
  form.append("file", file);
  const result = await api<{ url: string }>("/api/instructor/media", {
    method: "POST",
    body: form,
  });
  return result.url.startsWith("http") ? result.url : `${API_URL}${result.url}`;
}

export const ratingLabels: Record<RatingLevel, string> = {
  MUITO_BOM: "Muito bom",
  BOM: "Bom",
  FACIL: "Fácil",
  RUIM: "Ruim",
  MUITO_RUIM: "Muito ruim",
};
