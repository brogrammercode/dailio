import { z } from 'zod';

export const ListMembersQuerySchema = z.object({
  query: z.object({
    search: z.string().optional(),
    status: z.enum(['ACTIVE', 'SUSPENDED', 'INACTIVE']).optional(),
    role_id: z.string().optional(),
    page: z.coerce.number().int().positive().default(1),
    limit: z.coerce.number().int().positive().max(100).default(20),
  }),
});

export const AssistedAdmissionSchema = z.object({
  body: z.object({
    first_name: z.string().min(1),
    last_name: z.string().optional(),
    email: z.string().email().optional(),
    phone: z.string().optional(),
  }),
});

export const MemberActionSchema = z.object({
  body: z.object({
    reason: z.string().min(1),
  }),
});

export type ListMembersQuery = z.infer<typeof ListMembersQuerySchema>['query'];
export type AssistedAdmissionInput = z.infer<typeof AssistedAdmissionSchema>['body'];
export type MemberActionInput = z.infer<typeof MemberActionSchema>['body'];
export const UpdateMemberSchema = z.object({
  body: z.object({
    role_id: z.string().nullable().optional(),
    is_geofence_exempt: z.boolean().optional(),
    is_selfie_mandatory: z.boolean().optional(),
    is_multi_branch: z.boolean().optional(),
  }),
});

export type UpdateMemberInput = z.infer<typeof UpdateMemberSchema>['body'];
