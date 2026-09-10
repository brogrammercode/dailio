import { z } from 'zod';

export const CreateOrganizationSchema = z.object({
  name: z.string().min(2).max(100),
  email: z.string().email().optional(),
  phone: z.string().optional(),
  address: z.string().optional(),
  type: z.enum(['GYM', 'COACHING', 'CLINIC', 'OTHER']).optional(),
  timezone: z.string().default('Asia/Kolkata'),
  currency: z.string().length(3).default('INR'),
  logo_base64: z.string().optional(),
  logo_url: z.string().url().optional(),
});

export const UpdateOrganizationSchema = CreateOrganizationSchema.partial();

export const CreateLocationSchema = z.object({
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

export type CreateOrganizationInput = z.infer<typeof CreateOrganizationSchema>;
export type UpdateOrganizationInput = z.infer<typeof UpdateOrganizationSchema>;
export type CreateLocationInput = z.infer<typeof CreateLocationSchema>;
