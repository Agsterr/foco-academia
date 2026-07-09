const PREFIX = "academia_aluno";

export const TOKEN_KEY = `${PREFIX}_token`;
export const SLUG_KEY = `${PREFIX}_slug`;
const EMAIL_KEY = `${PREFIX}_login_email`;
const PASSWORD_KEY = `${PREFIX}_login_password`;
const REMEMBER_KEY = `${PREFIX}_remember`;

const LEGACY_TOKEN_KEY = "academia_token";
const LEGACY_SLUG_KEY = "academia_slug";

export interface SavedLogin {
  email: string;
  password: string;
  remember: boolean;
}

export function getSavedLogin(): SavedLogin {
  if (typeof window === "undefined") {
    return { email: "", password: "", remember: false };
  }
  const remember = localStorage.getItem(REMEMBER_KEY) === "1";
  if (!remember) {
    return { email: "", password: "", remember: false };
  }
  return {
    email: localStorage.getItem(EMAIL_KEY) ?? "",
    password: localStorage.getItem(PASSWORD_KEY) ?? "",
    remember: true,
  };
}

export function saveLogin(email: string, password: string) {
  localStorage.setItem(REMEMBER_KEY, "1");
  localStorage.setItem(EMAIL_KEY, email.trim());
  localStorage.setItem(PASSWORD_KEY, password);
}

export function clearSavedLogin() {
  localStorage.removeItem(REMEMBER_KEY);
  localStorage.removeItem(EMAIL_KEY);
  localStorage.removeItem(PASSWORD_KEY);
}

export function readStorageItem(key: string, legacyKey?: string): string | null {
  const value = localStorage.getItem(key);
  if (value) return value;
  if (!legacyKey) return null;
  const legacy = localStorage.getItem(legacyKey);
  if (legacy) {
    localStorage.setItem(key, legacy);
    localStorage.removeItem(legacyKey);
    return legacy;
  }
  return null;
}

export function writeStorageItem(key: string, value: string, legacyKey?: string) {
  localStorage.setItem(key, value);
  if (legacyKey) localStorage.removeItem(legacyKey);
}

export function removeStorageItem(key: string, legacyKey?: string) {
  localStorage.removeItem(key);
  if (legacyKey) localStorage.removeItem(legacyKey);
}
