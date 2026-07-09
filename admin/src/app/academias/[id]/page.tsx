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
  const [usersLoaded, setUsersLoaded] = useState(false);
  const [usersError, setUsersError] = useState("");
  const [deviceLimit, setDeviceLimit] = useState(3);
  const [tab, setTab] = useState<"users" | "add-instructor" | "add-student">("users");
  const [message, setMessage] = useState("");

  function load() {
    api<Academy>(`/api/admin/academies/${id}`).then((a) => {
      setAcademy(a);
      setDeviceLimit(a.deviceLimitPerUser);
    });
    setUsersLoaded(false);
    setUsersError("");
    api<AdminUser[]>(`/api/admin/academies/${id}/users`)
      .then((data) => {
        setUsers(data);
        setUsersLoaded(true);
      })
      .catch((err: Error) => {
        setUsers([]);
        setUsersLoaded(true);
        setUsersError(err.message || "Erro ao carregar usuários");
      });
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
      <p className="mt-1 text-sm text-emerald-400">Código de login: <code className="rounded bg-slate-800 px-2 py-0.5">{academy.slug}</code></p>
      <div className="mt-4 rounded-xl border border-slate-800 bg-slate-900 p-4">
        <p className="text-sm text-slate-400">Limite de dispositivos por usuário</p>
        <div className="mt-2 flex gap-2">
          <input type="number" min={1} max={20} value={deviceLimit} onChange={(e) => setDeviceLimit(Number(e.target.value))} className="form-input w-24" />
          <button onClick={saveLimit} className="btn-primary text-sm">Salvar</button>
        </div>
        {message && <p className="mt-2 text-sm text-green-400">{message}</p>}
      </div>

      <div className="mt-4 flex gap-2">
        {(["users", "add-instructor", "add-student"] as const).map((t) => (
          <button key={t} onClick={() => setTab(t)} className={`rounded-full px-3 py-1 text-sm ${tab === t ? "bg-emerald-600 text-white" : "bg-slate-800 text-slate-200"}`}>
            {t === "users" ? "Usuários" : t === "add-instructor" ? "+ Instrutor" : "+ Aluno"}
          </button>
        ))}
      </div>

      {tab === "users" && (
        <div className="mt-4 space-y-2">
          {usersError && <p className="text-sm text-red-400">{usersError}</p>}
          {!usersLoaded && <p className="text-sm text-slate-400">Carregando usuários...</p>}
          {usersLoaded && !usersError && users.length === 0 && (
            <p className="text-sm text-slate-400">Nenhum usuário cadastrado nesta academia.</p>
          )}
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
          <input name="name" placeholder="Nome" className="form-input" required />
          <input name="email" type="email" placeholder="E-mail" className="form-input" required />
          <input name="password" type="password" placeholder="Senha" className="form-input" required />
          <button type="submit" className="btn-primary text-sm">Cadastrar instrutor</button>
        </form>
      )}

      {tab === "add-student" && (
        <form onSubmit={addStudent} className="mt-4 space-y-2 rounded-xl border border-slate-800 bg-slate-900 p-4">
          <select name="instructorId" className="form-input" required>
            {instructors.map((i) => (
              <option key={i.id} value={i.id}>{i.name}</option>
            ))}
          </select>
          <input name="name" placeholder="Nome" className="form-input" required />
          <input name="email" type="email" placeholder="E-mail" className="form-input" required />
          <input name="password" type="password" placeholder="Senha" className="form-input" required />
          <button type="submit" className="btn-primary text-sm">Cadastrar aluno</button>
        </form>
      )}
    </AppShell>
  );
}
