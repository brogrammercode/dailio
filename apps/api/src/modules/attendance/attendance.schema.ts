import { z } from 'zod';

export const AttendanceEvidenceUploadSchema = z.object({
  filename: z.string().trim().min(1).max(200),
  content_type: z.enum(['image/jpeg', 'image/png', 'image/webp']),
});

export const UpdatePolicySchema = z.object({
  body: z.object({
    role_id: z.string().nullable().optional(),
    member_id: z.string().nullable().optional(),
    effective_from: z.string().datetime().optional(),
    punch_required: z.boolean().optional(),
    selfie_on_clock_in: z.boolean().optional(),
    selfie_on_clock_out: z.boolean().optional(),
    location_on_clock_in: z.boolean().optional(),
    location_on_clock_out: z.boolean().optional(),
    geofence_enabled: z.boolean().optional(),
    geofence_lat: z.number().min(-90).max(90).nullable().optional(),
    geofence_lng: z.number().min(-180).max(180).nullable().optional(),
    geofence_radius_meters: z.number().int().positive().max(100_000).nullable().optional(),
    geofence_accuracy_threshold: z.number().positive().max(10_000).nullable().optional(),
    shift_enforcement_enabled: z.boolean().optional(),
    early_arrival_minutes: z.number().int().min(0).max(1_440).optional(),
    late_grace_minutes: z.number().int().min(0).max(1_440).optional(),
    min_session_minutes: z.number().int().min(0).max(1_440).optional(),
    max_open_session_hours: z.number().int().min(0).max(720).optional(),
    allow_manual_entry: z.boolean().optional(),
    // Offline attendance remains disabled by product decision until a
    // tamper-evident sync flow is implemented.
    allow_offline_capture: z.literal(false).optional(),
  }),
});

export type UpdatePolicyInput = z.infer<typeof UpdatePolicySchema>['body'];

export const ClockInSchema = z.object({
  body: z.object({
    idempotency_key: z.string().min(8),
    policy_version: z.number().int().positive().optional(),
    client_time: z.string().datetime().optional(),
    timezone: z.string().default('UTC'),
    latitude: z.number().min(-90).max(90).optional(),
    longitude: z.number().min(-180).max(180).optional(),
    accuracy: z.number().nonnegative().max(10_000).optional(),
    device_info: z.record(z.unknown()).optional(),
    selfie_storage_key: z.string().trim().max(500).optional(),
    selfie_upload_token: z.string().trim().max(2_000).optional(),
    selfie_content_type: z.enum(['image/jpeg', 'image/png', 'image/webp']).optional(),
    selfie_size_bytes: z.number().int().positive().max(20_000_000).optional(),
  }),
});

export const ClockOutSchema = z.object({
  body: z.object({
    session_id: z.string().min(1),
    idempotency_key: z.string().min(8),
    policy_version: z.number().int().positive().optional(),
    client_time: z.string().datetime().optional(),
    timezone: z.string().default('UTC'),
    latitude: z.number().min(-90).max(90).optional(),
    longitude: z.number().min(-180).max(180).optional(),
    accuracy: z.number().nonnegative().max(10_000).optional(),
    selfie_storage_key: z.string().trim().max(500).optional(),
    selfie_upload_token: z.string().trim().max(2_000).optional(),
    selfie_content_type: z.enum(['image/jpeg', 'image/png', 'image/webp']).optional(),
    selfie_size_bytes: z.number().int().positive().max(20_000_000).optional(),
  }),
});

