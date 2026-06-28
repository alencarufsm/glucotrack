export type DiabetesType = 'TYPE_1' | 'PREDIABETES' | 'NONE';
export type MealContext = 'FASTING' | 'PRE_MEAL' | 'POST_MEAL';
export type ReadingSource = 'MANUAL' | 'CGM_IMPORT' | 'LIBRE';
export type ActivityIntensity = 'LOW' | 'MODERATE' | 'HIGH';
export type FamilyConnectionStatus = 'PENDING' | 'ACTIVE';
export type AlertType = 'HYPOGLYCEMIA' | 'HYPERGLYCEMIA' | 'RAPID_FALL' | 'RAPID_RISE' | 'REMINDER';

export interface User {
  id: string;
  name: string;
  email: string;
  diabetesType: DiabetesType;
  birthDate?: string;
  weight?: number;
  physicalLimitations?: string;
  targetMin: number;
  targetMax: number;
}

export interface GlucoseReading {
  id: string;
  userId: string;
  value: number;
  measuredAt: string;
  mealContext: MealContext;
  source: ReadingSource;
  notes?: string;
}

export interface InsulinDose {
  id: string;
  userId: string;
  readingId?: string;
  insulinType: string;
  doseUnits: number;
  appliedAt: string;
}

export interface PhysicalActivity {
  id: string;
  userId: string;
  type: string;
  durationMinutes: number;
  intensity: ActivityIntensity;
  performedAt: string;
}

export interface FamilyConnection {
  id: string;
  monitoredUserId: string;
  observerUserId: string;
  monitoredUserName?: string;
  observerUserName?: string;
  status: FamilyConnectionStatus;
  invitedAt: string;
  acceptedAt?: string;
}

export interface Alert {
  id: string;
  userId: string;
  type: AlertType;
  triggeredAt: string;
  readingId?: string;
  readingValue?: number;
}

export interface GlucoseStats {
  average: number;
  timeInRange: number;
  timeBelow: number;
  timeAbove: number;
  coefficientOfVariation: number;
  estimatedHba1c: number;
  totalReadings: number;
  periodDays: number;
}

export interface NewReadingRequest {
  value: number;
  measuredAt: string;
  mealContext: MealContext;
  notes?: string;
}

export interface LibreLinkStatus {
  connected: boolean;
  patientName: string | null;
  lastSync: string | null;
}

export interface LibreLinkPatient {
  patientId: string;
  displayName: string;
}

export interface LibreLinkTestResponse {
  patients: LibreLinkPatient[];
}

export interface LibreLinkSyncResponse {
  synced: number;
}
