import { z } from 'zod';

export const CreateSalaryStructureSchema = z.object({
  name: z.string().min(1, 'Name is required'),
  amount: z.number().int().positive('Amount must be positive'),
  branch_id: z.string(),
});

export const UpdateSalaryStructureSchema = CreateSalaryStructureSchema.partial();
