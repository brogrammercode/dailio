import { z } from 'zod';

export const CreatePlanSchema = z.object({
  name: z.string().min(1, 'Name is required'),
  description: z.string().optional(),
  duration_days: z.number().int().positive('Duration must be positive'),
  amount_minor_unit: z.number().int().min(0, 'Amount cannot be negative'),
  currency: z.string().length(3).default('INR'),
  joining_fee_minor: z.number().int().min(0).default(0),
  tax_percent: z.number().min(0).max(100).default(0),
  discount_percent: z.number().min(0).max(100).default(0),
  grace_days: z.number().int().min(0).default(0),
  is_active: z.boolean().default(true),
  branch_id: z.string(),
});

export const UpdatePlanSchema = CreatePlanSchema.partial();

