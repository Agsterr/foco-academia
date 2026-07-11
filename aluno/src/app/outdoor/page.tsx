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
  getActiveCardioWorkout,
  haversineMeters,
  parseIntervals,
  playBeeps,
  playPhaseSound,
  startCardioSession,
} from "@/lib/cardio";
import { getToken } from "@/lib/api";

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
  const watchId = useRef<number | null>(null);
  const seq = useRef(0);

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
  }, [router]);

  const currentPhase = intervals[phaseIndex];

  useEffect(() => {
    if (!running || !currentPhase) return;
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
  }, [running, phaseRemaining, phaseIndex, currentPhase, intervals]);

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
    try {
      const s = await startCardioSession(workout?.id, crypto.randomUUID());
      setSession(s);
      setRunning(true);
      if (intervals.length > 0) {
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
    }
  }

  async function finish() {
    setRunning(false);
    if (watchId.current != null) {
      navigator.geolocation.clearWatch(watchId.current);
    }
    if (!session) return;
    const elapsedMs = elapsed * 1000;
    const avgSpeedKmh = elapsed > 0 ? distance / 1000 / (elapsed / 3600) : 0;
    await completeCardioSession(session.id, {
      distanceMeters: distance,
      avgSpeedKmh,
      elapsedMs,
      points,
    });
    router.push("/evolucao");
  }

  const formatTime = (s: number) => `${Math.floor(s / 60)}:${(s % 60).toString().padStart(2, "0")}`;

  return (
    <AppShell>
      <h2 className="text-xl font-semibold">Treino outdoor</h2>
      <p className="mt-1 text-sm text-slate-400">
        {workout ? workout.title : "Corrida/caminhada livre"}
      </p>

      <RouteMap points={points} />

      <div className="mt-4 grid grid-cols-3 gap-2 text-center">
        <div className="rounded-xl border border-slate-800 bg-slate-900 p-3">
          <p className="text-xs text-slate-500">Tempo</p>
          <p className="text-lg font-semibold">{formatTime(elapsed)}</p>
        </div>
        <div className="rounded-xl border border-slate-800 bg-slate-900 p-3">
          <p className="text-xs text-slate-500">Distância</p>
          <p className="text-lg font-semibold">{(distance / 1000).toFixed(2)} km</p>
        </div>
        <div className="rounded-xl border border-slate-800 bg-slate-900 p-3">
          <p className="text-xs text-slate-500">Fase</p>
          <p className="text-lg font-semibold">
            {currentPhase ? `${currentPhase.phase} ${phaseRemaining}s` : "—"}
          </p>
        </div>
      </div>

      {error && <p className="mt-3 text-sm text-red-400">{error}</p>}

      <div className="mt-4 flex gap-2">
        {!running ? (
          <button onClick={start} className="btn-primary flex-1">
            Iniciar
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
