"use client";

import { FormEvent, useEffect, useState } from "react";
import { useParams, useRouter } from "next/navigation";
import AppShell from "@/components/AppShell";
import { Academy, AdminUser, api, formatDate, getToken } from "@/lib/api";

export default function AcademiaDetailPage() {
  const { id } = useParams<{ id: string }>();
  const router = useRouter();
  const [academy, setAcademy] = useState<Academy | null>(null);
  const [users, setUsers] = useState<AdminUser[]>([]);
  const [deviceLimit, setDeviceLimit] = useState(3);
  const [tab, setTab] = useState<"users" | "add-instructor" | "add-student">("users");
  const [message, setMessage] = useState("");

  function load() {
    api<Academy>(`/api/admin/academies/${id}`).then((a) => {
      setAcademy(a);
      setDeviceLimit(a.deviceLimitPerUser);
    });
    api<AdminUser[]>(`/api/admin/academies/${id}/users`).then(setUsers);
  }

  useEffect(() => {
    if (!getToken()) { router.replace("/login"); return; }
    load();
  }, [id, router]);

  async function saveLimit() {
    await api(`/api/admin/academies/${id}`, {
      method: "PATCH",
      body: JSON.stringify({ deviceLimitPerUser: deviceLimit }),
    });
    setMessage("Limite atualizado!");
    load();
  }

  async function addInstructor(e: FormEvent<HTMLFormElement>) {
    e.preventDefault();
    const fd = new FormData(e.currentTarget);
    await api(`/api/admin/academies/${id}/instructors`, {
      method: "POST",
      body: JSON.stringify({
        name: fd.get("name"),
        email: fd.get("email"),
        password: fd.get("password"),
      }),
    });
    setTab("users");
    load();
  }

  async function addStudent(e: FormEvent<HTMLFormElement>) {
    e.preventDefault();
    const fd = new FormData(e.currentTarget);
    const instructors = users.filter((u) => u.role === "INSTRUTOR");
    await api(`/api/admin/academies/${id}/students`, {
      method: "POST",
      body: JSON.stringify({
        name: fd.get("name"),
        email: fd.get("email"),
        password: fd.get("password"),
        instructorId: fd.get("instructorId"),
      }),
    });
    setTab("users");
    load();
  }

  if (!academy) return <AppShell><p className="text-slate-400">Carregando...</p></AppShell>;

  const instructors = users.filter((u) => u.role === "INSTRUTOR");

  return (
    <AppShell>
      <h2 className="text-xl font-semibold">{academy.name}</h2>
      <div className="mt-4 rounded-xl border border-slate-800 bg-slate-900 p-4">
        <p className="text-sm text-slate-400">Limite de dispositivos por usuário</p>
        <div className="mt-2 flex gap-2">
          <input type="number" min={1} max={20} value={deviceLimit} onChange={(e) => setDeviceLimit(Number(e.target.value))} className="w-24 rounded-lg border border-slate-700 bg-slate-950 px-3 py-2" />
          <button onClick={saveLimit} className="rounded-lg bg-emerald-600 px-4 py-2 text-sm">Salvar</button>
        </div>
        {message && <p className="mt-2 text-sm text-green-400">{message}</p>}
      </div>

      <div className="mt-4 flex gap-2">
        {(["users", "add-instructor", "add-student"] as const).map((t) => (
          <button key={t} onClick={() => setTab(t)} className={`rounded-full px-3 py-1 text-sm ${tab === t ? "bg-emerald-600" : "bg-slate-800"}`}>
            {t === "users" ? "Usuários" : t === "add-instructor" ? "+ Instrutor" : "+ Aluno"}
          </button>
        ))}
      </div>

      {tab === "users" && (
        <div className="mt-4 space-y-2">
          {users.map((u) => (
            <div key={u.id} className="rounded-xl border border-slate-800 bg-slate-900 p-3">
              <div className="flex justify-between">
                <div>
                  <p className="font-medium">{u.name} <span className="text-xs text-slate-500">({u.role})</span></p>
                  <p className="text-sm text-slate-400">{u.email}</p>
                </div>
                <div className="text-right text-xs text-slate-500">
                  <p>{u.deviceCount} dispositivo(s)</p>
                  <p>Último login: {formatDate(u.lastLoginAt)}</p>
                </div>
              </div>
            </div>
          ))}
        </div>
      )}

      {tab === "add-instructor" && (
        <form onSubmit={addInstructor} className="mt-4 space-y-2 rounded-xl border border-slate-800 bg-slate-900 p-4">
          <input name="name" placeholder="Nome" className="w-full rounded-lg border border-slate-700 bg-slate-950 px-3 py-2" required />
          <input name="email" type="email" placeholder="E-mail" className="w-full rounded-lg border border-slate-700 bg-slate-950 px-3 py-2" required />
          <input name="password" type="password" placeholder="Senha" className="w-full rounded-lg border border-slate-700 bg-slate-950 px-3 py-2" required />
          <button type="submit" className="rounded-lg bg-emerald-600 px-4 py-2 text-sm">Cadastrar instrutor</button>
        </form>
      )}

      {tab === "add-student" && (
        <form onSubmit={addStudent} className="mt-4 space-y-2 rounded-xl border border-slate-800 bg-slate-900 p-4">
          <select name="instructorId" className="w-full rounded-lg border border-slate-700 bg-slate-950 px-3 py-2" required>
            {instructors.map((i) => (
              <option key={i.id} value={i.id}>{i.name}</option>
            ))}
          </select>
          <input name="name" placeholder="Nome" className="w-full rounded-lg border border-slate-700 bg-slate-950 px-3 py-2" required />
          <input name="email" type="email" placeholder="E-mail" className="w-full rounded-lg border border-slate-700 bg-slate-950 px-3 py-2" required />
          <input name="password" type="password" placeholder="Senha" className="w-full rounded-lg border border-slate-700 bg-slate-950 px-3 py-2" required />
          <button type="submit" className="rounded-lg bg-emerald-600 px-4 py-2 text-sm">Cadastrar aluno</button>
        </form>
      )}
    </AppShell>
  );
}
