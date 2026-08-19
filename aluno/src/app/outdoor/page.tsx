"use client";

import { useCallback, useEffect, useRef, useState } from "react";
import { useRouter } from "next/navigation";
import AppShell from "@/components/AppShell";
import RouteMap from "@/components/RouteMap";
import {
  CardioInterval,
  CardioSession,
  CardioWorkout,
  RoutePoint,
  completeCardioSession,
  estimateCardioKcal,
  getActiveCardioWorkout,
  haversineMeters,
  parseIntervals,
  playBeeps,
  playPhaseSound,
  startCardioSession,
} from "@/lib/cardio";
import { getProfile } from "@/lib/profile";
import { getToken } from "@/lib/api";

function summarizeIntervals(intervals: CardioInterval[]): string {
  if (intervals.length === 0) return "";
  const walk = intervals.find((i) => i.phase === "WALK");
  const run = intervals.find((i) => i.phase === "RUN");
  const rounds = Math.ceil(intervals.length / 2);
  const parts: string[] = [];
  if (walk) parts.push(`${Math.round(walk.durationSec / 60)} min caminhada`);
  if (run) parts.push(`${Math.round(run.durationSec / 60)} min corrida`);
  if (parts.length === 0) return `${intervals.length} fases`;
  const cycle = parts.join(" + ");
  return rounds <= 1 ? cycle : `${cycle} · ${rounds} rodadas`;
}

