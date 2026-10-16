"use client";

import { FormEvent, useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import PasswordInput from "@/components/PasswordInput";
import { api, getAcademySlug, getDeviceId, setAcademySlug, setToken } from "@/lib/api";
import { clearSavedLogin, getSavedLogin, saveLogin } from "@/lib/auth-storage";
import { lookupAcademyName } from "@/lib/tenant";
import { useHydrated } from "@/lib/use-hydrated";

export default function LoginPage() {
  // Os valores iniciais vêm do localStorage: só monta o formulário no cliente.
  const hydrated = useHydrated();
  return hydrated ? <LoginForm /> : null;
}

function LoginForm() {
  const router = useRouter();
  const [academySlug, setSlug] = useState(getAcademySlug);
  const [academyName, setAcademyName] = useState("");
  const [email, setEmail] = useState(() => getSavedLogin().email);
  const [password, setPassword] = useState("");
  const [remember, setRemember] = useState(() => getSavedLogin().remember);
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    const controller = new AbortController();
    const timer = window.setTimeout(() => {
      void lookupAcademyName(academySlug, controller.signal)
        .then(setAcademyName)
        .catch(() => setAcademyName(""));
    }, 400);
    return () => {
      window.clearTimeout(timer);
      controller.abort();
    };
  }, [academySlug]);

  async function handleSubmit(e: FormEvent) {
    e.preventDefault();
    setLoading(true);
    setError("");
    try {
      setAcademySlug(academySlug);
      const data = await api<{ token: string }>("/api/auth/login", {
        method: "POST",
        body: JSON.stringify({
          email,
          password,
          academySlug: academySlug.trim(),
          deviceId: getDeviceId(),
          deviceLabel: typeof navigator !== "undefined" ? navigator.userAgent.slice(0, 80) : undefined,
        }),
      });
      if (remember) {
        saveLogin(email);
      } else {
        clearSavedLogin();
      }
      setToken(data.token);
      router.push("/");
    } catch (err) {
      setError(err instanceof Error ? err.message : "Erro ao entrar");
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="mx-auto flex min-h-screen max-w-md flex-col justify-center px-4 py-10">
      <div className="relative overflow-hidden rounded-3xl border border-slate-800 bg-slate-900/80 p-6 shadow-2xl shadow-black/40 backdrop-blur sm:p-8">
        <div className="pointer-events-none absolute -right-16 -top-16 h-48 w-48 rounded-full bg-violet-500/25 blur-3xl" />
        <span className="relative mb-5 flex h-12 w-12 items-center justify-center rounded-2xl bg-gradient-to-br from-violet-400 to-violet-700 text-2xl shadow-lg shadow-violet-900/50">🏋️</span>
        <h1 className="text-2xl font-bold text-violet-400">Painel do Instrutor</h1>
        <p className="mt-1 text-sm text-slate-400">Gerencie alunos e treinos da sua academia</p>

        <form onSubmit={handleSubmit} className="mt-6 space-y-4" autoComplete="off">
          <div>
            <label htmlFor="instrutor-academy-slug" className="mb-1 block text-sm text-slate-300">
              Código da academia
            </label>
            <input
              id="instrutor-academy-slug"
              name="instrutor-academy-slug"
              value={academySlug}
              onChange={(e) => setSlug(e.target.value.toLowerCase())}
              placeholder="ex: academia-demo"
              className="form-input"
              required
              autoComplete="off"
            />
            {academyName && <p className="mt-1 text-xs text-violet-300">{academyName}</p>}
          </div>
          <div>
            <label htmlFor="instrutor-login-email" className="mb-1 block text-sm text-slate-300">
              E-mail
            </label>
            <input
              id="instrutor-login-email"
              name="instrutor-login-email"
              type="email"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              className="form-input"
              required
              autoComplete="off"
              data-lpignore="true"
              data-1p-ignore="true"
            />
          </div>
          <div>
            <label htmlFor="instrutor-login-password" className="mb-1 block text-sm text-slate-300">
              Senha
            </label>
            <PasswordInput
              id="instrutor-login-password"
              value={password}
              onChange={setPassword}
              required
            />
          </div>
          <label className="flex items-center gap-2 text-sm text-slate-300">
            <input
              type="checkbox"
              checked={remember}
              onChange={(e) => setRemember(e.target.checked)}
            />
            Lembrar meu e-mail neste aparelho
          </label>
          {error && (
            <div className="text-sm text-red-400">
              <p>{error}</p>
              {error.includes("Administrador da plataforma") && (
                <p className="mt-2 text-slate-400">
                  Acesse o painel admin em{" "}
                  <a
                    href="https://academia.focodev.com.br/admin/login"
                    className="text-violet-400 underline"
                  >
                    academia.focodev.com.br/admin
                  </a>
                  . Para instrutor, use o e-mail cadastrado na academia.
                </p>
              )}
            </div>
          )}
          <button type="submit" disabled={loading} className="btn-primary w-full">
            {loading ? "Entrando..." : "Entrar"}
          </button>
        </form>
      </div>
    </div>
  );
}
