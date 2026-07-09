"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import AppShell from "@/components/AppShell";
import {
  Feedback,
  SessionFeedback,
  api,
  getToken,
  ratingLabels,
  weekDayLabels,
} from "@/lib/api";

function formatDuration(seconds?: number): string {
  if (!seconds) return "—";
  const m = Math.floor(seconds / 60);
  const s = seconds % 60;
  return `${m}:${s.toString().padStart(2, "0")}`;
}

export default function AvaliacoesPage() {
  const router = useRouter();
  const [sessionFeedbacks, setSessionFeedbacks] = useState<SessionFeedback[]>([]);
  const [legacyFeedbacks, setLegacyFeedbacks] = useState<Feedback[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    if (!getToken()) {
      router.replace("/login");
      return;
    }
    Promise.all([
      api<SessionFeedback[]>("/api/instructor/session-feedbacks"),
      api<Feedback[]>("/api/instructor/feedbacks"),
    ])
      .then(([sessions, legacy]) => {
        setSessionFeedbacks(sessions);
        setLegacyFeedbacks(legacy);
      })
      .catch(() => router.replace("/login"))
      .finally(() => setLoading(false));
  }, [router]);

  const hasAny = sessionFeedbacks.length > 0 || legacyFeedbacks.length > 0;

  return (
    <AppShell>
      <h2 className="mb-1 text-xl font-semibold">Avaliações dos alunos</h2>
      <p className="mb-4 text-sm text-slate-400">
        O que os alunos acharam dos treinos — use para melhorar a ficha semanal.
      </p>

      {loading && <p className="text-slate-400">Carregando...</p>}

      {!loading && !hasAny && (
        <p className="rounded-xl border border-dashed border-slate-700 p-6 text-center text-slate-400">
          Nenhuma avaliação ainda. Quando o aluno finalizar um treino, aparece aqui.
        </p>
      )}

      <div className="space-y-3">
        {sessionFeedbacks.map((f) => (
          <div key={f.id} className="rounded-xl border border-slate-800 bg-slate-900 p-4">
            <div className="flex items-start justify-between gap-2">
              <div>
                <p className="font-medium">{f.student.name}</p>
                <p className="mt-0.5 text-sm text-violet-300">
                  {weekDayLabels[f.weekDay]} — {f.muscleGroup || "Treino"}
                </p>
                <p className="text-xs text-slate-500">{f.programTitle}</p>
              </div>
              <span className="shrink-0 rounded-full bg-slate-800 px-2 py-0.5 text-xs">
                {f.rating ? ratingLabels[f.rating] : "Sem nota"}
              </span>
            </div>
            {f.comment && (
              <p className="mt-3 rounded-lg bg-slate-800/60 p-3 text-sm text-slate-200">
                &ldquo;{f.comment}&rdquo;
              </p>
            )}
            <div className="mt-2 flex flex-wrap gap-3 text-xs text-slate-500">
              <span>{f.setsCompleted} séries marcadas</span>
              <span>Tempo: {formatDuration(f.totalDurationSeconds)}</span>
              <span>{new Date(f.completedAt).toLocaleString("pt-BR")}</span>
            </div>
          </div>
        ))}

        {legacyFeedbacks.map((f) => (
          <div key={f.id} className="rounded-xl border border-slate-700/50 bg-slate-900/60 p-4">
            <div className="flex items-center justify-between">
              <p className="font-medium">{f.student.name}</p>
              <span className="rounded-full bg-slate-800 px-2 py-0.5 text-xs">
                {ratingLabels[f.rating]}
              </span>
            </div>
            <p className="mt-1 text-xs text-slate-500">Treino antigo (formato anterior)</p>
            {f.comment && <p className="mt-2 text-sm text-slate-300">{f.comment}</p>}
            <p className="mt-2 text-xs text-slate-500">
              {new Date(f.createdAt).toLocaleDateString("pt-BR")}
            </p>
          </div>
        ))}
      </div>
    </AppShell>
  );
}
