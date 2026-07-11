/** Em produção usa a mesma origem (nginx → /api). Em dev, defina NEXT_PUBLIC_API_URL. */
export const API_URL = (process.env.NEXT_PUBLIC_API_URL ?? "").replace(/\/$/, "");

export interface Academy {
  id: string;
  name: string;
  slug: string;
  deviceLimitPerUser: number;
  active: boolean;
  appBlocked: boolean;
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

export interface DeviceSession {
  id: string;
  deviceId: string;
  deviceLabel?: string;
  appClient: "WEB" | "MOBILE";
  appVersion?: string;
  lastSeenAt: string;
}

export interface Dashboard {
  totalAcademies: number;
  activeAcademies: number;
  totalInstructors: number;
  totalStudents: number;
}

export interface AppRelease {
  id: string;
  versionName: string;
  versionCode: number;
  fileName: string;
  fileSizeBytes: number;
  sha256: string;
  releaseNotes?: string;
  forceUpdate: boolean;
  active: boolean;
  downloadUrl: string;
  createdAt: string;
}

export interface ConnectedDevice {
  sessionId: string;
  userId: string;
  userName: string;
  userEmail: string;
  deviceId: string;
  deviceLabel?: string;
  appClient: string;
  appVersion?: string;
  appVersionCode?: number;
  needsUpdate: boolean;
  lastSeenAt: string;
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

export async function api<T>(path: string, options: RequestInit = {}): Promise<T> {
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

export function formatDate(iso?: string) {
  if (!iso) return "Nunca";
  return new Date(iso).toLocaleString("pt-BR");
}

export async function listAppReleases(): Promise<AppRelease[]> {
  return api<AppRelease[]>("/api/admin/releases");
}

export async function listConnectedDevices(): Promise<ConnectedDevice[]> {
  return api<ConnectedDevice[]>("/api/admin/releases/connected-devices");
}

export async function setReleaseForceUpdate(id: string, forceUpdate: boolean): Promise<AppRelease> {
  return api<AppRelease>(`/api/admin/releases/${id}/force-update`, {
    method: "PATCH",
    body: JSON.stringify({ forceUpdate }),
  });
}

export async function downloadAppRelease(id: string): Promise<Blob> {
  const token = getToken();
  const response = await fetch(`${API_URL}/api/admin/releases/${id}/download`, {
    headers: token ? { Authorization: `Bearer ${token}` } : {},
  });
  if (!response.ok) throw new Error("Erro ao baixar APK");
  return response.blob();
}

export async function uploadAppRelease(data: {
  file: File;
  versionName: string;
  versionCode: number;
  releaseNotes?: string;
  forceUpdate: boolean;
}): Promise<AppRelease> {
  const token = getToken();
  const form = new FormData();
  form.append("file", data.file);
  form.append("versionName", data.versionName);
  form.append("versionCode", String(data.versionCode));
  if (data.releaseNotes) form.append("releaseNotes", data.releaseNotes);
  form.append("forceUpdate", String(data.forceUpdate));
  const response = await fetch(`${API_URL}/api/admin/releases`, {
    method: "POST",
    headers: token ? { Authorization: `Bearer ${token}` } : {},
    body: form,
  });
  const json = await response.json().catch(() => ({}));
  if (!response.ok) {
    throw new Error(typeof json.message === "string" ? json.message : "Erro ao publicar APK");
  }
  return json as AppRelease;
}
