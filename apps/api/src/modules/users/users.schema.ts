import { z } from 'zod';

export const UpdateProfileSchema = z.object({
  name: z.string().min(1).max(100).optional(),
  phone: z.string().optional(),
  avatar_base64: z.string().optional(),
});

export type UpdateProfileInput = z.infer<typeof UpdateProfileSchema>;
