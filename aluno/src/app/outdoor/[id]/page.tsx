"use client";

import { useEffect, useMemo, useState } from "react";
import { useParams, useRouter } from "next/navigation";
import AppShell from "@/components/AppShell";
import RouteMap from "@/components/RouteMap";
import {
  CardioSession,
  SessionAiInsights,
  getSessionAiInsights,
  listCardioSessions,
} from "@/lib/cardio";
import { getToken } from "@/lib/api";

function formatPace(secPerKm: number | null) {
  if (secPerKm == null || !Number.isFinite(secPerKm) || secPerKm > 1800) return "--";
  const m = Math.floor(secPerKm / 60);
  const s = Math.round(secPerKm % 60)
    .toString()
    .padStart(2, "0");
  return `${m}'${s}"`;
}

export default function OutdoorSessionPage() {
  const router = useRouter();
  const params = useParams<{ id: string }>();
  const [session, setSession] = useState<CardioSession | null>(null);
  const [insights, setInsights] = useState<SessionAiInsights | null>(null);
  const [error, setError] = useState("");
  const [index, setIndex] = useState(0);
  const [playing, setPlaying] = useState(false);
  const [speed, setSpeed] = useState(2);

  useEffect(() => {
    if (!getToken()) {
      router.replace("/login");
      return;
    }
    listCardioSessions()
      .then((list) => {
        const found = list.find((s) => s.id === params.id) ?? null;
        setSession(found);
        if (!found) setError("Sessão não encontrada");
      })
      .catch((err) => setError(err instanceof Error ? err.message : "Erro"));
  }, [params.id, router]);

  useEffect(() => {
    if (!params.id || !getToken()) return;
    getSessionAiInsights(params.id)
      .then(setInsights)
      .catch(() => setInsights(null));
  }, [params.id]);

  const points = session?.routePoints ?? [];

  useEffect(() => {
    if (!playing || points.length < 2) return;
    if (index >= points.length - 1) {
      setPlaying(false);
      return;
    }
    const cur = points[index];
    const next = points[index + 1];
    const dt = Math.max(
      50,
      Math.min(
        5000,
        (new Date(next.recordedAt).getTime() - new Date(cur.recordedAt).getTime()) / speed
      )
    );
    const t = window.setTimeout(() => setIndex((i) => i + 1), dt);
    return () => window.clearTimeout(t);
  }, [playing, index, points, speed]);

  const metrics = useMemo(() => {
    if (!session || points.length === 0) {
      return { speed: 0, pace: null as number | null, alt: null as number | null, elapsed: 0 };
    }
    const p = points[Math.min(index, points.length - 1)];
    const start = new Date(points[0].recordedAt).getTime();
    const now = new Date(p.recordedAt).getTime();
    const speedKmh = p.speedKmh ?? 0;
    return {
      speed: speedKmh,
      pace: speedKmh >= 1 ? 3600 / speedKmh : null,
      alt: p.altitudeMeters ?? null,
      elapsed: Math.max(0, Math.floor((now - start) / 1000)),
    };
  }, [session, points, index]);

  return (
    <AppShell>
      <button
        type="button"
        onClick={() => router.back()}
        className="text-sm text-slate-400 hover:text-white"
      >
        ← Voltar
      </button>
      <h2 className="mt-2 text-xl font-semibold">
        {session?.workoutTitle ?? "Replay da corrida"}
      </h2>
      {error && <p className="mt-2 text-sm text-red-400">{error}</p>}

      {session && (
        <>
          <div className="mt-3 flex flex-wrap gap-2 text-xs">
            <span className="rounded-full border border-slate-700 px-2 py-1">
              {((session.distanceMeters ?? 0) / 1000).toFixed(2)} km
            </span>
            {session.caloriesKcal != null && (
              <span className="rounded-full border border-slate-700 px-2 py-1">
                {session.caloriesKcal} kcal
              </span>
            )}
            {session.gpsQualityLabel && (
              <span className="rounded-full border border-teal-800 bg-teal-950/40 px-2 py-1 text-teal-300">
                GPS {session.gpsQualityScore?.toFixed(0) ?? "--"}% · {session.gpsQualityLabel}
              </span>
            )}
          </div>

          <div className="mt-4">
            <RouteMap points={points} cursorIndex={index} />
          </div>

          <div className="mt-3 grid grid-cols-4 gap-2 text-center text-sm">
            <div className="rounded-xl border border-slate-800 bg-slate-900 p-2">
              <p className="text-xs text-slate-500">Tempo</p>
              <p className="font-semibold">
                {Math.floor(metrics.elapsed / 60)}:
                {(metrics.elapsed % 60).toString().padStart(2, "0")}
              </p>
            </div>
            <div className="rounded-xl border border-slate-800 bg-slate-900 p-2">
              <p className="text-xs text-slate-500">Vel.</p>
              <p className="font-semibold">{metrics.speed.toFixed(1)}</p>
            </div>
            <div className="rounded-xl border border-slate-800 bg-slate-900 p-2">
              <p className="text-xs text-slate-500">Pace</p>
              <p className="font-semibold">{formatPace(metrics.pace)}</p>
            </div>
            <div className="rounded-xl border border-slate-800 bg-slate-900 p-2">
              <p className="text-xs text-slate-500">Alt.</p>
              <p className="font-semibold">
                {metrics.alt != null ? `${metrics.alt.toFixed(0)} m` : "--"}
              </p>
            </div>
          </div>

          <div className="mt-4 flex items-center gap-3">
            <button
              type="button"
              className="btn-primary text-sm"
              onClick={() => {
                if (index >= points.length - 1) setIndex(0);
                setPlaying((p) => !p);
              }}
              disabled={points.length < 2}
            >
              {playing ? "Pausar" : "Reproduzir"}
            </button>
            <label className="flex flex-1 items-center gap-2 text-xs text-slate-400">
              Velocidade
              <input
                type="range"
                min={0.5}
                max={8}
                step={0.5}
                value={speed}
                onChange={(e) => setSpeed(Number(e.target.value))}
                className="flex-1"
              />
              {speed}x
            </label>
          </div>

          {insights && (
            <div
              className={`mt-4 rounded-xl border p-4 ${
                insights.suspiciousActivity
                  ? "border-amber-800/60 bg-amber-950/20"
                  : "border-slate-800 bg-slate-900"
              }`}
            >
              <h3 className="font-medium">Insights IA</h3>
              <p className="mt-1 text-sm text-slate-300">
                Risco {Math.round(insights.overallRiskScore)}% · {insights.summary}
              </p>
              {insights.performance?.trendLabel && (
                <p className="mt-1 text-xs text-slate-500">
                  Perfil: {insights.performance.trendLabel}
                </p>
              )}
              <ul className="mt-3 space-y-1 text-sm text-slate-400">
                {insights.findings.slice(0, 5).map((f, i) => (
                  <li key={`${f.code}-${i}`}>
                    [{f.severity}] {f.title}
                    {f.detail ? ` — ${f.detail}` : ""}
                  </li>
                ))}
              </ul>
              {insights.segmentSuggestions.length > 0 && (
                <p className="mt-2 text-xs text-slate-500">
                  {insights.segmentSuggestions.length} sugestão(ões) de exclusão/revisão
                  (sem inventar rota)
                </p>
              )}
            </div>
          )}
        </>
      )}
    </AppShell>
  );
}
