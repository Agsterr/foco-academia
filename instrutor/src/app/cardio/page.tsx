"use client";

import { FormEvent, useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import AppShell from "@/components/AppShell";
import { User, api, getToken } from "@/lib/api";

interface CardioSession {
  id: string;
  studentName: string;
  workoutTitle?: string;
  distanceMeters?: number;
  avgSpeedKmh?: number;
  elapsedMs?: number;
  startedAt: string;
}

interface CardioStats {
  sessionsThisWeek: number;
  totalKmThisWeek: number;
  avgSpeedKmh: number;
  recentSessions: CardioSession[];
  overdueWeightChecks: { studentName: string; dueDate: string }[];
}

interface CardioWorkout {
  id: string;
  studentName: string;
  title: string;
  type: string;
}

export default function CardioPage() {
  const router = useRouter();
  const [students, setStudents] = useState<User[]>([]);
  const [stats, setStats] = useState<CardioStats | null>(null);
  const [workouts, setWorkouts] = useState<CardioWorkout[]>([]);
  const [studentId, setStudentId] = useState("");
  const [title, setTitle] = useState("Caminhada intervalada");
  const [walkMin, setWalkMin] = useState(2);
  const [runMin, setRunMin] = useState(1);
  const [rounds, setRounds] = useState(5);
  const [message, setMessage] = useState("");

  useEffect(() => {
    if (!getToken()) {
      router.replace("/login");
      return;
    }
    void Promise.all([
      api<User[]>("/api/instructor/students"),
      api<CardioStats>("/api/instructor/cardio-stats"),
      api<CardioWorkout[]>("/api/instructor/cardio-workouts"),
    ]).then(([s, st, w]) => {
      setStudents(s);
      setStats(st);
      setWorkouts(w);
      if (s.length > 0) setStudentId(s[0].id);
    });
  }, [router]);

  async function createWorkout(e: FormEvent) {
    e.preventDefault();
    const intervals = [];
    for (let i = 0; i < rounds; i++) {
      intervals.push({ phase: "WALK", durationSec: walkMin * 60 });
      intervals.push({ phase: "RUN", durationSec: runMin * 60 });
    }
    await api("/api/instructor/cardio-workouts", {
      method: "POST",
      body: JSON.stringify({
        studentId,
        title,
        type: "INTERVAL",
        intervals,
      }),
    });
    setMessage("Treino outdoor criado!");
    const w = await api<CardioWorkout[]>("/api/instructor/cardio-workouts");
    setWorkouts(w);
  }

  return (
    <AppShell>
      <h2 className="text-xl font-semibold">Cardio outdoor</h2>

      {stats && (
        <div className="mt-4 grid grid-cols-3 gap-2">
          <div className="rounded-xl border border-slate-800 bg-slate-900 p-3 text-center">
            <p className="text-xs text-slate-500">Sessões/semana</p>
            <p className="text-lg font-semibold">{stats.sessionsThisWeek}</p>
          </div>
          <div className="rounded-xl border border-slate-800 bg-slate-900 p-3 text-center">
            <p className="text-xs text-slate-500">Km/semana</p>
            <p className="text-lg font-semibold">{stats.totalKmThisWeek.toFixed(1)}</p>
          </div>
          <div className="rounded-xl border border-slate-800 bg-slate-900 p-3 text-center">
            <p className="text-xs text-slate-500">Vel. média</p>
            <p className="text-lg font-semibold">{stats.avgSpeedKmh.toFixed(1)} km/h</p>
          </div>
        </div>
      )}

      <form onSubmit={createWorkout} className="mt-6 rounded-xl border border-slate-800 bg-slate-900 p-4">
        <h3 className="font-medium">Prescrever treino intervalado</h3>
        <div className="mt-3 space-y-2">
          <select value={studentId} onChange={(e) => setStudentId(e.target.value)} className="form-input" required>
            {students.map((s) => (
              <option key={s.id} value={s.id}>{s.name}</option>
            ))}
          </select>
          <input value={title} onChange={(e) => setTitle(e.target.value)} className="form-input" required />
          <div className="grid grid-cols-3 gap-2">
            <input type="number" min={1} value={walkMin} onChange={(e) => setWalkMin(Number(e.target.value))} className="form-input" placeholder="Caminhada min" />
            <input type="number" min={1} value={runMin} onChange={(e) => setRunMin(Number(e.target.value))} className="form-input" placeholder="Corrida min" />
            <input type="number" min={1} value={rounds} onChange={(e) => setRounds(Number(e.target.value))} className="form-input" placeholder="Rodadas" />
          </div>
        </div>
        <button type="submit" className="btn-primary mt-3 text-sm">Publicar treino outdoor</button>
      </form>

      {message && <p className="mt-3 text-sm text-green-400">{message}</p>}

      <h3 className="mt-6 font-medium">Execuções recentes</h3>
      <div className="mt-2 space-y-2">
        {stats?.recentSessions.map((s) => (
          <div key={s.id} className="rounded-xl border border-slate-800 bg-slate-900 p-3 text-sm">
            <p className="font-medium">{s.studentName}</p>
            <p className="text-slate-400">
              {((s.distanceMeters ?? 0) / 1000).toFixed(2)} km · {(s.avgSpeedKmh ?? 0).toFixed(1)} km/h
            </p>
          </div>
        ))}
        {stats?.recentSessions.length === 0 && (
          <p className="text-sm text-slate-500">Nenhuma sessão registrada ainda.</p>
        )}
      </div>

      <h3 className="mt-6 font-medium">Treinos prescritos</h3>
      <div className="mt-2 space-y-2">
        {workouts.map((w) => (
          <div key={w.id} className="rounded-xl border border-slate-800 bg-slate-900 p-3 text-sm">
            <p className="font-medium">{w.title}</p>
            <p className="text-slate-400">{w.studentName} · {w.type}</p>
          </div>
        ))}
      </div>
    </AppShell>
  );
}
