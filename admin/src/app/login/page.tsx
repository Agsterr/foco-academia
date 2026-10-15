"use client";

import { FormEvent, useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import PasswordInput from "@/components/PasswordInput";
import { api, getDeviceId, setToken } from "@/lib/api";
import { clearSavedLogin, getSavedLogin, saveLogin } from "@/lib/auth-storage";

export default function LoginPage() {
  const router = useRouter();
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [remember, setRemember] = useState(false);
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    const savedLogin = getSavedLogin();
    if (savedLogin.remember) {
      setEmail(savedLogin.email);
      setPassword(savedLogin.password);
      setRemember(true);
    }
  }, []);

  async function handleSubmit(e: FormEvent) {
    e.preventDefault();
    setLoading(true);
    setError("");
    try {
      const data = await api<{ token: string }>("/api/auth/login", {
        method: "POST",
        body: JSON.stringify({
          email,
          password,
          deviceId: getDeviceId(),
          deviceLabel: navigator.userAgent.slice(0, 80),
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
        <div className="pointer-events-none absolute -right-16 -top-16 h-48 w-48 rounded-full bg-emerald-500/25 blur-3xl" />
        <span className="relative mb-5 flex h-12 w-12 items-center justify-center rounded-2xl bg-gradient-to-br from-emerald-400 to-emerald-700 text-2xl shadow-lg shadow-emerald-900/50">🏋️</span>
        <h1 className="text-2xl font-bold text-emerald-400">Admin da Plataforma</h1>
        <p className="mt-1 text-sm text-slate-400">Gerencie academias, usuários e limites de dispositivos</p>
        <p className="mt-3 rounded-lg border border-slate-800 bg-slate-950/60 px-3 py-2 text-xs text-slate-400">
          Instrutor ou aluno? Use{" "}
          <a href="https://instrutor-academia.focodev.com.br/login" className="text-emerald-400 underline">
            instrutor-academia.focodev.com.br
          </a>{" "}
          ou{" "}
          <a href="https://academia.focodev.com.br/login" className="text-emerald-400 underline">
            academia.focodev.com.br
          </a>
          .
        </p>
        <form onSubmit={handleSubmit} className="mt-6 space-y-4" autoComplete="off">
          <div>
            <label htmlFor="admin-login-email" className="mb-1 block text-sm text-slate-300">
              E-mail
            </label>
            <input
              id="admin-login-email"
              name="admin-login-email"
              type="email"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              placeholder="admin@focodev.com.br"
              className="form-input"
              required
              autoComplete="off"
              data-lpignore="true"
              data-1p-ignore="true"
            />
          </div>
          <div>
            <label htmlFor="admin-login-password" className="mb-1 block text-sm text-slate-300">
              Senha
            </label>
            <PasswordInput
              id="admin-login-password"
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
          {error && <p className="text-sm text-red-400">{error}</p>}
          <button type="submit" disabled={loading} className="btn-primary w-full">
            {loading ? "Entrando..." : "Entrar"}
          </button>
        </form>
      </div>
    </div>
  );
}
