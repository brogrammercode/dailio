import { z } from 'zod';

const isoDate = z.string().regex(/^\d{4}-\d{2}-\d{2}$/, 'Use YYYY-MM-DD dates');

export const CreateLeaveRequestSchema = z.object({
  start_date: isoDate,
  end_date: isoDate,
  reason: z.string().trim().max(1000).optional(),
  idempotency_key: z.string().trim().min(8).max(200).optional(),
});

export const LeaveActionSchema = z.object({ review_note: z.string().trim().max(1000).optional() });

export type CreateLeaveRequestInput = z.infer<typeof CreateLeaveRequestSchema>;
export type LeaveActionInput = z.infer<typeof LeaveActionSchema>;
