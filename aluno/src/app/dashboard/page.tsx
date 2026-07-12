"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import AppShell from "@/components/AppShell";
import { CalorieStats, getCalorieStats } from "@/lib/profile";
import { getToken } from "@/lib/api";

function formatSessionDate(iso: string) {
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return iso;
  return d.toLocaleString("pt-BR", {
    day: "2-digit",
    month: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
  });
}

export default function DashboardPage() {
  const router = useRouter();
  const [stats, setStats] = useState<CalorieStats | null>(null);
  const [error, setError] = useState("");

  useEffect(() => {
    if (!getToken()) {
      router.replace("/login");
      return;
    }
    getCalorieStats()
      .then(setStats)
      .catch((err) => setError(err instanceof Error ? err.message : "Erro"));
  }, [router]);

  const maxWeekKm = stats
    ? Math.max(...stats.weekly.map((b) => b.km), 0.01)
    : 1;
  const maxMonthKm = stats
    ? Math.max(...stats.monthly.map((b) => b.km), 0.01)
    : 1;

  return (
    <AppShell>
      <h2 className="text-xl font-semibold">Dashboard</h2>
      <p className="mt-1 text-sm text-slate-400">
        Quilômetros percorridos, calorias e histórico de outdoor.
      </p>

      {error && <p className="mt-3 text-sm text-red-400">{error}</p>}

      {stats && (
        <>
          <div className="mt-4 rounded-xl border border-teal-900/50 bg-teal-950/30 p-4 text-center">
            <p className="text-xs text-teal-400/80">Total percorrido</p>
            <p className="text-3xl font-bold text-teal-300">{stats.totalKm.toFixed(1)} km</p>
            <p className="mt-1 text-xs text-slate-500">
              {stats.cardioSessions} corridas/caminhadas · {stats.kmToday.toFixed(1)} km hoje
            </p>
          </div>

          <div className="mt-3 grid grid-cols-3 gap-2 text-center text-sm">
            <div className="rounded-xl border border-slate-800 bg-slate-900 p-3">
              <p className="text-xs text-slate-500">7 dias</p>
              <p className="font-semibold text-sky-300">{stats.kmLast7Days.toFixed(1)} km</p>
            </div>
            <div className="rounded-xl border border-slate-800 bg-slate-900 p-3">
              <p className="text-xs text-slate-500">30 dias</p>
              <p className="font-semibold text-sky-300">{stats.kmLast30Days.toFixed(1)} km</p>
            </div>
            <div className="rounded-xl border border-slate-800 bg-slate-900 p-3">
              <p className="text-xs text-slate-500">12 meses</p>
              <p className="font-semibold text-sky-300">{stats.kmLast12Months.toFixed(1)} km</p>
            </div>
          </div>

          <div className="mt-3 grid grid-cols-3 gap-2 text-center">
            <div className="rounded-xl border border-slate-800 bg-slate-900 p-3">
              <p className="text-xs text-slate-500">kcal hoje</p>
              <p className="text-lg font-semibold text-orange-300">{stats.caloriesToday}</p>
            </div>
            <div className="rounded-xl border border-slate-800 bg-slate-900 p-3">
              <p className="text-xs text-slate-500">Min hoje</p>
              <p className="text-lg font-semibold">{stats.minutesToday}</p>
            </div>
            <div className="rounded-xl border border-slate-800 bg-slate-900 p-3">
              <p className="text-xs text-slate-500">Maior rota</p>
              <p className="text-lg font-semibold">{stats.maxDistanceKm.toFixed(2)} km</p>
            </div>
          </div>

          <h3 className="mt-6 font-medium">Km — últimos 7 dias</h3>
          <div className="mt-2 space-y-2">
            {stats.weekly.map((b) => (
              <div key={b.label} className="flex items-center gap-2 text-sm">
                <span className="w-12 text-slate-500">{b.label}</span>
                <div className="h-2 flex-1 overflow-hidden rounded bg-slate-800">
                  <div
                    className="h-full rounded bg-sky-500"
                    style={{ width: `${Math.min(100, (b.km / maxWeekKm) * 100)}%` }}
                  />
                </div>
                <span className="w-16 text-right">{b.km.toFixed(1)} km</span>
              </div>
            ))}
          </div>

          <h3 className="mt-6 font-medium">Km — últimos 12 meses</h3>
          <div className="mt-2 space-y-2">
            {stats.monthly.map((b) => (
              <div key={b.label} className="flex items-center gap-2 text-sm">
                <span className="w-16 text-slate-500">{b.label}</span>
                <div className="h-2 flex-1 overflow-hidden rounded bg-slate-800">
                  <div
                    className="h-full rounded bg-teal-500"
                    style={{ width: `${Math.min(100, (b.km / maxMonthKm) * 100)}%` }}
                  />
                </div>
                <span className="w-16 text-right">{b.km.toFixed(1)} km</span>
              </div>
            ))}
          </div>

          <h3 className="mt-6 font-medium">Histórico de distâncias</h3>
          <div className="mt-2 space-y-2">
            {stats.recentDistances.length === 0 && (
              <p className="text-sm text-slate-500">Nenhuma corrida/caminhada registrada ainda.</p>
            )}
            {stats.recentDistances.map((r) => (
              <button
                key={r.id}
                type="button"
                onClick={() => router.push(`/outdoor/${r.id}`)}
                className="flex w-full items-center justify-between rounded-xl border border-slate-800 bg-slate-900 p-3 text-left text-sm hover:border-slate-600"
              >
                <div>
                  <p className="font-medium">{r.title}</p>
                  <p className="text-xs text-slate-500">{formatSessionDate(r.completedAt)}</p>
                </div>
                <div className="text-right">
                  <p className="font-semibold text-sky-300">{r.distanceKm.toFixed(2)} km</p>
                  {r.caloriesKcal != null && (
                    <p className="text-xs text-orange-300/80">{r.caloriesKcal} kcal</p>
                  )}
                  <p className="text-xs text-teal-400/80">Replay →</p>
                </div>
              </button>
            ))}
          </div>

          <div className="mt-4 rounded-xl border border-slate-800 bg-slate-900 p-4 text-sm text-slate-400">
            Totais: {stats.totalHours.toFixed(1)} h · {stats.totalSessions} treinos · média{" "}
            {stats.avgCaloriesPerSession.toFixed(0)} kcal · sequência {stats.currentStreakDays} dias
          </div>

          <p className="mt-4 text-xs text-slate-500">{stats.estimateDisclaimer}</p>
        </>
      )}
    </AppShell>
  );
}
