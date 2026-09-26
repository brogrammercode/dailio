import { z } from 'zod';

export const CreateInviteSchema = z.object({}).strict();

export const JoinInviteRequestSchema = z.object({
  message: z.string().trim().max(1000).optional(),
});

export const CreateSubscriptionDraftSchema = z.object({
  start_date: z.string().datetime(),
});

export const CreateDirectSubscriptionDraftSchema = z.object({
  start_date: z.string().datetime(),
});

export type CreateInviteInput = z.infer<typeof CreateInviteSchema>;
export type JoinInviteRequestInput = z.infer<typeof JoinInviteRequestSchema>;
export type CreateSubscriptionDraftInput = z.infer<typeof CreateSubscriptionDraftSchema>;
export type CreateDirectSubscriptionDraftInput = z.infer<
  typeof CreateDirectSubscriptionDraftSchema
>;
