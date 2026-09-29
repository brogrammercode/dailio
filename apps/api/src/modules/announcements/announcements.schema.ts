import { z } from 'zod';

export const AnnouncementAudienceSchema = z.enum([
  'ALL_ACTIVE_MEMBERS',
  'SELECTED_ROLES',
  'SELECTED_MEMBERS',
]);
export const AnnouncementReactionSchema = z.enum([
  'LIKE',
  'LOVE',
  'CELEBRATE',
  'LAUGH',
  'SAD',
  'ANGRY',
]);

export const AnnouncementContentBlockSchema = z.object({
  type: z.enum(['paragraph', 'heading', 'quote', 'divider', 'image', 'slide']),
  text: z.string().max(10000).optional(),
  marks: z
    .array(z.enum(['bold', 'italic', 'underline', 'link']))
    .max(8)
    .optional(),
  storage_key: z.string().max(500).optional(),
  media_base64: z.string().max(12_000_000).optional(),
  media_filename: z.string().max(160).optional(),
  format: z
    .string()
    .regex(/^[a-z0-9]{2,8}$/i)
    .optional(),
  alt: z.string().max(240).optional(),
  href: z.string().url().max(2000).optional(),
  slide_index: z.number().int().min(0).max(100).optional(),
});

export const CreateAnnouncementSchema = z.object({
  branch_id: z.string().nullable().optional(),
  title: z.string().trim().min(1).max(160),
  body: z.string().trim().min(1).max(5000),
  content: z.array(AnnouncementContentBlockSchema).max(200).default([]),
  priority: z.number().int().min(0).max(100).optional(),
  audience: AnnouncementAudienceSchema.default('ALL_ACTIVE_MEMBERS'),
  role_ids: z.array(z.string()).max(100).default([]),
  member_ids: z.array(z.string()).max(1000).default([]),
  publish_at: z.string().datetime().nullable().optional(),
  expires_at: z.string().datetime().nullable().optional(),
});

export const UpdateAnnouncementSchema = CreateAnnouncementSchema.partial();

export const CreateAnnouncementCommentSchema = z.object({
  body: z.string().trim().min(1).max(2000),
  reply_to_id: z.string().min(1).optional(),
  idempotency_key: z.string().trim().min(8).max(200).optional(),
});

export const SetAnnouncementReactionSchema = z.object({ reaction: AnnouncementReactionSchema });
export const AnnouncementMediaSignatureSchema = z.object({
  filename: z.string().trim().min(1).max(160),
});
export const AnnouncementMediaUrlSchema = z.object({
  storage_key: z.string().trim().min(1).max(500),
  announcement_id: z.string().trim().min(1),
  format: z
    .string()
    .regex(/^[a-z0-9]{2,8}$/i)
    .optional(),
});

export type CreateAnnouncementInput = z.infer<typeof CreateAnnouncementSchema>;
export type UpdateAnnouncementInput = z.infer<typeof UpdateAnnouncementSchema>;
export type CreateAnnouncementCommentInput = z.infer<typeof CreateAnnouncementCommentSchema>;
export type SetAnnouncementReactionInput = z.infer<typeof SetAnnouncementReactionSchema>;
