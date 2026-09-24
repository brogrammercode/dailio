import { z } from 'zod';

export const UpdatePolicySchema = z.object({
  body: z.object({
    punch_required: z.boolean().optional(),
    selfie_on_clock_in: z.boolean().optional(),
    selfie_on_clock_out: z.boolean().optional(),
    location_on_clock_in: z.boolean().optional(),
    location_on_clock_out: z.boolean().optional(),
    geofence_enabled: z.boolean().optional(),
    geofence_lat: z.number().nullable().optional(),
    geofence_lng: z.number().nullable().optional(),
    geofence_radius_meters: z.number().nullable().optional(),
    geofence_accuracy_threshold: z.number().nullable().optional(),
    shift_enforcement_enabled: z.boolean().optional(),
    early_arrival_minutes: z.number().optional(),
    late_grace_minutes: z.number().optional(),
    min_session_minutes: z.number().optional(),
    max_open_session_hours: z.number().optional(),
    allow_manual_entry: z.boolean().optional(),
    allow_offline_capture: z.boolean().optional(),
  }),
});

export type UpdatePolicyInput = z.infer<typeof UpdatePolicySchema>['body'];

export const ClockInSchema = z.object({
  body: z.object({
    idempotency_key: z.string().optional(),
    client_time: z.string().datetime().optional(),
    timezone: z.string().default('UTC'),
    latitude: z.number().optional(),
    longitude: z.number().optional(),
    accuracy: z.number().optional(),
    device_info: z.record(z.unknown()).optional(),
  }),
});

export const ClockOutSchema = z.object({
  body: z.object({
    session_id: z.string().min(1),
    idempotency_key: z.string().optional(),
    client_time: z.string().datetime().optional(),
    timezone: z.string().default('UTC'),
    latitude: z.number().optional(),
    longitude: z.number().optional(),
    accuracy: z.number().optional(),
  }),
});

export const ListSessionsQuerySchema = z.object({
  query: z.object({
    period: z.enum(['today', 'yesterday', 'this_week', 'this_month']).default('today'),
    member_id: z.string().optional(),
    role_id: z.string().optional(),
    status: z.string().optional(),
  }),
});

export type ClockInInput = z.infer<typeof ClockInSchema>['body'];
export type ClockOutInput = z.infer<typeof ClockOutSchema>['body'];
export type ListSessionsQuery = z.infer<typeof ListSessionsQuerySchema>['query'];

export const CorrectSessionSchema = z.object({
  body: z.object({
    clock_in_at: z.string().datetime().optional(),
    clock_out_at: z.string().datetime().optional(),
    correction_reason: z.string().min(5),
    derived_status: z.enum(['PRESENT', 'LATE', 'LEFT_EARLY', 'HALF_DAY', 'ABSENT', 'ON_LEAVE', 'HOLIDAY', 'WEEK_OFF', 'INCOMPLETE', 'MANUAL', 'VOID']).optional(),
  }),
});

export type CorrectSessionInput = z.infer<typeof CorrectSessionSchema>['body'];

