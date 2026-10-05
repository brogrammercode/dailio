export type User = {
  id: string;
  name: string;
  email: string;
  phone?: string | null;
  avatar_url?: string | null;
  status: "ACTIVE" | "DISABLED";
};

export type TenantContext = {
  organizationId: string;
  branchId: string;
  branchName?: string;
  organizationName?: string;
  organizationType?: string;
  timezone?: string;
  permissions?: string[];
};

export type AttendancePolicy = {
  version?: number;
  punch_required?: boolean;
  selfie_on_clock_in?: boolean;
  selfie_on_clock_out?: boolean;
  qr_scan_on_clock_in?: boolean;
  qr_scan_on_clock_out?: boolean;
  location_on_clock_in?: boolean;
  location_on_clock_out?: boolean;
  geofence_enabled?: boolean;
  late_grace_minutes?: number;
  shift_enforcement_enabled?: boolean;
  shift?: {
    name?: string;
    start_time?: string;
    end_time?: string;
    is_overnight?: boolean;
  } | null;
};

export type Invite = {
  id: string;
  purpose: "BRANCH_JOIN" | "PLAN_PURCHASE" | "MEAL_ATTENDANCE";
  organization: { id: string; name: string };
  branch: {
    id: string;
    name: string;
    city?: string | null;
    state?: string | null;
    timezone: string;
  };
  plan?: {
    id: string;
    name: string;
    duration_days: number;
    amount_minor_unit: number;
    joining_fee_minor: number;
    currency: string;
    discount_percent: number;
    is_active: boolean;
  } | null;
  joinability?:
    "JOINABLE" | "ALREADY_PENDING" | "ALREADY_MEMBER" | "MEMBERSHIP_INACTIVE";
  existing_request_id?: string | null;
  membership_id?: string | null;
  attendance_action?: "CLOCK_IN" | "CLOCK_OUT" | "ATTENDANCE_DISABLED" | null;
  attendance_available?: boolean;
  active_session_id?: string | null;
  attendance_policy?: AttendancePolicy | null;
  meal_slots?: {
    id: string;
    name: string;
    code: string;
    starts_at_local: string;
    ends_at_local: string;
  }[];
};

export type AttendanceSession = {
  id: string;
  state: string;
  source?: string;
  clock_in_at?: string | null;
  clock_out_at?: string | null;
  derived_status?: string | null;
  worked_minutes?: number | null;
  policy_snapshot?: AttendancePolicy | null;
};

export type SubscriptionDraft = {
  id: string;
  status: string;
  start_date: string;
  end_date: string;
  agreed_amount_minor: number;
  discount_minor?: number;
  currency: string;
  plan?: {
    id: string;
    name: string;
    duration_days: number;
    amount_minor_unit: number;
    joining_fee_minor: number;
    currency: string;
  };
};

export type FeeCard = Record<string, unknown> & {
  status?: string;
  member?: { id?: string; name?: string };
  subscription?: {
    id?: string;
    plan_name?: string;
    start_date?: string;
    end_date?: string;
  };
  amount_minor_unit?: number;
  balance_minor_unit?: number;
  charged_amount_minor_unit?: number;
  paid_amount_minor_unit?: number;
  waived_amount_minor_unit?: number;
  currency?: string;
};

export type PaymentRequest = Record<string, unknown> & {
  id: string;
  status: string;
  amount_minor_unit: number;
  currency: string;
};
