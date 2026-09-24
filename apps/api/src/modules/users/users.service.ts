import { prisma } from '../../lib/prisma';
import { NotFoundError } from '../../lib/errors';
import { cloudinary } from '../../lib/cloudinary';

import type { UpdateProfileInput } from './users.schema';

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

  return prisma.user.update({ where: { id: user_id }, data: updateData });
}

export async function getUserContexts(user_id: string) {
  const members = await prisma.member.findMany({
    where: { user_id, status: 'ACTIVE' },
    include: {
      organization: true,
      branch: true,
    },
  });
  return members;
}

export async function deleteAccount(user_id: string) {
  const user = await prisma.user.findUnique({ where: { id: user_id } });
  if (!user) throw new NotFoundError('User');

  // Anonymize the user record
  return prisma.user.update({
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
}
