"use client";

import { FormEvent, useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import AppShell from "@/components/AppShell";
import StudentWeightChart, { WeightPoint } from "@/components/StudentWeightChart";
import { User, api, getToken } from "@/lib/api";
import { FitnessGoal, StudentProfile, goalLabels } from "@/lib/profile";

export default function AlunosPage() {
  const router = useRouter();
  const [students, setStudents] = useState<User[]>([]);
  const [selected, setSelected] = useState<User | null>(null);
  const [profile, setProfile] = useState<StudentProfile | null>(null);
  const [measurements, setMeasurements] = useState<WeightPoint[]>([]);
  const [weightDate, setWeightDate] = useState("");
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

  async function selectStudent(student: User) {
    setSelected(student);
    setMessage("");
    setMeasurements([]);
    try {
      const [p, m] = await Promise.all([
        api<StudentProfile>(`/api/instructor/students/${student.id}/profile`),
        api<WeightPoint[]>(`/api/instructor/students/${student.id}/measurements`),
      ]);
      setProfile(p);
      setMeasurements(m);
    } catch {
      setProfile(null);
      setMeasurements([]);
    }
  }

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

  async function quickWorkout() {
    if (!selected) return;
    setSaving(true);
    try {
      await api("/api/instructor/programs/quick", {
        method: "POST",
        body: JSON.stringify({ studentId: selected.id }),
      });
      setMessage(`Treino rápido criado para ${selected.name}!`);
    } catch (err) {
      setMessage(err instanceof Error ? err.message : "Erro");
    } finally {
      setSaving(false);
    }
  }

  async function scheduleWeight() {
    if (!selected || !weightDate) return;
    setSaving(true);
    try {
      await api(`/api/instructor/students/${selected.id}/weight-schedule`, {
        method: "POST",
        body: JSON.stringify({ dueDate: weightDate }),
      });
      setMessage("Data de pesagem definida!");
      setWeightDate("");
    } catch (err) {
      setMessage(err instanceof Error ? err.message : "Erro");
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
          <input value={name} onChange={(e) => setName(e.target.value)} placeholder="Nome" className="rounded-lg border border-slate-700 bg-slate-950 px-3 py-2 text-sm" required />
          <input value={email} onChange={(e) => setEmail(e.target.value)} placeholder="E-mail" type="email" className="rounded-lg border border-slate-700 bg-slate-950 px-3 py-2 text-sm" required />
          <input value={password} onChange={(e) => setPassword(e.target.value)} placeholder="Senha" type="password" className="rounded-lg border border-slate-700 bg-slate-950 px-3 py-2 text-sm" required />
          <input value={phone} onChange={(e) => setPhone(e.target.value)} placeholder="Telefone (opcional)" className="rounded-lg border border-slate-700 bg-slate-950 px-3 py-2 text-sm" />
        </div>
        <button type="submit" disabled={saving} className="mt-3 rounded-lg bg-violet-600 px-4 py-2 text-sm font-medium disabled:opacity-50">
          {saving ? "Salvando..." : "Cadastrar"}
        </button>
      </form>

      {message && <p className="mb-4 text-sm text-green-400">{message}</p>}
      {loading && <p className="text-slate-400">Carregando...</p>}

      <div className="grid gap-4 lg:grid-cols-2">
        <div className="space-y-2">
          {students.map((s) => (
            <button
              key={s.id}
              type="button"
              onClick={() => selectStudent(s)}
              className={`w-full rounded-xl border p-4 text-left ${
                selected?.id === s.id ? "border-violet-500 bg-violet-950/30" : "border-slate-800 bg-slate-900"
              }`}
            >
              <p className="font-medium">{s.name}</p>
              <p className="text-sm text-slate-400">{s.email}</p>
            </button>
          ))}
        </div>

        {selected && (
          <div className="rounded-xl border border-slate-800 bg-slate-900 p-4">
            <h3 className="font-medium">{selected.name}</h3>
            {profile?.onboardingCompleted ? (
              <div className="mt-2 space-y-1 text-sm text-slate-400">
                <p>Altura: {profile.heightCm} cm</p>
                <p>Peso: {profile.currentWeightKg} kg</p>
                <p>Objetivo: {profile.goal ? goalLabels[profile.goal as FitnessGoal] : "—"}</p>
              </div>
            ) : (
              <p className="mt-2 text-sm text-amber-400">Aguardando onboarding do aluno</p>
            )}

            <StudentWeightChart measurements={measurements} />

            <button
              type="button"
              onClick={quickWorkout}
              disabled={saving || !profile?.goal}
              className="mt-4 w-full rounded-lg bg-violet-600 px-4 py-2 text-sm font-medium disabled:opacity-50"
            >
              Treino rápido (por objetivo)
            </button>

            <div className="mt-4">
              <label className="text-sm text-slate-400">Próxima data de pesagem</label>
              <div className="mt-1 flex gap-2">
                <input
                  type="date"
                  value={weightDate}
                  onChange={(e) => setWeightDate(e.target.value)}
                  className="form-input flex-1"
                />
                <button type="button" onClick={scheduleWeight} disabled={saving || !weightDate} className="btn-primary text-sm">
                  Definir
                </button>
              </div>
            </div>
          </div>
        )}
      </div>
    </AppShell>
  );
}