export const ListSessionsQuerySchema = z.object({
  query: z
    .object({
      period: z
        .enum(['today', 'yesterday', 'this_week', 'this_month', 'this_year', 'custom'])
        .default('today'),
      date_from: z
        .string()
        .regex(/^\d{4}-\d{2}-\d{2}$/)
        .optional(),
      date_to: z
        .string()
        .regex(/^\d{4}-\d{2}-\d{2}$/)
        .optional(),
      member_id: z.string().optional(),
      role_id: z.string().optional(),
      status: z.string().optional(),
      limit: z.coerce.number().int().min(1).max(100).default(50),
      cursor: z.string().min(1).optional(),
    })
    .superRefine((query, context) => {
      if (query.period === 'custom' && (!query.date_from || !query.date_to)) {
        context.addIssue({
          code: z.ZodIssueCode.custom,
          path: ['date_from'],
          message: 'Custom attendance periods require date_from and date_to',
        });
      }
      if (query.date_from && query.date_to && query.date_to < query.date_from) {
        context.addIssue({
          code: z.ZodIssueCode.custom,
          path: ['date_to'],
          message: 'date_to must be on or after date_from',
        });
      }
    }),
});

export type ClockInInput = z.infer<typeof ClockInSchema>['body'];
export type ClockOutInput = z.infer<typeof ClockOutSchema>['body'];
export type ListSessionsQuery = z.infer<typeof ListSessionsQuerySchema>['query'];

export const CreateManualSessionSchema = z.object({
  body: z
    .object({
      member_id: z.string().min(1),
      clock_in_at: z.string().datetime(),
      clock_out_at: z.string().datetime().optional(),
      policy_version: z.number().int().positive().optional(),
      reason: z.string().trim().min(5).max(1_000),
    })
    .superRefine((body, context) => {
      if (body.clock_out_at && new Date(body.clock_out_at) < new Date(body.clock_in_at)) {
        context.addIssue({
          code: z.ZodIssueCode.custom,
          path: ['clock_out_at'],
          message: 'Clock-out must be after clock-in',
        });
      }
    }),
});

export type CreateManualSessionInput = z.infer<typeof CreateManualSessionSchema>['body'];

export const CorrectSessionSchema = z.object({
  body: z
    .object({
      clock_in_at: z.string().datetime().optional(),
      clock_out_at: z.string().datetime().optional(),
      correction_reason: z.string().trim().min(5).max(1000),
      derived_status: z
        .enum([
          'PRESENT',
          'LATE',
          'LEFT_EARLY',
          'HALF_DAY',
          'ABSENT',
          'ON_LEAVE',
          'HOLIDAY',
          'WEEK_OFF',
          'INCOMPLETE',
          'MANUAL',
          'VOID',
        ])
        .optional(),
    })
    .superRefine((body, context) => {
      if (!body.clock_in_at && !body.clock_out_at && !body.derived_status) {
        context.addIssue({
          code: z.ZodIssueCode.custom,
          path: [],
          message: 'At least one attendance value must be corrected',
        });
      }
      if (body.clock_in_at && body.clock_out_at) {
        const clockIn = new Date(body.clock_in_at).getTime();
        const clockOut = new Date(body.clock_out_at).getTime();
        if (clockOut < clockIn) {
          context.addIssue({
            code: z.ZodIssueCode.custom,
            path: ['clock_out_at'],
            message: 'Clock-out must be after clock-in',
          });
        }
      }
    }),
});

export type CorrectSessionInput = z.infer<typeof CorrectSessionSchema>['body'];

export const QrPunchSchema = z.object({
  body: z.object({
    token: z.string().min(20),
    policy_version: z.number().int().positive().optional(),
    client_time: z.string().datetime().optional(),
    timezone: z.string().default('UTC'),
    latitude: z.number().min(-90).max(90).optional(),
    longitude: z.number().min(-180).max(180).optional(),
    accuracy: z.number().nonnegative().max(10_000).optional(),
    device_info: z.record(z.unknown()).optional(),
    selfie_storage_key: z.string().trim().max(500).optional(),
    selfie_upload_token: z.string().trim().max(2_000).optional(),
    selfie_content_type: z.enum(['image/jpeg', 'image/png', 'image/webp']).optional(),
    selfie_size_bytes: z.number().int().positive().max(20_000_000).optional(),
  }),
});

export type QrPunchInput = z.infer<typeof QrPunchSchema>['body'];
