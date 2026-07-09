"use client";

import { FormEvent, useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { api, getAcademySlug, getDeviceId, setAcademySlug, setToken, type AuthResponse } from "@/lib/api";
import { lookupAcademyName } from "@/lib/tenant";

export default function LoginPage() {
  const router = useRouter();
  const [academySlug, setSlug] = useState("academia-demo");
  const [academyName, setAcademyName] = useState("");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    const saved = getAcademySlug();
    if (saved) setSlug(saved);
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
      const data = await api<AuthResponse>("/api/auth/login", {
        method: "POST",
        body: JSON.stringify({
          email,
          password,
          academySlug: academySlug.trim(),
          deviceId: getDeviceId(),
          deviceLabel: typeof navigator !== "undefined" ? navigator.userAgent.slice(0, 80) : undefined,
        }),
      });
      if (data.user.role !== "ALUNO") {
        throw new Error(
          data.user.role === "INSTRUTOR"
            ? "Esta conta é de instrutor. Acesse academia.focodev.com.br/instrutor"
            : "Administrador da plataforma não usa código de academia",
        );
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

        <form onSubmit={handleSubmit} className="mt-6 space-y-4">
          <div>
            <label className="mb-1 block text-sm text-slate-300">Código da academia</label>
            <input
              value={academySlug}
              onChange={(e) => setSlug(e.target.value.toLowerCase())}
              placeholder="ex: academia-demo"
              className="form-input"
              required
            />
            {academyName && <p className="mt-1 text-xs text-blue-300">{academyName}</p>}
          </div>
          <div>
            <label className="mb-1 block text-sm text-slate-300">E-mail</label>
            <input
              type="email"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              className="form-input"
              required
            />
          </div>
          <div>
            <label className="mb-1 block text-sm text-slate-300">Senha</label>
            <input
              type="password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              className="form-input"
              required
            />
          </div>
          {error && (
            <div className="text-sm text-red-400">
              <p>{error}</p>
              {error.includes("instrutor") && (
                <p className="mt-2 text-slate-400">
                  Acesse{" "}
                  <a href="/instrutor/login" className="text-blue-400 underline">
                    academia.focodev.com.br/instrutor
                  </a>
                </p>
              )}
              {error.includes("Administrador da plataforma") && (
                <p className="mt-2 text-slate-400">
                  Acesse o painel admin em{" "}
                  <a href="/admin/login" className="text-blue-400 underline">
                    academia.focodev.com.br/admin
                  </a>
                </p>
              )}
            </div>
          )}
          <button
            type="submit"
            disabled={loading}
            className="btn-primary w-full"
          >
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
