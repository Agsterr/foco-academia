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
  accuracyMeters?: number;
  heading?: number;
  altitudeMeters?: number;
  provider?: string;
  isFiltered?: boolean;
  filterReason?: string;
  confidenceScore?: number;
  batteryLevel?: number;
  verticalAccuracy?: number;
  bearingAccuracy?: number;
  speedAccuracy?: number;
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
  caloriesKcal?: number;
  gpsQualityScore?: number;
  gpsQualityLabel?: string;
  routePoints: RoutePoint[];
}

export function parseIntervals(json?: string | CardioInterval[] | null): CardioInterval[] {
  if (!json) return [];
  try {
    const list = typeof json === "string" ? (JSON.parse(json) as unknown) : json;
    if (!Array.isArray(list)) return [];
    return list
      .filter((i): i is CardioInterval =>
        !!i &&
        typeof i === "object" &&
        typeof (i as CardioInterval).phase === "string" &&
        typeof (i as CardioInterval).durationSec === "number" &&
        (i as CardioInterval).durationSec > 0
      )
      .map((i) => ({
        phase: i.phase === "RUN" ? "RUN" : "WALK",
        durationSec: i.durationSec,
      }));
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
    caloriesKcal?: number;
    points: RoutePoint[];
  }
) {
  return api<CardioSession>(`/api/student/cardio-sessions/${sessionId}/complete`, {
    method: "POST",
    body: JSON.stringify(data),
  });
}

/** Estimativa MET: kcal = MET × peso × horas. Parado (sem km) → 0. */
export function estimateCardioKcal(
  weightKg: number,
  avgSpeedKmh: number,
  elapsedMs: number,
  distanceMeters?: number,
): number {
  if (elapsedMs <= 0) return 0;
  const hours = elapsedMs / 3_600_000;
  if (hours <= 0) return 0;

  let speed = Number.isFinite(avgSpeedKmh) ? avgSpeedKmh : 0;
  if (distanceMeters != null && distanceMeters >= 20 && hours > 0) {
    const fromDist = distanceMeters / 1000 / hours;
    if (Number.isFinite(fromDist) && fromDist > 0) speed = fromDist;
  }
  speed = Math.max(0, Math.min(22, speed));

  const moved = distanceMeters != null && distanceMeters >= 20;
  if (!moved && speed < 1) return 0;
  if (moved && speed < 0.6) {
    return Math.round(0.7 * weightKg * (distanceMeters! / 1000));
  }

  const met = metForSpeed(speed);
  let kcal = met * weightKg * hours;

  if (distanceMeters != null && distanceMeters > 0) {
    const km = distanceMeters / 1000;
    const perKgPerKm = speed >= 6.5 ? 1.15 : 0.85;
    const cap = perKgPerKm * weightKg * km * 1.2;
    const floor = 0.55 * weightKg * km;
    if (cap >= floor) {
      kcal = Math.max(floor, Math.min(cap, kcal));
    } else {
      kcal = Math.max(0, Math.min(cap, kcal));
    }
  }

  return Math.round(Math.max(0, kcal));
}

function metForSpeed(speed: number): number {
  if (speed <= 0.3) return 1.0;
  if (speed < 2) return 1 + ((speed - 0.3) / 1.7);
  if (speed < 6.5) {
    if (speed <= 3) return 2.5;
    if (speed <= 4) return 3.0;
    if (speed <= 5) return 3.8;
    return 4.8;
  }
  if (speed <= 7) return 7.0;
  if (speed <= 8) return 8.3;
  if (speed <= 9) return 9.0;
  if (speed <= 10) return 9.8;
  if (speed <= 11) return 10.5;
  if (speed <= 12) return 11.8;
  return 12.8;
}

export function listCardioSessions() {
  return api<CardioSession[]>("/api/student/cardio-sessions");
}

export interface GpsAiFinding {
  code: string;
  severity: string;
  title: string;
  detail?: string;
  sequenceFrom?: number;
  sequenceTo?: number;
}

export interface GpsAiSegmentSuggestion {
  sequenceFrom: number;
  sequenceTo: number;
  action: string;
  reason: string;
}

export interface SessionAiInsights {
  sessionId: string;
  overallRiskScore: number;
  summary: string;
  findings: GpsAiFinding[];
  segmentSuggestions: GpsAiSegmentSuggestion[];
  suspiciousActivity: boolean;
  performance?: {
    avgPaceSecPerKm?: number;
    avgSpeedKmh?: number;
    trendLabel?: string;
  };
}

export interface AthleteRecommendations {
  evolutionSummary: string;
  predictedNextKmPaceSecPerKm?: number;
  recommendations: string[];
  warnings: string[];
}

export function getSessionAiInsights(sessionId: string) {
  return api<SessionAiInsights>(`/api/student/cardio-sessions/${sessionId}/ai-insights`);
}

export function getAthleteRecommendations() {
  return api<AthleteRecommendations>("/api/student/ai/recommendations");
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
