"use client";

import { FormEvent, useState } from "react";
import { useRouter } from "next/navigation";
import { api, getDeviceId, setToken } from "@/lib/api";

export default function LoginPage() {
  const router = useRouter();
  const [email, setEmail] = useState("admin@focodev.com.br");
  const [password, setPassword] = useState("admin123");
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);

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
        <form onSubmit={handleSubmit} className="mt-6 space-y-4">
          <input type="email" value={email} onChange={(e) => setEmail(e.target.value)} placeholder="E-mail" className="w-full rounded-lg border border-slate-700 bg-slate-950 px-3 py-2" required />
          <input type="password" value={password} onChange={(e) => setPassword(e.target.value)} placeholder="Senha" className="w-full rounded-lg border border-slate-700 bg-slate-950 px-3 py-2" required />
          {error && <p className="text-sm text-red-400">{error}</p>}
          <button type="submit" disabled={loading} className="w-full rounded-lg bg-emerald-600 py-2.5 font-medium disabled:opacity-50">
            {loading ? "Entrando..." : "Entrar"}
          </button>
        </form>
        <p className="mt-4 text-center text-xs text-slate-500">Demo: admin@focodev.com.br / admin123</p>
      </div>
    </div>
  );
}
