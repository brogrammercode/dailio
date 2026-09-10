import { z } from 'zod';

export const DiscoverBranchesQuerySchema = z.object({
  query: z.string().optional(),
  limit: z.coerce.number().min(1).max(50).default(20),
  cursor: z.string().optional(),
});

export type DiscoverBranchesQuery = z.infer<typeof DiscoverBranchesQuerySchema>;
