import { beforeEach, describe, expect, it, vi } from 'vitest';

const prismaMock = vi.hoisted(() => ({
  attendanceEvidence: { findMany: vi.fn() },
  $transaction: vi.fn(),
}));

const cloudinaryMock = vi.hoisted(() => ({
  uploader: { destroy: vi.fn() },
}));
const mediaAssetDeleteMany = vi.hoisted(() => vi.fn());

vi.mock('../../lib/prisma', () => ({ prisma: prismaMock }));
vi.mock('../../lib/cloudinary', () => ({
  cloudinary: cloudinaryMock,
  getUploadSignature: vi.fn(),
}));
vi.mock('../../lib/firebase', () => ({ getFirebaseMessaging: vi.fn() }));

import { purgeExpiredAttendanceEvidence } from './attendance.service';

describe('attendance evidence retention', () => {
  beforeEach(() => {
    vi.resetAllMocks();
    prismaMock.attendanceEvidence.findMany.mockResolvedValue([
      {
        id: 'evidence-1',
        asset_id: 'asset-1',
        asset: {
          id: 'asset-1',
          storage_key: 'organizations/org-1/attendance-selfies/selfie-1',
        },
      },
    ]);
    cloudinaryMock.uploader.destroy.mockResolvedValue({ result: 'ok' });
    prismaMock.$transaction.mockImplementation(async (callback: (tx: unknown) => unknown) =>
      callback({
        attendanceEvidence: { update: vi.fn() },
        mediaAsset: { deleteMany: mediaAssetDeleteMany },
      }),
    );
  });

  it('deletes private media before purging sensitive evidence fields', async () => {
    const result = await purgeExpiredAttendanceEvidence(10);

    expect(cloudinaryMock.uploader.destroy).toHaveBeenCalledWith(
      'organizations/org-1/attendance-selfies/selfie-1',
      expect.objectContaining({ type: 'authenticated', invalidate: true }),
    );
    expect(prismaMock.$transaction).toHaveBeenCalledTimes(1);
    expect(mediaAssetDeleteMany).toHaveBeenCalledWith({ where: { id: 'asset-1' } });
    expect(result).toMatchObject({ scanned: 1, purged: 1 });
  });

  it('keeps the database reference when private media deletion fails', async () => {
    cloudinaryMock.uploader.destroy.mockRejectedValue(new Error('storage unavailable'));

    const result = await purgeExpiredAttendanceEvidence(10);

    expect(result).toMatchObject({ scanned: 1, purged: 0 });
    expect(prismaMock.$transaction).not.toHaveBeenCalled();
  });
});
