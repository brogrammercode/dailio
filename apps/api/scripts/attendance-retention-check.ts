/* eslint-disable no-console */
import { ulid } from 'ulid';

import { env } from '../src/config/env';
import { cloudinary } from '../src/lib/cloudinary';
import { prisma } from '../src/lib/prisma';
import { purgeExpiredAttendanceEvidence } from '../src/modules/attendance/attendance.service';

if (process.env.RUN_ATTENDANCE_RETENTION_CHECK !== 'true') {
  throw new Error(
    'Refusing to run. Set RUN_ATTENDANCE_RETENTION_CHECK=true against a disposable staging database and storage account.',
  );
}

if (!env.CLOUDINARY_CLOUD_NAME || !env.CLOUDINARY_API_KEY || !env.CLOUDINARY_API_SECRET) {
  throw new Error('Cloudinary credentials are required for the retention check.');
}

const ids = {
  organization: `att_retention_org_${ulid()}`,
  branch: `att_retention_branch_${ulid()}`,
  user: `att_retention_user_${ulid()}`,
  member: `att_retention_member_${ulid()}`,
  session: `att_retention_session_${ulid()}`,
  evidence: `att_retention_evidence_${ulid()}`,
  asset: `att_retention_asset_${ulid()}`,
};
const storageKey = `organizations/${ids.organization}/branches/${ids.branch}/attendance-selfies/${ids.asset}`;
let uploaded = false;

async function cleanup() {
  if (uploaded) {
    try {
      await cloudinary.uploader.destroy(storageKey, {
        resource_type: 'image',
        type: 'authenticated',
        invalidate: true,
      });
    } catch {
      // The retention check may already have deleted the object.
    }
  }

  await prisma.attendanceEvidence.deleteMany({ where: { id: ids.evidence } });
  await prisma.mediaAsset.deleteMany({ where: { id: ids.asset } });
  await prisma.attendanceSession.deleteMany({ where: { id: ids.session } });
  await prisma.member.deleteMany({ where: { id: ids.member } });
  await prisma.branch.deleteMany({ where: { id: ids.branch } });
  await prisma.organization.deleteMany({ where: { id: ids.organization } });
  await prisma.user.deleteMany({ where: { id: ids.user } });
}

async function assertStorageObjectDeleted() {
  for (let attempt = 0; attempt < 5; attempt += 1) {
    try {
      await cloudinary.api.resource(storageKey, {
        resource_type: 'image',
        type: 'authenticated',
      });
    } catch {
      return;
    }
    await new Promise((resolve) => setTimeout(resolve, 500));
  }
  throw new Error('Retention job returned without deleting the private storage object');
}

async function main() {
  const oldDate = new Date(
    Date.now() - (env.ATTENDANCE_EVIDENCE_RETENTION_DAYS + 1) * 24 * 60 * 60 * 1000,
  );

  await prisma.organization.create({
    data: {
      id: ids.organization,
      name: `Attendance retention ${ulid()}`,
      slug: `attendance-retention-${ulid().toLowerCase()}`,
      type: 'GYM',
      status: 'ACTIVE',
      timezone: 'UTC',
      currency: 'INR',
    },
  });
  await prisma.branch.create({
    data: {
      id: ids.branch,
      organization_id: ids.organization,
      name: 'Attendance Retention Branch',
      timezone: 'UTC',
      status: 'ACTIVE',
    },
  });
  await prisma.user.create({
    data: {
      id: ids.user,
      name: 'Attendance Retention Test User',
      email: `${ulid().toLowerCase()}@invalid.test`,
      status: 'ACTIVE',
    },
  });
  await prisma.member.create({
    data: {
      id: ids.member,
      user_id: ids.user,
      organization_id: ids.organization,
      branch_id: ids.branch,
      status: 'ACTIVE',
    },
  });

  const imageData =
    'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=';
  await cloudinary.uploader.upload(imageData, {
    resource_type: 'image',
    type: 'authenticated',
    public_id: storageKey,
    overwrite: true,
  });
  uploaded = true;

  await prisma.attendanceSession.create({
    data: {
      id: ids.session,
      organization_id: ids.organization,
      branch_id: ids.branch,
      member_id: ids.member,
      policy_version: 1,
      state: 'CLOSED',
      source: 'SELF',
      clock_in_at: oldDate,
      clock_out_at: new Date(oldDate.getTime() + 60 * 60 * 1000),
      created_at: oldDate,
      updated_at: oldDate,
    },
  });
  await prisma.mediaAsset.create({
    data: {
      id: ids.asset,
      organization_id: ids.organization,
      owner_type: 'ATTENDANCE_SELFIE',
      owner_id: ids.session,
      storage_key: storageKey,
      content_type: 'image/png',
      size_bytes: 68,
      uploaded_by: ids.user,
      created_at: oldDate,
    },
  });
  await prisma.attendanceEvidence.create({
    data: {
      id: ids.evidence,
      session_id: ids.session,
      organization_id: ids.organization,
      type: 'SELFIE_IN',
      asset_id: ids.asset,
      latitude: 28.61,
      longitude: 77.21,
      accuracy: 4,
      device_metadata: { test: true },
      ip_address: '192.0.2.1',
      created_at: oldDate,
    },
  });

  const result = await purgeExpiredAttendanceEvidence(10);
  const evidence = await prisma.attendanceEvidence.findUnique({ where: { id: ids.evidence } });
  const asset = await prisma.mediaAsset.findUnique({ where: { id: ids.asset } });
  if (
    result.purged !== 1 ||
    evidence?.latitude !== null ||
    evidence.longitude !== null ||
    evidence.device_metadata !== null ||
    evidence.ip_address !== null ||
    evidence.asset_id !== null ||
    asset !== null
  ) {
    throw new Error(
      'Retention job did not purge sensitive fields and the database asset reference',
    );
  }
  await assertStorageObjectDeleted();

  console.log('Attendance retention check passed', {
    scanned: result.scanned,
    purged: result.purged,
    storage: 'private object deleted',
  });
}

main()
  .catch((error) => {
    console.error(error);
    process.exitCode = 1;
  })
  .finally(async () => {
    try {
      await cleanup();
    } finally {
      await prisma.$disconnect();
    }
  });
