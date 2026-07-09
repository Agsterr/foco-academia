"use client";

import { FormEvent, useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import PasswordInput from "@/components/PasswordInput";
import { api, getAcademySlug, getDeviceId, setAcademySlug, setToken } from "@/lib/api";
import { clearSavedLogin, getSavedLogin, saveLogin } from "@/lib/auth-storage";
import { lookupAcademyName } from "@/lib/tenant";

export default function LoginPage() {
  const router = useRouter();
  const [academySlug, setSlug] = useState("academia-demo");
  const [academyName, setAcademyName] = useState("");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [remember, setRemember] = useState(true);
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    const savedSlug = getAcademySlug();
    if (savedSlug) setSlug(savedSlug);

    const savedLogin = getSavedLogin();
    if (savedLogin.remember) {
      setEmail(savedLogin.email);
      setPassword(savedLogin.password);
      setRemember(true);
    }
  }, []);

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
        saveLogin(email, password);
      } else {
        clearSavedLogin();
      }
      setToken(data.token);
      router.push("/treinos");
    } catch (err) {
      setError(err instanceof Error ? err.message : "Erro ao entrar");
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="mx-auto flex min-h-full max-w-lg flex-col justify-center px-4 py-8">
      <div className="rounded-2xl border border-slate-800 bg-slate-900 p-6 shadow-xl">
        <h1 className="text-2xl font-bold text-blue-400">Área do Aluno</h1>
        <p className="mt-1 text-sm text-slate-400">Acesse seus treinos na sua academia</p>

        <form onSubmit={handleSubmit} className="mt-6 space-y-4" autoComplete="off">
          <div>
            <label htmlFor="aluno-academy-slug" className="mb-1 block text-sm text-slate-300">
              Código da academia
            </label>
            <input
              id="aluno-academy-slug"
              name="aluno-academy-slug"
              value={academySlug}
              onChange={(e) => setSlug(e.target.value.toLowerCase())}
              placeholder="ex: academia-demo"
              className="form-input"
              required
              autoComplete="off"
            />
            {academyName && <p className="mt-1 text-xs text-blue-300">{academyName}</p>}
          </div>
          <div>
            <label htmlFor="aluno-login-email" className="mb-1 block text-sm text-slate-300">
              E-mail
            </label>
            <input
              id="aluno-login-email"
              name="aluno-login-email"
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
            <label htmlFor="aluno-login-password" className="mb-1 block text-sm text-slate-300">
              Senha
            </label>
            <PasswordInput
              id="aluno-login-password"
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
            Lembrar e-mail e senha neste aparelho
          </label>
          {error && (
            <div className="text-sm text-red-400">
              <p>{error}</p>
              {error.includes("Administrador da plataforma") && (
                <p className="mt-2 text-slate-400">
                  Acesse o painel admin em{" "}
                  <a href="/admin/login" className="text-blue-400 underline">
                    academia.focodev.com.br/admin
                  </a>
                  . Para aluno, use o e-mail cadastrado pelo instrutor.
                </p>
              )}
            </div>
          )}
          <button type="submit" disabled={loading} className="btn-primary w-full">
            {loading ? "Entrando..." : "Entrar"}
          </button>
          <p className="text-center text-xs text-slate-500">
            Demo: código <code className="text-slate-400">academia-demo</code> · aluno@academia.com / aluno123
          </p>
        </form>
      </div>
    </div>
  );
}
