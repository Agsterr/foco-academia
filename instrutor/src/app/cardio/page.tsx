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
  pausedMs?: number;
  pauseCount?: number;
  caloriesKcal?: number;
  gpsQualityScore?: number;
  gpsQualityLabel?: string;
  startedAt: string;
}

interface GpsAnalytics {
  completedSessions: number;
  avgGpsQualityScore: number | null;
  qualityLabelCounts: Record<string, number>;
  filterReasonCounts: Record<string, number>;
  diagnosticEventCounts: Record<string, number>;
  algorithmVersionCounts: Record<string, number>;
}

interface SessionAiInsights {
  sessionId: string;
  overallRiskScore: number;
  summary: string;
  findings: { code: string; severity: string; title: string; detail?: string }[];
  segmentSuggestions: { action: string; reason: string }[];
  suspiciousActivity: boolean;
}

interface SessionDiagnostic {
  id: string;
  eventType: string;
  recordedAt: string;
  message?: string | null;
  latitude?: number | null;
  longitude?: number | null;
  accuracy?: number | null;
}

interface CardioStats {
  sessionsThisWeek: number;
  totalKmThisWeek: number;
  avgSpeedKmh: number;
  recentSessions: CardioSession[];
  overdueWeightChecks: { studentName: string; dueDate: string }[];
}

interface CardioInterval {
  phase: string;
  durationSec: number;
}

interface CardioWorkout {
  id: string;
  studentId: string;
  studentName: string;
  title: string;
  type: string;
  intervalsJson?: string | null;
  active: boolean;
  createdAt: string;
}

function parseIntervals(json?: string | null): CardioInterval[] {
  if (!json) return [];
  try {
    return JSON.parse(json) as CardioInterval[];
  } catch {
    return [];
  }
}

function summarizeIntervals(json?: string | null): string {
  const intervals = parseIntervals(json);
  if (intervals.length === 0) return "Sem intervalos";
  const walk = intervals.filter((i) => i.phase === "WALK").length;
  const run = intervals.filter((i) => i.phase === "RUN").length;
  const walkSec = intervals.find((i) => i.phase === "WALK")?.durationSec ?? 0;
  const runSec = intervals.find((i) => i.phase === "RUN")?.durationSec ?? 0;
  const rounds = Math.max(walk, run);
  const totalMin = Math.round(
    ((walk * walkSec) + (run * runSec)) / 60
  );
  return `${rounds} rodadas (caminhada ${Math.round(walkSec / 60)} min + corrida ${Math.round(runSec / 60)} min) · ~${totalMin} min no total`;
}

function formatDuration(ms?: number | null): string {
  if (ms == null || ms < 0) return "0:00";
  const totalSec = Math.floor(ms / 1000);
  const m = Math.floor(totalSec / 60);
  const s = (totalSec % 60).toString().padStart(2, "0");
  return `${m}:${s}`;
}

