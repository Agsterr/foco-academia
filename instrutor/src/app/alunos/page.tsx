"use client";

import { FormEvent, useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import AppShell from "@/components/AppShell";
import { User, api, getToken } from "@/lib/api";

export default function AlunosPage() {
  const router = useRouter();
  const [students, setStudents] = useState<User[]>([]);
  const [name, setName] = useState("");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [phone, setPhone] = useState("");
  const [message, setMessage] = useState("");
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);

  function load() {
    api<User[]>("/api/instructor/students")
      .then(setStudents)
      .catch(() => router.replace("/login"))
      .finally(() => setLoading(false));
  }

  useEffect(() => {
    if (!getToken()) {
      router.replace("/login");
      return;
    }
    load();
  }, [router]);

  async function handleSubmit(e: FormEvent) {
    e.preventDefault();
    setSaving(true);
    setMessage("");
    try {
      await api("/api/instructor/students", {
        method: "POST",
        body: JSON.stringify({ name, email, password, phone: phone || undefined }),
      });
      setName("");
      setEmail("");
      setPassword("");
      setPhone("");
      setMessage("Aluno cadastrado!");
      load();
    } catch (err) {
      setMessage(err instanceof Error ? err.message : "Erro ao cadastrar");
    } finally {
      setSaving(false);
    }
  }

  return (
    <AppShell>
      <h2 className="mb-4 text-xl font-semibold">Alunos</h2>

      <form onSubmit={handleSubmit} className="mb-6 rounded-xl border border-slate-800 bg-slate-900 p-4">
        <h3 className="mb-3 font-medium">Cadastrar aluno</h3>
        <div className="grid gap-2 sm:grid-cols-2">
          <input
            value={name}
            onChange={(e) => setName(e.target.value)}
            placeholder="Nome"
            className="rounded-lg border border-slate-700 bg-slate-950 px-3 py-2 text-sm"
            required
          />
          <input
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            placeholder="E-mail"
            type="email"
            className="rounded-lg border border-slate-700 bg-slate-950 px-3 py-2 text-sm"
            required
          />
          <input
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            placeholder="Senha"
            type="password"
            className="rounded-lg border border-slate-700 bg-slate-950 px-3 py-2 text-sm"
            required
          />
          <input
            value={phone}
            onChange={(e) => setPhone(e.target.value)}
            placeholder="Telefone (opcional)"
            className="rounded-lg border border-slate-700 bg-slate-950 px-3 py-2 text-sm"
          />
        </div>
        {message && <p className="mt-2 text-sm text-green-400">{message}</p>}
        <button
          type="submit"
          disabled={saving}
          className="mt-3 rounded-lg bg-violet-600 px-4 py-2 text-sm font-medium disabled:opacity-50"
        >
          {saving ? "Salvando..." : "Cadastrar"}
        </button>
      </form>

      {loading && <p className="text-slate-400">Carregando...</p>}
      <div className="space-y-2">
        {students.map((s) => (
          <div key={s.id} className="rounded-xl border border-slate-800 bg-slate-900 p-4">
            <p className="font-medium">{s.name}</p>
            <p className="text-sm text-slate-400">{s.email}</p>
            {s.phone && <p className="text-sm text-slate-500">{s.phone}</p>}
          </div>
        ))}
      </div>
    </AppShell>
  );
}
