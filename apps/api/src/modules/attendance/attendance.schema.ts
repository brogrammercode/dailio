import { z } from 'zod';

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
    status: z.string().optional(),
  }),
});

export type ClockInInput = z.infer<typeof ClockInSchema>['body'];
export type ClockOutInput = z.infer<typeof ClockOutSchema>['body'];
export type ListSessionsQuery = z.infer<typeof ListSessionsQuerySchema>['query'];
