import { z } from 'zod';
import { extendZodWithOpenApi } from '@asteasolutions/zod-to-openapi';

extendZodWithOpenApi(z);

export const DiscoverLocationsQuerySchema = z.object({
  query: z
    .string()
    .optional()
    .openapi({ description: 'Search term for organization or location name' }),
  limit: z.coerce.number().min(1).max(50).default(20),
  cursor: z.string().optional(),
});

export type DiscoverLocationsQuery = z.infer<typeof DiscoverLocationsQuerySchema>;
