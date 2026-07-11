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
  const [appBlocked, setAppBlocked] = useState(false);
  const [academyActive, setAcademyActive] = useState(true);
  const [tab, setTab] = useState<"users" | "add-instructor" | "add-student">("users");
  const [message, setMessage] = useState("");
  const [selectedInstructorId, setSelectedInstructorId] = useState("");

  function load() {
    api<Academy>(`/api/admin/academies/${id}`).then((a) => {
      setAcademy(a);
      setDeviceLimit(a.deviceLimitPerUser);
      setAppBlocked(a.appBlocked);
      setAcademyActive(a.active);
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

  const instructors = users.filter((u) => u.role === "INSTRUTOR");

  useEffect(() => {
    setSelectedInstructorId((current) => {
      if (instructors.length === 1) return instructors[0].id;
      if (current && instructors.some((i) => i.id === current)) return current;
      return "";
    });
  }, [instructors]);

  async function saveAcademySettings() {
    await api(`/api/admin/academies/${id}`, {
      method: "PATCH",
      body: JSON.stringify({
        deviceLimitPerUser: deviceLimit,
        appBlocked,
        active: academyActive,
      }),
    });
    setMessage("Configurações atualizadas!");
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

  return (
    <AppShell>
      <h2 className="text-xl font-semibold">{academy.name}</h2>
      <p className="mt-1 text-sm text-emerald-400">Código de login: <code className="rounded bg-slate-800 px-2 py-0.5">{academy.slug}</code></p>
      <div className="mt-4 rounded-xl border border-slate-800 bg-slate-900 p-4 space-y-3">
        <p className="text-sm text-slate-400">Configurações da academia</p>
        <div className="flex gap-2 items-center">
          <label className="text-sm text-slate-300">Limite de dispositivos</label>
          <input type="number" min={1} max={20} value={deviceLimit} onChange={(e) => setDeviceLimit(Number(e.target.value))} className="form-input w-24" />
        </div>
        <label className="flex items-center gap-2 text-sm">
          <input type="checkbox" checked={academyActive} onChange={(e) => setAcademyActive(e.target.checked)} />
          Academia ativa
        </label>
        <label className="flex items-center gap-2 text-sm text-red-300">
          <input type="checkbox" checked={appBlocked} onChange={(e) => setAppBlocked(e.target.checked)} />
          Bloquear apps (aluno/instrutor)
        </label>
        <button onClick={saveAcademySettings} className="btn-primary text-sm">Salvar</button>
        {message && <p className="text-sm text-green-400">{message}</p>}
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
        <form onSubmit={addStudent} className="mt-4 space-y-3 rounded-xl border border-slate-800 bg-slate-900 p-4">
          <div>
            <label htmlFor="instructorId" className="mb-1 block text-sm text-slate-400">
              Instrutor responsável
            </label>
            {!usersLoaded && <p className="text-sm text-slate-500">Carregando instrutores...</p>}
            {usersLoaded && instructors.length === 0 && (
              <p className="text-sm text-amber-400">
                Nenhum instrutor cadastrado. Use &quot;+ Instrutor&quot; antes de cadastrar alunos.
              </p>
            )}
            <select
              id="instructorId"
              name="instructorId"
              className="form-input"
              required
              value={selectedInstructorId}
              onChange={(e) => setSelectedInstructorId(e.target.value)}
              disabled={!usersLoaded || instructors.length === 0}
            >
              <option value="" disabled>
                {instructors.length === 0 ? "Nenhum instrutor disponível" : "Selecione o instrutor"}
              </option>
              {instructors.map((i) => (
                <option key={i.id} value={i.id}>{i.name} ({i.email})</option>
              ))}
            </select>
          </div>
          <input name="name" placeholder="Nome do aluno" className="form-input" required disabled={instructors.length === 0} />
          <input name="email" type="email" placeholder="E-mail do aluno" className="form-input" required disabled={instructors.length === 0} />
          <input name="password" type="password" placeholder="Senha" className="form-input" required disabled={instructors.length === 0} />
          <button type="submit" className="btn-primary text-sm" disabled={instructors.length === 0}>
            Cadastrar aluno
          </button>
        </form>
      )}
    </AppShell>
  );
}
