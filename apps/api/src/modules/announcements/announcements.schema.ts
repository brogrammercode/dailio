import { z } from 'zod';

export const AnnouncementAudienceSchema = z.enum(['ALL_ACTIVE_MEMBERS', 'SELECTED_ROLES', 'SELECTED_MEMBERS']);

export const CreateAnnouncementSchema = z.object({
  branch_id: z.string().nullable().optional(),
  title: z.string().trim().min(1).max(160),
  body: z.string().trim().min(1).max(5000),
  priority: z.number().int().min(0).max(100).optional(),
  audience: AnnouncementAudienceSchema.default('ALL_ACTIVE_MEMBERS'),
  role_ids: z.array(z.string()).max(100).default([]),
  member_ids: z.array(z.string()).max(1000).default([]),
  publish_at: z.string().datetime().nullable().optional(),
  expires_at: z.string().datetime().nullable().optional(),
});

export const UpdateAnnouncementSchema = CreateAnnouncementSchema.partial();

export type CreateAnnouncementInput = z.infer<typeof CreateAnnouncementSchema>;
export type UpdateAnnouncementInput = z.infer<typeof UpdateAnnouncementSchema>;
