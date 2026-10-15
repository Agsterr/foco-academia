const PREFIX = "academia_admin";

export const TOKEN_KEY = `${PREFIX}_token`;
const EMAIL_KEY = `${PREFIX}_login_email`;
const PASSWORD_KEY = `${PREFIX}_login_password`;
const REMEMBER_KEY = `${PREFIX}_remember`;

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
  // Remove senhas que versões antigas guardavam em texto puro
  localStorage.removeItem(PASSWORD_KEY);
  return {
    email: localStorage.getItem(EMAIL_KEY) ?? "",
    password: "",
    remember: true,
  };
}

/** Lembra apenas o e-mail. A senha nunca é salva no aparelho (ficava em texto puro no localStorage). */
export function saveLogin(email: string) {
  localStorage.setItem(REMEMBER_KEY, "1");
  localStorage.setItem(EMAIL_KEY, email.trim());
  localStorage.removeItem(PASSWORD_KEY);
}

export function clearSavedLogin() {
  localStorage.removeItem(REMEMBER_KEY);
  localStorage.removeItem(EMAIL_KEY);
  localStorage.removeItem(PASSWORD_KEY);
}
