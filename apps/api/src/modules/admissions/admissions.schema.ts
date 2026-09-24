import { z } from 'zod';
import { extendZodWithOpenApi } from '@asteasolutions/zod-to-openapi';

extendZodWithOpenApi(z);

export const CreateJoinRequestSchema = z.object({
  body: z.object({
    message: z.string().optional(),
    emergency_contact_name: z.string().optional(),
    emergency_contact_phone: z.string().optional(),
    date_of_birth: z.string().optional(), // ISO date string
    avatar_url: z.string().optional(),
  }),
});

export const JoinRequestActionSchema = z.object({
  body: z.object({
    reason: z.string().optional(),
  }),
});

export type CreateJoinRequestInput = z.infer<typeof CreateJoinRequestSchema>['body'];
export type JoinRequestActionInput = z.infer<typeof JoinRequestActionSchema>['body'];
