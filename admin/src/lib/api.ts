export const API_URL = process.env.NEXT_PUBLIC_API_URL ?? "http://localhost:8080";

export interface Academy {
  id: string;
  name: string;
  slug: string;
  deviceLimitPerUser: number;
  active: boolean;
  createdAt: string;
  instructorCount: number;
  studentCount: number;
}

export interface AdminUser {
  id: string;
  email: string;
  name: string;
  phone?: string;
  role: "ADMIN" | "INSTRUTOR" | "ALUNO";
  academyId?: string;
  academyName?: string;
  instructorId?: string;
  lastLoginAt?: string;
  deviceCount: number;
  active: boolean;
}

export interface Dashboard {
  totalAcademies: number;
  activeAcademies: number;
  totalInstructors: number;
  totalStudents: number;
}

const TOKEN_KEY = "academia_admin_token";

export function getToken() {
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

export async function api<T>(path: string, options: RequestInit = {}): Promise<T> {
  const token = getToken();
  const headers: Record<string, string> = {
    "Content-Type": "application/json",
    ...(options.headers as Record<string, string>),
  };
  if (token) headers.Authorization = `Bearer ${token}`;

  const response = await fetch(`${API_URL}${path}`, { ...options, headers });
  const data = await response.json().catch(() => ({}));
  if (!response.ok) throw new Error(data.message ?? "Erro na requisição");
  return data as T;
}

export function formatDate(iso?: string) {
  if (!iso) return "Nunca";
  return new Date(iso).toLocaleString("pt-BR");
}
