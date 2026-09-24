import { z } from 'zod';

export const UpdateProfileSchema = z.object({
  name: z.string().min(1).max(100).optional(),
  phone: z.string().optional(),
  emergency_contact_name: z.string().optional(),
  emergency_contact_phone: z.string().optional(),
  date_of_birth: z.string().optional(), // ISO format
  avatar_base64: z.string().optional(),
  fcm_token: z.string().optional(),
});

export type UpdateProfileInput = z.infer<typeof UpdateProfileSchema>;
