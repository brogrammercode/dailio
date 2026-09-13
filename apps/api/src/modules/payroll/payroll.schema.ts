import { z } from 'zod';

export const CreateSalaryStructureSchema = z.object({
  name: z.string().min(1, 'Name is required'),
  amount: z.number().int().nonnegative('Amount must be positive').default(0).optional(),
  branch_id: z.string().nullable().optional(),
  earnings: z.array(z.object({
    label: z.string(),
    amount: z.number().int().nonnegative()
  })).default([]).optional(),
  deductions: z.array(z.object({
    label: z.string(),
    amount: z.number().int().nonnegative()
  })).default([]).optional(),
});

export const UpdateSalaryStructureSchema = CreateSalaryStructureSchema.partial();
