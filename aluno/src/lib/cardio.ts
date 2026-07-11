import { api } from "./api";

export type CardioType = "RUN" | "WALK" | "INTERVAL" | "STRETCH";

export interface CardioInterval {
  phase: "RUN" | "WALK";
  durationSec: number;
}

export interface CardioWorkout {
  id: string;
  title: string;
  type: CardioType;
  intervalsJson?: string;
  active: boolean;
}

export interface RoutePoint {
  latitude: number;
  longitude: number;
  speedKmh?: number;
  recordedAt: string;
  sequenceNum: number;
}

export interface CardioSession {
  id: string;
  workoutId?: string;
  workoutTitle?: string;
  startedAt: string;
  completedAt?: string;
  distanceMeters?: number;
  avgSpeedKmh?: number;
  elapsedMs?: number;
  routePoints: RoutePoint[];
}

export function parseIntervals(json?: string): CardioInterval[] {
  if (!json) return [];
  try {
    return JSON.parse(json) as CardioInterval[];
  } catch {
    return [];
  }
}

export function getActiveCardioWorkout() {
  return api<CardioWorkout>("/api/student/cardio-workouts/active");
}

export function startCardioSession(workoutId?: string, clientSessionId?: string) {
  return api<CardioSession>("/api/student/cardio-sessions/start", {
    method: "POST",
    body: JSON.stringify({ workoutId, clientSessionId }),
  });
}

export function completeCardioSession(
  sessionId: string,
  data: {
    distanceMeters: number;
    avgSpeedKmh: number;
    elapsedMs: number;
    points: RoutePoint[];
  }
) {
  return api<CardioSession>(`/api/student/cardio-sessions/${sessionId}/complete`, {
    method: "POST",
    body: JSON.stringify(data),
  });
}

export function listCardioSessions() {
  return api<CardioSession[]>("/api/student/cardio-sessions");
}

export function haversineMeters(
  lat1: number,
  lon1: number,
  lat2: number,
  lon2: number
): number {
  const R = 6371000;
  const toRad = (v: number) => (v * Math.PI) / 180;
  const dLat = toRad(lat2 - lat1);
  const dLon = toRad(lon2 - lon1);
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLon / 2) ** 2;
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

export function playBeeps(count: number) {
  if (typeof window === "undefined") return;
  const ctx = new AudioContext();
  for (let i = 0; i < count; i++) {
    const osc = ctx.createOscillator();
    const gain = ctx.createGain();
    osc.connect(gain);
    gain.connect(ctx.destination);
    osc.frequency.value = 880;
    const start = ctx.currentTime + i * 0.35;
    gain.gain.setValueAtTime(0.0001, start);
    gain.gain.exponentialRampToValueAtTime(0.3, start + 0.02);
    gain.gain.exponentialRampToValueAtTime(0.0001, start + 0.2);
    osc.start(start);
    osc.stop(start + 0.25);
  }
}

export function playPhaseSound(phase: "RUN" | "WALK") {
  if (typeof window === "undefined") return;
  const ctx = new AudioContext();
  const osc = ctx.createOscillator();
  const gain = ctx.createGain();
  osc.connect(gain);
  gain.connect(ctx.destination);
  osc.frequency.value = phase === "RUN" ? 1200 : 600;
  gain.gain.value = 0.25;
  osc.start();
  osc.stop(ctx.currentTime + 0.3);
  if (navigator.vibrate) {
    navigator.vibrate(phase === "RUN" ? [200, 100, 200] : [100]);
  }
}
