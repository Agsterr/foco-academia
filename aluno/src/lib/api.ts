export const API_URL = process.env.NEXT_PUBLIC_API_URL ?? "http://localhost:8080";

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

const TOKEN_KEY = "academia_token";

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
    throw new Error(data.message ?? "Erro na requisição");
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
