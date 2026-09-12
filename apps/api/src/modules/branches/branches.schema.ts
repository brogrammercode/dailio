import { z } from 'zod';

export const DiscoverBranchesQuerySchema = z.object({
  query: z.string().optional(),
  limit: z.coerce.number().min(1).max(50).default(20),
  cursor: z.string().optional(),
});

export type DiscoverBranchesQuery = z.infer<typeof DiscoverBranchesQuerySchema>;

export const CreateBranchSchema = z.object({
  name: z.string().min(2).max(100),
  address: z.string().optional(),
  city: z.string().optional(),
  state: z.string().optional(),
  country: z.string().default('IN'),
  postal_code: z.string().optional(),
  latitude: z.number().optional(),
  longitude: z.number().optional(),
  phone: z.string().optional(),
  email: z.string().email().optional(),
  timezone: z.string().default('Asia/Kolkata'),
});

export const UpdateBranchSchema = CreateBranchSchema.partial().extend({
  status: z.enum(['ACTIVE', 'ARCHIVED']).optional(),
});

export type CreateBranchInput = z.infer<typeof CreateBranchSchema>;
export type UpdateBranchInput = z.infer<typeof UpdateBranchSchema>;