export default function OutdoorPage() {
  const router = useRouter();
  const [workout, setWorkout] = useState<CardioWorkout | null>(null);
  const [session, setSession] = useState<CardioSession | null>(null);
  const [intervals, setIntervals] = useState<CardioInterval[]>([]);
  const [phaseIndex, setPhaseIndex] = useState(0);
  const [phaseRemaining, setPhaseRemaining] = useState(0);
  const [elapsed, setElapsed] = useState(0);
  const [running, setRunning] = useState(false);
  const [points, setPoints] = useState<RoutePoint[]>([]);
  const [distance, setDistance] = useState(0);
  const [error, setError] = useState("");
  const [weightKg, setWeightKg] = useState(70);
  const [walkMin, setWalkMin] = useState(2);
  const [runMin, setRunMin] = useState(2);
  const [customInterval, setCustomInterval] = useState(false);
  const [intervalKm, setIntervalKm] = useState("5");
  const [intervalMin, setIntervalMin] = useState("");
  const [intervalByTime, setIntervalByTime] = useState(false);
  const [starting, setStarting] = useState(false);
  const watchId = useRef<number | null>(null);
  const seq = useRef(0);
  const finishingRef = useRef(false);

  useEffect(() => {
    if (!getToken()) {
      router.replace("/login");
      return;
    }
    getActiveCardioWorkout()
      .then((w) => {
        setWorkout(w);
        setIntervals(parseIntervals(w.intervalsJson));
      })
      .catch(() => setWorkout(null));
    getProfile()
      .then((p) => {
        if (p.currentWeightKg) setWeightKg(p.currentWeightKg);
      })
      .catch(() => undefined);
  }, [router]);

  const looping = customInterval;
  const loopWalkSec = Math.max(1, walkMin) * 60;
  const loopRunSec = Math.max(1, runMin) * 60;
  const currentPhase = looping
    ? (elapsed % (loopWalkSec + loopRunSec) < loopWalkSec
        ? { phase: "WALK" as const, durationSec: loopWalkSec }
        : { phase: "RUN" as const, durationSec: loopRunSec })
    : intervals[phaseIndex];

  useEffect(() => {
    if (!running) return;
    if (looping) {
      const cycle = loopWalkSec + loopRunSec;
      const pos = elapsed % cycle;
      const remaining = pos < loopWalkSec ? loopWalkSec - pos : cycle - pos;
      setPhaseRemaining(remaining);
      const parsedKm = Number(String(intervalKm).replace(",", "."));
      const targetKm = !intervalByTime && parsedKm > 0 ? parsedKm : 0;
      const parsedMin = Number(intervalMin);
      const targetSec = intervalByTime && parsedMin > 0 ? parsedMin * 60 : 0;
      if ((targetKm > 0 && distance >= targetKm * 1000) || (targetSec > 0 && elapsed >= targetSec)) {
        if (!finishingRef.current) {
          playBeeps(3);
          void finish();
        }
      }
      return;
    }
    if (!currentPhase) return;
    if (phaseRemaining <= 0) {
      const next = phaseIndex + 1;
      if (next >= intervals.length) {
        playBeeps(3);
        void finish();
        return;
      }
      playBeeps(next);
      setPhaseIndex(next);
      setPhaseRemaining(intervals[next].durationSec);
      playPhaseSound(intervals[next].phase);
      return;
    }
    const t = window.setTimeout(() => setPhaseRemaining((v) => v - 1), 1000);
    return () => window.clearTimeout(t);
  }, [running, phaseRemaining, phaseIndex, currentPhase, intervals, looping, elapsed, distance, intervalKm, intervalMin, intervalByTime, loopWalkSec, loopRunSec]);

  useEffect(() => {
    if (!running) return;
    const t = window.setInterval(() => setElapsed((e) => e + 1), 1000);
    return () => window.clearInterval(t);
  }, [running]);

  const onPosition = useCallback((pos: GeolocationPosition) => {
    const { latitude, longitude, speed } = pos.coords;
    const speedKmh = speed != null ? speed * 3.6 : undefined;
    setPoints((prev) => {
      const next: RoutePoint = {
        latitude,
        longitude,
        speedKmh,
        recordedAt: new Date().toISOString(),
        sequenceNum: seq.current++,
      };
      if (prev.length > 0) {
        const last = prev[prev.length - 1];
        setDistance((d) => d + haversineMeters(last.latitude, last.longitude, latitude, longitude));
      }
      return [...prev, next];
    });
  }, []);

  async function start() {
    setError("");
    setStarting(true);
    try {
      const s = await startCardioSession(customInterval ? undefined : workout?.id, crypto.randomUUID());
      setSession(s);
      setRunning(true);
      if (looping) {
        setPhaseIndex(0);
        setPhaseRemaining(loopWalkSec);
        playBeeps(1);
        playPhaseSound("WALK");
      } else if (intervals.length > 0) {
        setPhaseIndex(0);
        setPhaseRemaining(intervals[0].durationSec);
        playBeeps(1);
        playPhaseSound(intervals[0].phase);
      }
      if (navigator.geolocation) {
        watchId.current = navigator.geolocation.watchPosition(onPosition, undefined, {
          enableHighAccuracy: true,
          maximumAge: 2000,
        });
      }
    } catch (err) {
      setError(err instanceof Error ? err.message : "Erro ao iniciar");
    } finally {
      setStarting(false);
    }
  }

  async function finish() {
    if (finishingRef.current) return;
    finishingRef.current = true;
    setRunning(false);
    if (watchId.current != null) {
      navigator.geolocation.clearWatch(watchId.current);
      watchId.current = null;
    }
    if (!session) {
      finishingRef.current = false;
      return;
    }
    const elapsedMs = elapsed * 1000;
    const avgSpeedKmh = elapsed > 0 ? distance / 1000 / (elapsed / 3600) : 0;
    const caloriesKcal = estimateCardioKcal(weightKg, avgSpeedKmh, elapsedMs, distance);
    try {
      await completeCardioSession(session.id, {
        distanceMeters: distance,
        avgSpeedKmh,
        elapsedMs,
        caloriesKcal,
        points,
      });
      router.push("/dashboard");
    } catch (caught) {
      const message = caught instanceof Error ? caught.message : "";
      if (distance < 20 || message.toLowerCase().includes("não contabilizado")) {
        setError("Treino não contabilizado: saia e caminhe um pouco antes de finalizar.");
        setSession(null);
        finishingRef.current = false;
        return;
      }
      setError(message || "Não foi possível finalizar o treino.");
      finishingRef.current = false;
    }
  }

  const formatTime = (s: number) => `${Math.floor(s / 60)}:${(s % 60).toString().padStart(2, "0")}`;
  const liveSpeed = elapsed > 0 ? distance / 1000 / (elapsed / 3600) : 0;
  const liveCalories = estimateCardioKcal(weightKg, liveSpeed, elapsed * 1000, distance);

  return (
    <AppShell>
      <h2 className="text-xl font-semibold">Treino outdoor</h2>
      <p className="mt-1 text-sm text-slate-400">
        {workout ? workout.title : "Corrida/caminhada livre"}
      </p>
      {intervals.length > 0 && (
        <p className="mt-1 text-sm text-teal-300">
          {summarizeIntervals(intervals)}
        </p>
      )}

      {intervals.length > 0 && !running && !customInterval && (
        <div className="mt-3 grid grid-cols-2 gap-2 rounded-xl border border-slate-700 bg-slate-900/80 p-3 text-center text-sm">
          {intervals.find((i) => i.phase === "WALK") && (
            <div>
              <p className="text-xs text-green-400">CAMINHADA</p>
              <p className="text-lg font-semibold">
                {Math.round((intervals.find((i) => i.phase === "WALK")!.durationSec) / 60)} min
              </p>
            </div>
          )}
          {intervals.find((i) => i.phase === "RUN") && (
            <div>
              <p className="text-xs text-red-400">CORRIDA</p>
              <p className="text-lg font-semibold">
                {Math.round((intervals.find((i) => i.phase === "RUN")!.durationSec) / 60)} min
              </p>
            </div>
          )}
        </div>
      )}

      {!running && (
        <div className="mt-3 rounded-xl border border-slate-700 bg-slate-900/80 p-3">
          <label className="flex items-center gap-2 text-sm">
            <input
              type="checkbox"
              checked={customInterval}
              onChange={(e) => setCustomInterval(e.target.checked)}
            />
            Criar intervalado (caminhada + corrida)
          </label>
          {customInterval && (
            <div className="mt-3 space-y-2">
              <div className="grid grid-cols-2 gap-2">
                <label className="text-xs text-slate-400">
                  Caminhada (min)
                  <input
                    type="number"
                    min={1}
                    max={30}
                    value={walkMin}
                    onChange={(e) => setWalkMin(Number(e.target.value) || 1)}
                    className="form-input mt-1"
                  />
                </label>
                <label className="text-xs text-slate-400">
                  Corrida (min)
                  <input
                    type="number"
                    min={1}
                    max={30}
                    value={runMin}
                    onChange={(e) => setRunMin(Number(e.target.value) || 1)}
                    className="form-input mt-1"
                  />
                </label>
              </div>
              <div className="space-y-2">
                <p className="text-xs text-slate-400">Até quantos km? (ou minutos)</p>
                <div className="grid grid-cols-2 gap-2">
                  <label className="text-xs text-slate-400">
                    Distância (km)
                    <input
                      type="number"
                      min={0.1}
                      step={0.1}
                      value={intervalByTime ? "" : intervalKm}
                      onChange={(e) => {
                        setIntervalByTime(false);
                        setIntervalKm(e.target.value);
                        setIntervalMin("");
                      }}
                      className="form-input mt-1"
                      placeholder="ex. 7.5"
                    />
                  </label>
                  <label className="text-xs text-slate-400">
                    ou tempo (min)
                    <input
                      type="number"
                      min={1}
                      value={intervalByTime ? intervalMin : ""}
                      onChange={(e) => {
                        setIntervalByTime(true);
                        setIntervalMin(e.target.value);
                        setIntervalKm("");
                      }}
                      className="form-input mt-1"
                      placeholder="ex. 40"
                    />
                  </label>
                </div>
                <div className="flex flex-wrap gap-2">
                  {[
                    { label: "5 km", km: "5" },
                    { label: "10 km", km: "10" },
                  ].map((t) => (
                    <button
                      key={t.label}
                      type="button"
                      onClick={() => {
                        setIntervalByTime(false);
                        setIntervalKm(t.km);
                        setIntervalMin("");
                      }}
                      className={`rounded-full px-3 py-1 text-sm ${
                        !intervalByTime && intervalKm === t.km
                          ? "bg-blue-600 text-white"
                          : "bg-slate-800 text-slate-300"
                      }`}
                    >
                      {t.label}
                    </button>
                  ))}
                  <button
                    type="button"
                    onClick={() => {
                      setIntervalByTime(true);
                      setIntervalMin("60");
                      setIntervalKm("");
                    }}
                    className={`rounded-full px-3 py-1 text-sm ${
                      intervalByTime && intervalMin === "60"
                        ? "bg-blue-600 text-white"
                        : "bg-slate-800 text-slate-300"
                    }`}
                  >
                    1 hora
                  </button>
                </div>
              </div>
              <p className="text-xs text-teal-300">
                {walkMin} min caminhada + {runMin} min corrida{" "}
                {intervalByTime
                  ? `por ${intervalMin || "?"} min`
                  : `até ${intervalKm || "?"} km`}
              </p>
            </div>
          )}
        </div>
      )}

      <RouteMap points={points} />

      <div className="mt-4 grid grid-cols-2 gap-2 text-center sm:grid-cols-4">
        <div className="rounded-xl border border-slate-800 bg-slate-900 p-3">
          <p className="text-xs text-slate-500">Tempo</p>
          <p className="text-lg font-semibold">{formatTime(elapsed)}</p>
        </div>
        <div className="rounded-xl border border-slate-800 bg-slate-900 p-3">
          <p className="text-xs text-slate-500">Distância</p>
          <p className="text-lg font-semibold">{(distance / 1000).toFixed(2)} km</p>
        </div>
        <div className="rounded-xl border border-slate-800 bg-slate-900 p-3">
          <p className="text-xs text-slate-500">Vel. média</p>
          <p className="text-lg font-semibold">{liveSpeed.toFixed(1)} km/h</p>
        </div>
        <div className="rounded-xl border border-slate-800 bg-slate-900 p-3">
          <p className="text-xs text-slate-500">Calorias*</p>
          <p className="text-lg font-semibold text-orange-300">{liveCalories}</p>
        </div>
      </div>
      {currentPhase && (
        <p className="mt-2 text-center text-sm text-slate-400">
          Fase: {currentPhase.phase} · {phaseRemaining}s
        </p>
      )}
      <p className="mt-1 text-center text-[11px] text-slate-500">
        *Estimativa MET com base no peso do perfil ({weightKg} kg)
      </p>

      {error && <p className="mt-3 text-sm text-red-400">{error}</p>}

      <div className="mt-4 flex gap-2 pb-[max(1.25rem,env(safe-area-inset-bottom))]">
        {!running ? (
          <button onClick={start} disabled={starting} className="btn-primary flex-1">
            {starting ? "Iniciando..." : "Iniciar"}
          </button>
        ) : (
          <button onClick={finish} className="btn-primary flex-1 bg-red-600 hover:bg-red-500">
            Finalizar
          </button>
        )}
      </div>
    </AppShell>
  );
}
