import { z } from 'zod';

export const CreatePlanSchema = z.object({
  name: z.string().trim().min(1, 'Name is required').max(120),
  description: z.string().trim().max(2000).optional(),
  duration_days: z.number().int().positive('Duration must be positive'),
  amount_minor_unit: z.number().int().positive('Amount must be positive'),
  currency: z
    .string()
    .length(3)
    .transform((value) => value.toUpperCase())
    .default('INR'),
  joining_fee_minor: z.number().int().min(0).default(0),
  tax_percent: z.number().min(0).max(100).default(0),
  discount_percent: z.number().min(0).max(100).default(0),
  grace_days: z.number().int().min(0).default(0),
  is_active: z.boolean().default(true),
  branch_id: z.string().min(1).nullable().optional(),
  metadata: z.record(z.unknown()).optional(),
});

export const UpdatePlanSchema = CreatePlanSchema.partial();

export type CreatePlanInput = z.infer<typeof CreatePlanSchema>;
export type UpdatePlanInput = z.infer<typeof UpdatePlanSchema>;
