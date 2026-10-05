import { z } from 'zod';

const localTime = z.string().regex(/^([01]\d|2[0-3]):[0-5]\d$/, 'Use HH:mm local time');

export const MealSlotInputSchema = z
  .object({
    code: z
      .string()
      .trim()
      .min(2)
      .max(32)
      .regex(/^[a-z0-9_-]+$/),
    name: z.string().trim().min(2).max(80),
    starts_at_local: localTime,
    ends_at_local: localTime,
    is_active: z.boolean().default(true),
  })
  .refine(
    (value) => value.starts_at_local !== value.ends_at_local,
    'A meal window must have a start and an end',
  );

export const MealEntitlementInputSchema = z.object({
  meal_slot_id: z.string().min(1),
  max_servings_per_day: z.number().int().min(1).max(10),
  is_active: z.boolean().default(true),
});

export const MealServeInputSchema = z.object({
  member_id: z.string().min(1),
  meal_slot_id: z.string().min(1),
});

export const MealVoidInputSchema = z.object({
  reason: z.string().trim().min(10).max(1000),
});

export const MealServingQuerySchema = z.object({
  member_id: z.string().optional(),
  from: z.string().date().optional(),
  to: z.string().date().optional(),
  page: z.coerce.number().int().positive().default(1),
  limit: z.coerce.number().int().positive().max(100).default(30),
});

export type MealSlotInput = z.infer<typeof MealSlotInputSchema>;
export type MealEntitlementInput = z.infer<typeof MealEntitlementInputSchema>;
export type MealServeInput = z.infer<typeof MealServeInputSchema>;
export type MealServingQuery = z.infer<typeof MealServingQuerySchema>;
