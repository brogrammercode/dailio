import { z } from 'zod';

export const CreateShiftSchema = z.object({
  body: z.object({
    branch_id: z.string().min(1),
    name: z.string().min(1),
    start_time: z.string().regex(/^([01]\d|2[0-3]):([0-5]\d)$/, 'Invalid time format HH:mm'),
    end_time: z.string().regex(/^([01]\d|2[0-3]):([0-5]\d)$/, 'Invalid time format HH:mm'),
    is_overnight: z.boolean().default(false),
    break_minutes: z.number().int().nonnegative().default(0),
    grace_in_min: z.number().int().nonnegative().default(0),
    grace_out_min: z.number().int().nonnegative().default(0),
    week_days: z.array(z.number().int().min(1).max(7)).default([1, 2, 3, 4, 5, 6, 7]),
  }),
});

export const UpdateShiftSchema = z.object({
  body: z.object({
    name: z.string().min(1).optional(),
    start_time: z.string().regex(/^([01]\d|2[0-3]):([0-5]\d)$/).optional(),
    end_time: z.string().regex(/^([01]\d|2[0-3]):([0-5]\d)$/).optional(),
    is_overnight: z.boolean().optional(),
    break_minutes: z.number().int().nonnegative().optional(),
    grace_in_min: z.number().int().nonnegative().optional(),
    grace_out_min: z.number().int().nonnegative().optional(),
    week_days: z.array(z.number().int().min(1).max(7)).optional(),
  }),
});

export type CreateShiftInput = z.infer<typeof CreateShiftSchema>['body'];
export type UpdateShiftInput = z.infer<typeof UpdateShiftSchema>['body'];
