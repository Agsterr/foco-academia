import { api } from "./api";

export type FitnessGoal =
  | "EMAGRECER"
  | "GANHAR_MASSA"
  | "CONDICIONAMENTO"
  | "CORRIDA"
  | "ALONGAMENTO"
  | "MANUTENCAO";

export const goalLabels: Record<FitnessGoal, string> = {
  EMAGRECER: "Emagrecer",
  GANHAR_MASSA: "Ganhar massa",
  CONDICIONAMENTO: "Condicionamento",
  CORRIDA: "Corrida / caminhada",
  ALONGAMENTO: "Alongamento",
  MANUTENCAO: "Manutenção",
};

export interface StudentProfile {
  studentId: string;
  studentName: string;
  heightCm?: number;
  currentWeightKg?: number;
  goal?: FitnessGoal;
  onboardingCompleted: boolean;
  sex?: "MASCULINO" | "FEMININO" | "NAO_INFORMADO";
  birthDate?: string;
  age?: number;
  activityLevel?: "SEDENTARIO" | "LEVE" | "MODERADO" | "INTENSO" | "MUITO_INTENSO";
}

export interface ProfileStatus {
  onboardingCompleted: boolean;
  pendingWeightCheck: boolean;
  pendingWeightSchedule?: {
    id: string;
    dueDate: string;
    overdue: boolean;
  };
  suggestGoalCheckIn: boolean;
}

export interface BodyMeasurement {
  id: string;
  weightKg: number;
  waistCm?: number;
  hipsCm?: number;
  chestCm?: number;
  recordedAt: string;
  source: string;
  notes?: string;
}

export function getProfileStatus() {
  return api<ProfileStatus>("/api/student/profile/status");
}

export function getProfile() {
  return api<StudentProfile>("/api/student/profile");
}

export function completeOnboarding(data: {
  heightCm: number;
  weightKg: number;
  goal: FitnessGoal;
  sex?: StudentProfile["sex"];
  birthDate?: string;
  activityLevel?: StudentProfile["activityLevel"];
}) {
  return api<StudentProfile>("/api/student/profile/onboarding", {
    method: "POST",
    body: JSON.stringify(data),
  });
}

export function updateProfile(data: {
  heightCm?: number;
  weightKg?: number;
  goal?: FitnessGoal;
  sex?: StudentProfile["sex"];
  birthDate?: string;
  activityLevel?: StudentProfile["activityLevel"];
}) {
  return api<StudentProfile>("/api/student/profile", {
    method: "PUT",
    body: JSON.stringify(data),
  });
}

export interface CalorieStats {
  caloriesToday: number;
  kmToday: number;
  minutesToday: number;
  caloriesLast7Days: number;
  kmLast7Days: number;
  caloriesLast30Days: number;
  kmLast30Days: number;
  caloriesLast12Months: number;
  kmLast12Months: number;
  totalKm: number;
  totalHours: number;
  totalSessions: number;
  cardioSessions: number;
  avgCaloriesPerSession: number;
  maxCaloriesSingleSession: number;
  maxDistanceKm: number;
  maxDurationMinutes: number;
  currentStreakDays: number;
  weekly: { label: string; calories: number; km: number; sessions: number }[];
  monthly: { label: string; calories: number; km: number; sessions: number }[];
  yearly: { label: string; calories: number; km: number; sessions: number }[];
  recentDistances: {
    id: string;
    completedAt: string;
    title: string;
    distanceKm: number;
    caloriesKcal?: number;
    elapsedMs?: number;
    avgSpeedKmh?: number;
  }[];
  estimateDisclaimer: string;
}

export function getCalorieStats() {
  return api<CalorieStats>("/api/student/calorie-stats");
}

export function addMeasurement(data: {
  weightKg: number;
  waistCm?: number;
  hipsCm?: number;
  chestCm?: number;
  notes?: string;
  /** STUDENT | SCALE_BLE | WATCH | IMPORT */
  source?: string;
}) {
  return api<BodyMeasurement>("/api/student/measurements", {
    method: "POST",
    body: JSON.stringify(data),
  });
}

export function listMeasurements() {
  return api<BodyMeasurement[]>("/api/student/measurements");
}

export function submitGoalCheckIn(data: {
  achievingGoal: boolean;
  progressRating: number;
  comment?: string;
}) {
  return api("/api/student/goal-checkins", {
    method: "POST",
    body: JSON.stringify(data),
  });
}
