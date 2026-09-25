import { z } from 'zod';

export const CreateInviteSchema = z.object({
  expires_in_hours: z
    .number()
    .int()
    .min(1)
    .max(24 * 30)
    .default(24),
});

export const JoinInviteRequestSchema = z.object({
  message: z.string().trim().max(1000).optional(),
});

export const CreateSubscriptionDraftSchema = z.object({
  start_date: z.string().datetime(),
});

export type CreateInviteInput = z.infer<typeof CreateInviteSchema>;
export type JoinInviteRequestInput = z.infer<typeof JoinInviteRequestSchema>;
export type CreateSubscriptionDraftInput = z.infer<typeof CreateSubscriptionDraftSchema>;