export default function CardioPage() {
  const router = useRouter();
  const [students, setStudents] = useState<User[]>([]);
  const [stats, setStats] = useState<CardioStats | null>(null);
  const [gpsAnalytics, setGpsAnalytics] = useState<GpsAnalytics | null>(null);
  const [workouts, setWorkouts] = useState<CardioWorkout[]>([]);
  const [studentId, setStudentId] = useState("");
  const [title, setTitle] = useState("Caminhada intervalada");
  const [walkMin, setWalkMin] = useState(2);
  const [runMin, setRunMin] = useState(1);
  const [rounds, setRounds] = useState(5);
  const [message, setMessage] = useState("");
  const [error, setError] = useState("");
  const [editingId, setEditingId] = useState<string | null>(null);
  const [saving, setSaving] = useState(false);
  const [aiBySession, setAiBySession] = useState<Record<string, SessionAiInsights | "loading" | "error">>({});
  const [diagBySession, setDiagBySession] = useState<
    Record<string, SessionDiagnostic[] | "loading" | "error" | "empty">
  >({});

  async function loadAiInsights(sessionId: string) {
    setAiBySession((prev) => ({ ...prev, [sessionId]: "loading" }));
    try {
      const r = await api<SessionAiInsights>(
        `/api/instructor/cardio-sessions/${sessionId}/ai-insights`
      );
      setAiBySession((prev) => ({ ...prev, [sessionId]: r }));
    } catch {
      setAiBySession((prev) => ({ ...prev, [sessionId]: "error" }));
    }
  }

  async function loadDiagnostics(sessionId: string) {
    setDiagBySession((prev) => ({ ...prev, [sessionId]: "loading" }));
    try {
      const r = await api<SessionDiagnostic[]>(
        `/api/instructor/cardio-sessions/${sessionId}/diagnostics`
      );
      setDiagBySession((prev) => ({
        ...prev,
        [sessionId]: r.length === 0 ? "empty" : r,
      }));
    } catch {
      setDiagBySession((prev) => ({ ...prev, [sessionId]: "error" }));
    }
  }

  async function refreshWorkouts() {
    const w = await api<CardioWorkout[]>("/api/instructor/cardio-workouts");
    setWorkouts(w);
  }

  useEffect(() => {
    if (!getToken()) {
      router.replace("/login");
      return;
    }
    void Promise.all([
      api<User[]>("/api/instructor/students"),
      api<CardioStats>("/api/instructor/cardio-stats"),
      api<CardioWorkout[]>("/api/instructor/cardio-workouts"),
      api<GpsAnalytics>("/api/instructor/gps-analytics").catch(() => null),
    ]).then(([s, st, w, ga]) => {
      setStudents(s);
      setStats(st);
      setWorkouts(w);
      setGpsAnalytics(ga);
      if (s.length > 0) setStudentId(s[0].id);
    });
  }, [router]);

  function buildIntervals() {
    const intervals: CardioInterval[] = [];
    for (let i = 0; i < rounds; i++) {
      intervals.push({ phase: "WALK", durationSec: walkMin * 60 });
      intervals.push({ phase: "RUN", durationSec: runMin * 60 });
    }
    return intervals;
  }

  function resetForm() {
    setEditingId(null);
    setTitle("Caminhada intervalada");
    setWalkMin(2);
    setRunMin(1);
    setRounds(5);
    if (students.length > 0) setStudentId(students[0].id);
  }

  function startEdit(w: CardioWorkout) {
    const intervals = parseIntervals(w.intervalsJson);
    const walk = intervals.find((i) => i.phase === "WALK");
    const run = intervals.find((i) => i.phase === "RUN");
    const walkCount = intervals.filter((i) => i.phase === "WALK").length;
    const runCount = intervals.filter((i) => i.phase === "RUN").length;

    setEditingId(w.id);
    setStudentId(w.studentId);
    setTitle(w.title);
    setWalkMin(Math.max(1, Math.round((walk?.durationSec ?? 120) / 60)));
    setRunMin(Math.max(1, Math.round((run?.durationSec ?? 60) / 60)));
    setRounds(Math.max(1, Math.max(walkCount, runCount) || 1));
    setMessage("");
    setError("");
    window.scrollTo({ top: 0, behavior: "smooth" });
  }

  async function saveWorkout(e: FormEvent) {
    e.preventDefault();
    setSaving(true);
    setMessage("");
    setError("");
    try {
      const intervals = buildIntervals();
      if (editingId) {
        await api(`/api/instructor/cardio-workouts/${editingId}`, {
          method: "PUT",
          body: JSON.stringify({
            title,
            type: "INTERVAL",
            intervals,
            active: true,
          }),
        });
        setMessage("Treino atualizado!");
      } else {
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
      }
      resetForm();
      await refreshWorkouts();
    } catch (err) {
      setError(err instanceof Error ? err.message : "Falha ao salvar treino");
    } finally {
      setSaving(false);
    }
  }

  async function toggleActive(w: CardioWorkout) {
    setError("");
    try {
      const intervals = parseIntervals(w.intervalsJson);
      const body: Record<string, unknown> = {
        title: w.title,
        type: w.type,
        active: !w.active,
      };
      if (intervals.length > 0) {
        body.intervals = intervals;
      }
      await api(`/api/instructor/cardio-workouts/${w.id}`, {
        method: "PUT",
        body: JSON.stringify(body),
      });
      setMessage(w.active ? "Treino desativado." : "Treino reativado para o aluno.");
      await refreshWorkouts();
    } catch (err) {
      setError(err instanceof Error ? err.message : "Falha ao atualizar status");
    }
  }

  async function deleteWorkout(w: CardioWorkout) {
    if (!confirm(`Apagar o treino "${w.title}" de ${w.studentName}?`)) return;
    setError("");
    try {
      await api(`/api/instructor/cardio-workouts/${w.id}`, { method: "DELETE" });
      if (editingId === w.id) resetForm();
      setMessage("Treino apagado.");
      await refreshWorkouts();
    } catch (err) {
      setError(err instanceof Error ? err.message : "Falha ao apagar treino");
    }
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

      {gpsAnalytics && (
        <div className="mt-4 rounded-xl border border-teal-900/40 bg-teal-950/20 p-4">
          <h3 className="font-medium text-teal-200">Analytics GPS</h3>
          <p className="mt-1 text-sm text-slate-400">
            {gpsAnalytics.completedSessions} sessões · qualidade média{" "}
            {gpsAnalytics.avgGpsQualityScore != null
              ? `${gpsAnalytics.avgGpsQualityScore.toFixed(0)}%`
              : "--"}
          </p>
          <div className="mt-2 flex flex-wrap gap-2 text-xs">
            {Object.entries(gpsAnalytics.qualityLabelCounts).map(([k, v]) => (
              <span key={k} className="rounded-full border border-slate-700 px-2 py-1">
                {k}: {v}
              </span>
            ))}
          </div>
          {Object.keys(gpsAnalytics.diagnosticEventCounts).length > 0 && (
            <p className="mt-2 text-xs text-slate-500">
              Diagnósticos:{" "}
              {Object.entries(gpsAnalytics.diagnosticEventCounts)
                .map(([k, v]) => `${k} (${v})`)
                .join(" · ")}
            </p>
          )}
        </div>
      )}

      <form onSubmit={saveWorkout} className="mt-6 rounded-xl border border-slate-800 bg-slate-900 p-4">
        <div className="flex items-center justify-between gap-2">
          <h3 className="font-medium">
            {editingId ? "Editar treino outdoor" : "Prescrever treino intervalado"}
          </h3>
          {editingId && (
            <button
              type="button"
              onClick={resetForm}
              className="text-xs text-slate-400 hover:text-white"
            >
              Cancelar edição
            </button>
          )}
        </div>
        <div className="mt-3 space-y-2">
          <select
            value={studentId}
            onChange={(e) => setStudentId(e.target.value)}
            className="form-input"
            required
            disabled={!!editingId}
          >
            {students.map((s) => (
              <option key={s.id} value={s.id}>{s.name}</option>
            ))}
          </select>
          <input value={title} onChange={(e) => setTitle(e.target.value)} className="form-input" required />
          <div className="grid grid-cols-3 gap-2">
            <label className="text-xs text-slate-400">
              Caminhada (min)
              <input
                type="number"
                min={1}
                value={walkMin}
                onChange={(e) => setWalkMin(Math.max(1, Number(e.target.value) || 1))}
                className="form-input mt-1"
              />
            </label>
            <label className="text-xs text-slate-400">
              Corrida (min)
              <input
                type="number"
                min={1}
                value={runMin}
                onChange={(e) => setRunMin(Math.max(1, Number(e.target.value) || 1))}
                className="form-input mt-1"
              />
            </label>
            <label className="text-xs text-slate-400">
              Quantas vezes repetir
              <input
                type="number"
                min={1}
                value={rounds}
                onChange={(e) => setRounds(Math.max(1, Number(e.target.value) || 1))}
                className="form-input mt-1"
              />
            </label>
          </div>
          <div className="rounded-lg border border-slate-700 bg-slate-950/60 p-3 text-xs text-slate-300">
            <p className="font-medium text-slate-200">Como funciona</p>
            <p className="mt-1 text-slate-400">
              Cada repetição é <span className="text-white">1 caminhada + 1 corrida</span>.
              O número do lado não é o total de minutos: é quantas vezes esse ciclo se repete.
            </p>
            <p className="mt-2 text-slate-200">
              Ex.: {rounds}× ({walkMin} min caminhada + {runMin} min corrida) ={" "}
              <span className="text-teal-300">
                {rounds} caminhadas e {rounds} corridas
              </span>{" "}
              no app do aluno · duração ≈{" "}
              <span className="text-teal-300">
                {rounds * (walkMin + runMin)} min
              </span>
              .
            </p>
            <p className="mt-1 text-slate-500">
              Para ~1 hora com 3 min caminhada + 1 min corrida, use{" "}
              <span className="text-slate-300">15 repetições</span> (15×4 = 60 min).
              No celular aparece “Rodada 1 de 15”, não “30 vezes a mesma coisa”.
            </p>
          </div>
        </div>
        <button type="submit" disabled={saving} className="btn-primary mt-3 text-sm">
          {saving ? "Salvando..." : editingId ? "Salvar alterações" : "Publicar treino outdoor"}
        </button>
      </form>

      {message && <p className="mt-3 text-sm text-green-400">{message}</p>}
      {error && <p className="mt-3 text-sm text-red-400">{error}</p>}

      <h3 className="mt-6 font-medium">Execuções recentes</h3>
      <div className="mt-2 space-y-2">
        {stats?.recentSessions.map((s) => (
          <div key={s.id} className="rounded-xl border border-slate-800 bg-slate-900 p-3 text-sm">
            <p className="font-medium">{s.studentName}</p>
            <p className="text-slate-400">
              {((s.distanceMeters ?? 0) / 1000).toFixed(2)} km · {(s.avgSpeedKmh ?? 0).toFixed(1)} km/h
              {s.caloriesKcal != null && <> · {s.caloriesKcal} kcal</>}
              {s.gpsQualityLabel != null && (
                <> · GPS {s.gpsQualityScore?.toFixed(0) ?? "--"}% {s.gpsQualityLabel}</>
              )}
            </p>
            <p className="mt-1 text-xs text-slate-500">
              Em movimento {formatDuration(s.elapsedMs)}
              {(s.pausedMs ?? 0) > 0 && (
                <> · Pausado {formatDuration(s.pausedMs)}</>
              )}
              {(s.pauseCount ?? 0) > 0 && (
                <> · {s.pauseCount} pausa{(s.pauseCount ?? 0) === 1 ? "" : "s"}</>
              )}
            </p>
            <button
              type="button"
              className="mt-2 rounded-lg border border-slate-700 px-3 py-1 text-xs hover:bg-slate-800"
              onClick={() => void loadAiInsights(s.id)}
              disabled={aiBySession[s.id] === "loading"}
            >
              {aiBySession[s.id] === "loading" ? "Analisando…" : "Insights IA"}
            </button>
            <button
              type="button"
              className="mt-2 ml-2 rounded-lg border border-amber-900/50 px-3 py-1 text-xs text-amber-200 hover:bg-amber-950/30"
              onClick={() => void loadDiagnostics(s.id)}
              disabled={diagBySession[s.id] === "loading"}
            >
              {diagBySession[s.id] === "loading" ? "Carregando…" : "Erros GPS"}
            </button>
            {aiBySession[s.id] && aiBySession[s.id] !== "loading" && aiBySession[s.id] !== "error" && (
              <div className="mt-2 rounded-lg border border-slate-800 bg-slate-950/60 p-2 text-xs text-slate-400">
                <p>
                  Risco {Math.round((aiBySession[s.id] as SessionAiInsights).overallRiskScore)}% ·{" "}
                  {(aiBySession[s.id] as SessionAiInsights).summary}
                </p>
                <ul className="mt-1 space-y-0.5">
                  {(aiBySession[s.id] as SessionAiInsights).findings.slice(0, 3).map((f, i) => (
                    <li key={`${f.code}-${i}`}>
                      [{f.severity}] {f.title}
                    </li>
                  ))}
                </ul>
              </div>
            )}
            {aiBySession[s.id] === "error" && (
              <p className="mt-1 text-xs text-red-400">Falha ao carregar insights</p>
            )}
            {Array.isArray(diagBySession[s.id]) && (
              <div className="mt-2 rounded-lg border border-amber-900/40 bg-amber-950/20 p-2 text-xs text-amber-100/90">
                <p className="font-medium text-amber-200">
                  {(diagBySession[s.id] as SessionDiagnostic[]).length} evento(s) de diagnóstico
                </p>
                <ul className="mt-1 max-h-40 space-y-1 overflow-y-auto">
                  {(diagBySession[s.id] as SessionDiagnostic[]).slice(0, 12).map((d) => (
                    <li key={d.id}>
                      <span className="text-amber-300">{d.eventType}</span>
                      {d.message ? ` — ${d.message}` : ""}
                      {d.accuracy != null ? ` · ±${Math.round(d.accuracy)}m` : ""}
                    </li>
                  ))}
                </ul>
              </div>
            )}
            {diagBySession[s.id] === "error" && (
              <p className="mt-1 text-xs text-red-400">Falha ao carregar erros GPS</p>
            )}
            {diagBySession[s.id] === "empty" && (
              <p className="mt-1 text-xs text-slate-500">Nenhum diagnóstico nesta sessão</p>
            )}
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
            <div className="flex items-start justify-between gap-2">
              <div>
                <p className="font-medium">{w.title}</p>
                <p className="text-slate-400">
                  {w.studentName} · {w.type}
                  {w.active ? (
                    <span className="ml-2 text-green-400">Ativo</span>
                  ) : (
                    <span className="ml-2 text-slate-500">Inativo</span>
                  )}
                </p>
                <p className="mt-1 text-xs text-slate-500">{summarizeIntervals(w.intervalsJson)}</p>
              </div>
            </div>
            <div className="mt-3 flex flex-wrap gap-2">
              <button
                type="button"
                onClick={() => startEdit(w)}
                className="rounded-lg border border-slate-700 px-3 py-1.5 text-xs hover:bg-slate-800"
              >
                Editar
              </button>
              <button
                type="button"
                onClick={() => void toggleActive(w)}
                className="rounded-lg border border-slate-700 px-3 py-1.5 text-xs hover:bg-slate-800"
              >
                {w.active ? "Desativar" : "Reativar"}
              </button>
              <button
                type="button"
                onClick={() => void deleteWorkout(w)}
                className="rounded-lg border border-red-900/60 px-3 py-1.5 text-xs text-red-400 hover:bg-red-950/40"
              >
                Apagar
              </button>
            </div>
          </div>
        ))}
        {workouts.length === 0 && (
          <p className="text-sm text-slate-500">Nenhum treino prescrito ainda.</p>
        )}
      </div>
    </AppShell>
  );
}
