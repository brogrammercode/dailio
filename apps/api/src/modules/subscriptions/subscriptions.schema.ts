import { z } from 'zod';

export const AssignSubscriptionSchema = z.object({
  plan_id: z.string().min(1, 'Invalid Plan ID'),
  start_date: z.string().datetime(),
  agreed_amount_minor: z.number().int().positive().optional(),
  discount_minor: z.number().int().min(0).optional(),
});

export type AssignSubscriptionInput = z.infer<typeof AssignSubscriptionSchema>;

export const UpdateSubscriptionSchema = z.object({
  end_date: z.string().datetime().optional(),
});

export type UpdateSubscriptionInput = z.infer<typeof UpdateSubscriptionSchema>;

export const CancelSubscriptionSchema = z.object({ reason: z.string().trim().min(1).max(1000) });
export type CancelSubscriptionInput = z.infer<typeof CancelSubscriptionSchema>;

export const SubscriptionTransitionSchema = z.object({
  reason: z.string().trim().min(1).max(1000),
});
export type SubscriptionTransitionInput = z.infer<typeof SubscriptionTransitionSchema>;

export const RenewSubscriptionSchema = z.object({
  start_date: z.string().datetime(),
});
export type RenewSubscriptionInput = z.infer<typeof RenewSubscriptionSchema>;
