"use client";

import { FormEvent, useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { API_URL, api, getAcademySlug, getDeviceId, setAcademySlug, setToken } from "@/lib/api";

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
    if (!academySlug.trim()) return;
    fetch(`${API_URL}/api/tenants/${encodeURIComponent(academySlug.trim())}`)
      .then((r) => (r.ok ? r.json() : null))
      .then((t) => setAcademyName(t?.name ?? ""))
      .catch(() => setAcademyName(""));
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
          {error && <p className="text-sm text-red-400">{error}</p>}
          <button
            type="submit"
            disabled={loading}
            className="btn-primary w-full"
          >
            {loading ? "Entrando..." : "Entrar"}
          </button>
        </form>


      </div>
    </div>
  );
}
