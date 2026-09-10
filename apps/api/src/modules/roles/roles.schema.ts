import { z } from 'zod';

export const CreateRoleSchema = z.object({
  organization_id: z.string(),
  name: z.string().min(1, 'Name is required'),
  permissions: z.array(z.string()).default([]),
});

export const UpdateRoleSchema = z.object({
  name: z.string().min(1, 'Name cannot be empty').optional(),
  permissions: z.array(z.string()).optional(),
});

export type CreateRoleInput = z.infer<typeof CreateRoleSchema>;
export type UpdateRoleInput = z.infer<typeof UpdateRoleSchema>;
