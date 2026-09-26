import { beforeEach, describe, expect, it, vi } from 'vitest';

const prismaMock = vi.hoisted(() => ({
  branch: { findFirst: vi.fn() },
  member: { findFirst: vi.fn() },
  attendancePolicy: { findMany: vi.fn() },
  attendanceSession: { findFirst: vi.fn(), create: vi.fn() },
  attendanceEvidence: { create: vi.fn() },
  mediaAsset: { create: vi.fn() },
  auditLog: { create: vi.fn() },
  $transaction: vi.fn(),
}));

vi.mock('../../lib/prisma', () => ({ prisma: prismaMock }));

import { clockIn, createAttendanceSelfieUploadSignature } from './attendance.service';

const member = {
  id: 'member-1',
  user_id: 'user-1',
  organization_id: 'org-1',
  branch_id: 'branch-1',
  status: 'ACTIVE',
  role_id: null,
  branch: { timezone: 'UTC' },
  shift: null,
  shift_id: null,
};

const policy = (overrides: Record<string, unknown> = {}) => ({
  id: 'policy-1',
  version: 3,
  organization_id: 'org-1',
  branch_id: 'branch-1',
  role_id: null,
  member_id: null,
  effective_from: new Date('2026-09-01T00:00:00.000Z'),
  effective_to: null,
  punch_required: true,
  selfie_on_clock_in: false,
  selfie_on_clock_out: false,
  location_on_clock_in: false,
  location_on_clock_out: false,
  geofence_enabled: false,
  geofence_lat: null,
  geofence_lng: null,
  geofence_radius_meters: null,
  geofence_accuracy_threshold: null,
  shift_enforcement_enabled: false,
  early_arrival_minutes: 30,
  late_grace_minutes: 15,
  min_session_minutes: 0,
  max_open_session_hours: 24,
  ...overrides,
});

