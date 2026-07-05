"use client";

import { FormEvent, useState } from "react";
import { useRouter } from "next/navigation";
import AppShell from "@/components/AppShell";
import { api, getToken } from "@/lib/api";

export default function NovaAcademiaPage() {
  const router = useRouter();
  const [name, setName] = useState("");
  const [deviceLimit, setDeviceLimit] = useState(3);
  const [instructorName, setInstructorName] = useState("");
  const [instructorEmail, setInstructorEmail] = useState("");
  const [instructorPassword, setInstructorPassword] = useState("");
  const [message, setMessage] = useState("");
  const [saving, setSaving] = useState(false);

  async function handleSubmit(e: FormEvent) {
    e.preventDefault();
    if (!getToken()) { router.replace("/login"); return; }
    setSaving(true);
    setMessage("");
    try {
      const created = await api<{ id: string }>("/api/admin/academies", {
        method: "POST",
        body: JSON.stringify({
          name,
          deviceLimitPerUser: deviceLimit,
          instructorName,
          instructorEmail,
          instructorPassword,
        }),
      });
      router.push(`/academias/${created.id}`);
    } catch (err) {
      setMessage(err instanceof Error ? err.message : "Erro");
    } finally {
      setSaving(false);
    }
  }

  return (
    <AppShell>
      <h2 className="mb-4 text-xl font-semibold">Nova academia</h2>
      <form onSubmit={handleSubmit} className="space-y-3 rounded-xl border border-slate-800 bg-slate-900 p-4">
        <input value={name} onChange={(e) => setName(e.target.value)} placeholder="Nome da academia" className="w-full rounded-lg border border-slate-700 bg-slate-950 px-3 py-2" required />
        <label className="block text-sm text-slate-400">
          Limite de dispositivos por usuário
          <input type="number" min={1} max={20} value={deviceLimit} onChange={(e) => setDeviceLimit(Number(e.target.value))} className="mt-1 w-full rounded-lg border border-slate-700 bg-slate-950 px-3 py-2" />
        </label>
        <hr className="border-slate-800" />
        <p className="text-sm font-medium text-emerald-400">Primeiro instrutor</p>
        <input value={instructorName} onChange={(e) => setInstructorName(e.target.value)} placeholder="Nome" className="w-full rounded-lg border border-slate-700 bg-slate-950 px-3 py-2" required />
        <input value={instructorEmail} onChange={(e) => setInstructorEmail(e.target.value)} placeholder="E-mail" type="email" className="w-full rounded-lg border border-slate-700 bg-slate-950 px-3 py-2" required />
        <input value={instructorPassword} onChange={(e) => setInstructorPassword(e.target.value)} placeholder="Senha" type="password" className="w-full rounded-lg border border-slate-700 bg-slate-950 px-3 py-2" required />
        {message && <p className="text-sm text-red-400">{message}</p>}
        <button type="submit" disabled={saving} className="w-full rounded-lg bg-emerald-600 py-2 font-medium disabled:opacity-50">
          {saving ? "Criando..." : "Criar academia"}
        </button>
      </form>
    </AppShell>
  );
}
