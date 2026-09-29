import { z } from 'zod';

export const FeedReactionSchema = z.enum(['LIKE', 'LOVE', 'CELEBRATE', 'LAUGH', 'SAD', 'ANGRY']);

export const CreateFeedSchema = z.object({
  name: z.string().trim().min(1).max(120),
  member_ids: z.array(z.string().min(1)).max(1000).default([]),
  participants_can_post: z.boolean().default(false),
  post_timeout: z.number().int().min(1).max(43200).nullable().optional(),
  report_threshold: z.number().int().min(1).max(100).default(3),
});

export const UpdateFeedSchema = z.object({
  name: z.string().trim().min(1).max(120).optional(),
  participants_can_post: z.boolean().optional(),
  post_timeout: z.number().int().min(1).max(43200).nullable().optional(),
  report_threshold: z.number().int().min(1).max(100).optional(),
});

export const AddFeedParticipantSchema = z.object({ member_id: z.string().min(1) });

export const FeedContentBlockSchema = z.object({
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

export const CreateFeedPostSchema = z.object({
  title: z.string().trim().min(1).max(160),
  body: z.string().trim().min(1).max(10000),
  content: z.array(FeedContentBlockSchema).max(200).default([]),
  idempotency_key: z.string().trim().min(8).max(200).optional(),
});

export const FeedMediaSignatureSchema = z.object({
  filename: z.string().trim().min(1).max(160),
});

export const FeedMediaUrlSchema = z.object({
  storage_key: z.string().trim().min(1).max(500),
  feed_id: z.string().trim().min(1),
  post_id: z.string().trim().min(1),
  format: z
    .string()
    .regex(/^[a-z0-9]{2,8}$/i)
    .optional(),
});

export const UpdateFeedPostSchema = z.object({
  title: z.string().trim().min(1).max(160).optional(),
  body: z.string().trim().min(1).max(10000).optional(),
  content: z.array(FeedContentBlockSchema).max(200).optional(),
});

export const SetFeedReactionSchema = z.object({ reaction: FeedReactionSchema });

export const CreateFeedCommentSchema = z.object({
  body: z.string().trim().min(1).max(2000),
  reply_to_id: z.string().min(1).optional(),
  idempotency_key: z.string().trim().min(8).max(200).optional(),
});

export const CreateFeedReportSchema = z.object({
  reason: z.string().trim().min(1).max(1000),
});

export type CreateFeedInput = z.infer<typeof CreateFeedSchema>;
export type UpdateFeedInput = z.infer<typeof UpdateFeedSchema>;
export type CreateFeedPostInput = z.infer<typeof CreateFeedPostSchema>;
export type UpdateFeedPostInput = z.infer<typeof UpdateFeedPostSchema>;
export type SetFeedReactionInput = z.infer<typeof SetFeedReactionSchema>;
export type CreateFeedCommentInput = z.infer<typeof CreateFeedCommentSchema>;
