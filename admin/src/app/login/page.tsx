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
  const [remember, setRemember] = useState(true);
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
        saveLogin(email, password);
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
    <div className="mx-auto flex min-h-full max-w-lg flex-col justify-center px-4 py-8">
      <div className="rounded-2xl border border-slate-800 bg-slate-900 p-6">
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
            Lembrar e-mail e senha neste aparelho
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
