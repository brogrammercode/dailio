import { ulid } from 'ulid';
import { z } from 'zod';

import { imageUploadTransformation } from '../../lib/image-upload-policy';
import { prisma } from '../../lib/prisma';
import { cloudinary } from '../../lib/cloudinary';
import { ForbiddenError, NotFoundError } from '../../lib/errors';
import { permissionsForMember } from '../authorization/authorization.service';

export const MemberProfileSchema = z
  .object({
    name: z.string().trim().min(1).max(200).optional(),
    phone: z.string().trim().max(40).optional(),
    avatar_base64: z
      .string()
      .max(7_000_000)
      .regex(/^data:image\/(png|jpeg);base64,[A-Za-z0-9+/=]+$/)
      .optional(),
  })
  .strict()
  .refine((data) => Object.keys(data).length > 0, 'Provide at least one profile field');

export async function updateOrganizationMemberProfile(
  actorId: string,
  organizationId: string,
  branchId: string,
  memberId: string,
  data: z.infer<typeof MemberProfileSchema>,
) {
  // Authorize independently of route visibility and reject role-assignment-only access.
  const actor = await prisma.member.findFirst({
    where: {
      user_id: actorId,
      organization_id: organizationId,
      branch_id: branchId,
      status: 'ACTIVE',
    },
    include: {
      role: true,
      role_assignments: {
        where: {
          organization_id: organizationId,
          branch_id: branchId,
          effective_from: { lte: new Date() },
          OR: [{ effective_to: null }, { effective_to: { gt: new Date() } }],
        },
        include: { role: true },
      },
    },
  });
  const permissions = actor ? permissionsForMember(actor) : new Set<string>();
  if (!permissions.has('ALL') && !permissions.has('ORG_UPDATE')) {
    throw new ForbiddenError('Organization profile editing is not permitted');
  }
  if (
    !permissions.has('ALL') &&
    !permissions.has('MEMBER_UPDATE_BRANCH') &&
    !permissions.has('MEMBER_UPDATE_ALL') &&
    !permissions.has('MEMBER_UPDATE')
  ) {
    throw new ForbiddenError('Member profile editing is not permitted');
  }
  const member = await prisma.member.findFirst({
    where: { id: memberId, organization_id: organizationId, branch_id: branchId },
    select: { user_id: true },
  });
  if (!member) throw new NotFoundError('Member');
  let avatarUrl: string | undefined;
  if (data.avatar_base64) {
    const upload = await cloudinary.uploader.upload(data.avatar_base64, {
      folder: `organizations/${organizationId}/member-profiles/${member.user_id}`,
      public_id: ulid(),
      overwrite: false,
      transformation: [
        { ...imageUploadTransformation, width: 400, height: 400, crop: 'fill', gravity: 'face' },
      ],
    });
    avatarUrl = upload.secure_url;
  }
  const changes = { name: data.name, phone: data.phone, avatar_url: avatarUrl };
  return prisma.$transaction(async (tx) => {
    const target = await tx.member.findFirst({
      where: {
        id: memberId,
        organization_id: organizationId,
        branch_id: branchId,
        user_id: member.user_id,
      },
    });
    if (!target) throw new NotFoundError('Member');
    const profile = await tx.organizationMemberProfile.upsert({
      where: {
        organization_id_user_id: { organization_id: organizationId, user_id: member.user_id },
      },
      create: { organization_id: organizationId, user_id: member.user_id, ...changes },
      update: changes,
    });
    await tx.auditLog.create({
      data: {
        id: ulid(),
        organization_id: organizationId,
        branch_id: branchId,
        actor_id: actorId,
        action: 'UPDATE',
        target_type: 'OrganizationMemberProfile',
        target_id: memberId,
        after_state: {
          fields: Object.keys(changes).filter(
            (key) => changes[key as keyof typeof changes] !== undefined,
          ),
        },
      },
    });
    return profile;
  });
}

export async function withOrganizationProfiles<
  T extends {
    user_id: string;
    user: { name: string; phone: string | null; avatar_url: string | null };
  },
>(organizationId: string, members: T[]): Promise<T[]> {
  if (!members.length) return members;
  const profiles = await prisma.organizationMemberProfile.findMany({
    where: {
      organization_id: organizationId,
      user_id: { in: members.map((member) => member.user_id) },
    },
  });
  return members.map((member) => {
    const profile = profiles.find((item) => item.user_id === member.user_id);
    return profile
      ? {
          ...member,
          user: {
            ...member.user,
            name: profile.name ?? member.user.name,
            phone: profile.phone ?? member.user.phone,
            avatar_url: profile.avatar_url ?? member.user.avatar_url,
          },
        }
      : member;
  });
}
