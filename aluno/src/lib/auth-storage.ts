const PREFIX = "academia_aluno";

export const TOKEN_KEY = `${PREFIX}_token`;
export const SLUG_KEY = `${PREFIX}_slug`;
const EMAIL_KEY = `${PREFIX}_login_email`;
const LEGACY_PASSWORD_KEY = `${PREFIX}_login_password`;
const REMEMBER_KEY = `${PREFIX}_remember`;

export interface SavedLogin {
  email: string;
  remember: boolean;
}

/** Remove a senha gravada por versões antigas (ficava em texto puro no localStorage). */
function purgeLegacyPassword() {
  localStorage.removeItem(LEGACY_PASSWORD_KEY);
}

export function getSavedLogin(): SavedLogin {
  if (typeof window === "undefined") {
    return { email: "", remember: false };
  }
  purgeLegacyPassword();
  const remember = localStorage.getItem(REMEMBER_KEY) === "1";
  if (!remember) {
    return { email: "", remember: false };
  }
  return {
    email: localStorage.getItem(EMAIL_KEY) ?? "",
    remember: true,
  };
}

export function saveLogin(email: string) {
  localStorage.setItem(REMEMBER_KEY, "1");
  localStorage.setItem(EMAIL_KEY, email.trim());
  purgeLegacyPassword();
}

export function clearSavedLogin() {
  localStorage.removeItem(REMEMBER_KEY);
  localStorage.removeItem(EMAIL_KEY);
  purgeLegacyPassword();
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
