import { prisma } from '../../lib/prisma';
import { NotFoundError } from '../../lib/errors';
import { cloudinary } from '../../lib/cloudinary';
import { permissionsForMember } from '../authorization/authorization.service';
import { retryPendingPushDeliveriesForUser } from '../notifications/notifications.service';

import type { RegisterDeviceTokenInput, UpdateProfileInput } from './users.schema';

export async function updateProfile(user_id: string, data: UpdateProfileInput) {
  const user = await prisma.user.findUnique({ where: { id: user_id } });
  if (!user) throw new NotFoundError('User');

  const updateData: Record<string, unknown> = {};
  if (data.name !== undefined) updateData.name = data.name;
  if (data.phone !== undefined) updateData.phone = data.phone;
  if (data.fcm_token !== undefined) updateData.fcm_token = data.fcm_token;
  if (data.emergency_contact_name !== undefined)
    updateData.emergency_contact_name = data.emergency_contact_name;
  if (data.emergency_contact_phone !== undefined)
    updateData.emergency_contact_phone = data.emergency_contact_phone;
  if (data.date_of_birth !== undefined) {
    updateData.date_of_birth = data.date_of_birth ? new Date(data.date_of_birth) : null;
  }

  if (data.avatar_base64) {
    const uploadResult = await cloudinary.uploader.upload(data.avatar_base64, {
      folder: 'avatars',
      public_id: user_id,
      overwrite: true,
      transformation: [{ width: 400, height: 400, crop: 'fill', gravity: 'face' }],
    });
    updateData.avatar_url = uploadResult.secure_url;
  }

  return prisma.$transaction(async (tx) => {
    const updated = await tx.user.update({ where: { id: user_id }, data: updateData });
    if (data.fcm_token) {
      await tx.userDeviceToken.upsert({
        where: { token: data.fcm_token },
        create: { user_id, token: data.fcm_token },
        update: { user_id, last_seen_at: new Date() },
      });
    }
    return updated;
  });
}

export async function removeDeviceToken(user_id: string, token: string) {
  await prisma.userDeviceToken.deleteMany({ where: { user_id, token } });
  await prisma.user.updateMany({
    where: { id: user_id, fcm_token: token },
    data: { fcm_token: null },
  });
}

export async function registerDeviceToken(user_id: string, data: RegisterDeviceTokenInput) {
  const updated = await prisma.$transaction(async (tx) => {
    const user = await tx.user.findUnique({ where: { id: user_id } });
    if (!user) throw new NotFoundError('User');

    // A device token belongs to the currently authenticated user. Clear the
    // legacy single-token field on a previous account before reassigning it.
    await tx.user.updateMany({
      where: { id: { not: user_id }, fcm_token: data.token },
      data: { fcm_token: null },
    });
    await tx.userDeviceToken.upsert({
      where: { token: data.token },
      create: {
        user_id,
        token: data.token,
        platform: data.platform,
        app_version: data.app_version,
        last_seen_at: new Date(),
      },
      update: {
        user_id,
        platform: data.platform,
        app_version: data.app_version,
        last_seen_at: new Date(),
      },
    });
    return tx.user.update({
      where: { id: user_id },
      data: { fcm_token: data.token },
    });
  });
  try {
    await retryPendingPushDeliveriesForUser(user_id);
  } catch {
    // Registration must succeed even if replaying a prior push is unavailable.
  }
  return updated;
}

export async function getUserContexts(user_id: string) {
  const now = new Date();
  const members = await prisma.member.findMany({
    where: { user_id, status: 'ACTIVE' },
    include: {
      organization: true,
      branch: true,
      role: { select: { system_key: true, permissions: true } },
      role_assignments: {
        where: {
          effective_from: { lte: now },
          OR: [{ effective_to: null }, { effective_to: { gt: now } }],
        },
        orderBy: [{ priority: 'asc' }, { effective_from: 'desc' }, { id: 'asc' }],
        select: {
          organization_id: true,
          branch_id: true,
          role: { select: { system_key: true, permissions: true } },
        },
      },
    },
  });
  return members.map((member) => ({
    ...member,
    effective_permissions: [
      ...permissionsForMember({
        ...member,
        role_assignments: member.role_assignments.filter(
          (assignment) =>
            assignment.organization_id === member.organization_id &&
            assignment.branch_id === member.branch_id,
        ),
      }),
    ],
  }));
}

export async function deleteAccount(user_id: string) {
  const user = await prisma.user.findUnique({ where: { id: user_id } });
  if (!user) throw new NotFoundError('User');

  // Anonymize the user record
  return prisma.$transaction(async (tx) => {
    await tx.userDeviceToken.deleteMany({ where: { user_id } });
    return tx.user.update({
      where: { id: user_id },
      data: {
        status: 'DISABLED',
        email: null,
        phone: null,
        google_id: null,
        name: 'Deleted User',
        avatar_url: null,
        fcm_token: null,
      },
    });
  });
}