describe('attendance punch enforcement', () => {
  beforeEach(() => {
    vi.resetAllMocks();
    prismaMock.member.findFirst.mockResolvedValue(member);
    prismaMock.attendancePolicy.findMany.mockResolvedValue([policy()]);
    prismaMock.branch.findFirst.mockResolvedValue({
      latitude: 28.61,
      longitude: 77.21,
    });
    prismaMock.attendanceSession.findFirst.mockResolvedValue(null);
    prismaMock.$transaction.mockImplementation(async (callback: (tx: unknown) => unknown) =>
      callback(prismaMock),
    );
  });

  const punch = (overrides: Record<string, unknown> = {}) =>
    clockIn('user-1', 'org-1', 'branch-1', {
      idempotency_key: 'clock-in-key-12345678',
      timezone: 'UTC',
      ...overrides,
    });

  it('rejects a stale policy version before accepting evidence', async () => {
    await expect(punch({ policy_version: 2 })).rejects.toThrow(
      'Attendance policy changed while you were preparing the punch',
    );
    expect(prismaMock.$transaction).not.toHaveBeenCalled();
  });

  it('rejects a new punch when the effective policy disables punching', async () => {
    prismaMock.attendancePolicy.findMany.mockResolvedValue([policy({ punch_required: false })]);

    await expect(punch()).rejects.toThrow('Attendance punching is disabled by this policy');
    expect(prismaMock.$transaction).not.toHaveBeenCalled();
  });

  it('rejects missing selfie evidence when the effective policy requires it', async () => {
    prismaMock.attendancePolicy.findMany.mockResolvedValue([policy({ selfie_on_clock_in: true })]);

    await expect(punch()).rejects.toThrow('A live selfie is required for this attendance action');
    expect(prismaMock.$transaction).not.toHaveBeenCalled();
  });

  it('rejects a selfie storage key from another branch in the same organization', async () => {
    prismaMock.attendancePolicy.findMany.mockResolvedValue([policy({ selfie_on_clock_in: true })]);

    await expect(
      punch({
        selfie_storage_key: 'organizations/org-1/branches/other-branch/attendance-selfies/photo',
      }),
    ).rejects.toThrow('Attendance selfie storage key is invalid');
    expect(prismaMock.$transaction).not.toHaveBeenCalled();
  });

  it('rejects a branch-scoped selfie key without an actor-bound upload token', async () => {
    prismaMock.attendancePolicy.findMany.mockResolvedValue([policy({ selfie_on_clock_in: true })]);

    await expect(
      punch({
        selfie_storage_key: 'organizations/org-1/branches/branch-1/attendance-selfies/photo',
      }),
    ).rejects.toThrow('Attendance selfie upload is not authorized');
    expect(prismaMock.$transaction).not.toHaveBeenCalled();
  });

  it('accepts a selfie key signed for the authenticated actor and branch', async () => {
    prismaMock.attendancePolicy.findMany.mockResolvedValue([policy({ selfie_on_clock_in: true })]);
    const signature = createAttendanceSelfieUploadSignature(
      'user-1',
      'org-1',
      'branch-1',
      'selfie.jpg',
    );
    const created = { id: 'session-selfie-1', state: 'OPEN' };
    prismaMock.attendanceSession.create.mockResolvedValue(created);
    prismaMock.mediaAsset.create.mockResolvedValue({ id: 'asset-selfie-1' });

    await expect(
      punch({
        selfie_storage_key: signature.storage_key,
        selfie_upload_token: signature.upload_token,
      }),
    ).resolves.toBe(created);
    expect(prismaMock.mediaAsset.create).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({
          storage_key: signature.storage_key,
          uploaded_by: 'user-1',
        }),
      }),
    );
  });

  it('rejects missing location evidence when the effective policy requires it', async () => {
    prismaMock.attendancePolicy.findMany.mockResolvedValue([
      policy({ location_on_clock_in: true }),
    ]);

    await expect(punch()).rejects.toThrow(
      'Location evidence is required for this attendance action',
    );
    expect(prismaMock.$transaction).not.toHaveBeenCalled();
  });

  it('rejects a punch outside the configured geofence', async () => {
    prismaMock.attendancePolicy.findMany.mockResolvedValue([
      policy({
        geofence_enabled: true,
        geofence_lat: 28.61,
        geofence_lng: 77.21,
        geofence_radius_meters: 50,
      }),
    ]);

    await expect(punch({ latitude: 28.7, longitude: 77.3, accuracy: 5 })).rejects.toThrow(
      'outside the branch attendance geofence',
    );
    expect(prismaMock.$transaction).not.toHaveBeenCalled();
  });

  it('rejects a geofence punch whose accuracy exceeds the policy threshold', async () => {
    prismaMock.attendancePolicy.findMany.mockResolvedValue([
      policy({
        geofence_enabled: true,
        geofence_lat: 28.61,
        geofence_lng: 77.21,
        geofence_radius_meters: 100,
        geofence_accuracy_threshold: 25,
      }),
    ]);

    await expect(punch({ latitude: 28.61, longitude: 77.21, accuracy: 50 })).rejects.toThrow(
      'Location accuracy is outside the attendance policy',
    );
    expect(prismaMock.$transaction).not.toHaveBeenCalled();
  });

  it('rejects a punch without an assigned shift when shift enforcement is enabled', async () => {
    prismaMock.attendancePolicy.findMany.mockResolvedValue([
      policy({ shift_enforcement_enabled: true }),
    ]);

    await expect(punch()).rejects.toThrow(
      'A scheduled shift is required for this attendance action',
    );
    expect(prismaMock.$transaction).not.toHaveBeenCalled();
  });

  it('creates one server-confirmed QR gate session with an immutable snapshot', async () => {
    const created = {
      id: 'session-1',
      derived_status: null,
      policy_version: 3,
      source: 'QR_GATE',
    };
    prismaMock.attendanceSession.create.mockResolvedValue(created);

    const result = await clockIn(
      'user-1',
      'org-1',
      'branch-1',
      {
        idempotency_key: 'qr-key-12345678',
        timezone: 'UTC',
        client_time: '2026-09-26T08:00:00.000Z',
      },
      'QR_GATE',
    );

    expect(result).toBe(created);
    expect(prismaMock.attendanceSession.create).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({
          organization_id: 'org-1',
          branch_id: 'branch-1',
          member_id: 'member-1',
          source: 'QR_GATE',
          policy_version: 3,
          policy_snapshot: expect.objectContaining({ version: 3 }),
          branch_timezone: 'UTC',
        }),
      }),
    );
    expect(prismaMock.auditLog.create).toHaveBeenCalled();
  });
});
