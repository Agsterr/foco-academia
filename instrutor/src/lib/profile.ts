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
