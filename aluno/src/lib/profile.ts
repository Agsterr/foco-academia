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
}) {
  return api<StudentProfile>("/api/student/profile/onboarding", {
    method: "POST",
    body: JSON.stringify(data),
  });
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
