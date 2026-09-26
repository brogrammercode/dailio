import { beforeEach, describe, expect, it, vi } from 'vitest';

const prismaMock = vi.hoisted(() => ({
  inviteToken: { findUnique: vi.fn() },
  member: { findFirst: vi.fn() },
  joinRequest: { findFirst: vi.fn() },
  attendanceSession: { findFirst: vi.fn() },
  auditLog: { create: vi.fn() },
}));

const attendanceMock = vi.hoisted(() => ({
  clockIn: vi.fn(),
  clockOut: vi.fn(),
  getEffectivePolicyForMember: vi.fn(),
}));

vi.mock('../../lib/prisma', () => ({ prisma: prismaMock }));
vi.mock('../attendance/attendance.service', () => attendanceMock);

import { NotFoundError } from '../../lib/errors';

import { punchAttendanceFromInvite, resolveInvite } from './invites.service';

describe('permanent gate QR idempotency', () => {
  beforeEach(() => vi.resetAllMocks());

  const invite = (overrides: Record<string, unknown> = {}) => ({
    id: 'invite-1',
    purpose: 'BRANCH_JOIN',
    revoked_at: null,
    expires_at: null,
    organization_id: 'org-1',
    branch_id: 'branch-1',
    organization: { id: 'org-1', name: 'Gym' },
    branch: {
      id: 'branch-1',
      name: 'Main',
      city: null,
      state: null,
      timezone: 'UTC',
      status: 'ACTIVE',
    },
    plan: null,
    ...overrides,
  });

  it('returns the prior result without creating a duplicate QR audit event', async () => {
    prismaMock.inviteToken.findUnique.mockResolvedValue(invite());
    prismaMock.member.findFirst.mockResolvedValue({
      id: 'member-1',
      user_id: 'user-1',
      organization_id: 'org-1',
      branch_id: 'branch-1',
      status: 'ACTIVE',
    });
    const prior = { id: 'session-1', state: 'OPEN', evidence: [] };
    prismaMock.attendanceSession.findFirst.mockResolvedValue(prior);

    const result = await punchAttendanceFromInvite('user-1', 'raw-token', 'idem-12345678', {
      token: 'raw-token',
      timezone: 'UTC',
    });

    expect(result).toBe(prior);
    expect(attendanceMock.clockIn).not.toHaveBeenCalled();
    expect(attendanceMock.clockOut).not.toHaveBeenCalled();
    expect(prismaMock.auditLog.create).not.toHaveBeenCalled();
  });

  it('returns the correct member state and server-derived next action', async () => {
    prismaMock.inviteToken.findUnique.mockResolvedValue(invite());
    prismaMock.member.findFirst.mockResolvedValue({
      id: 'member-1',
      status: 'ACTIVE',
      shift: null,
    });
    prismaMock.joinRequest.findFirst.mockResolvedValue(null);
    prismaMock.attendanceSession.findFirst.mockResolvedValue(null);
    attendanceMock.getEffectivePolicyForMember.mockResolvedValue({
      version: 4,
      source_scope: 'ROLE',
      effective_from: new Date('2026-09-01T00:00:00.000Z'),
      selfie_on_clock_in: false,
      selfie_on_clock_out: true,
      location_on_clock_in: true,
      location_on_clock_out: true,
      geofence_enabled: true,
      shift_enforcement_enabled: false,
    });

    const result = await resolveInvite('user-1', 'raw-token');

    expect(result.joinability).toBe('ALREADY_MEMBER');
    expect(result.attendance_action).toBe('CLOCK_IN');
    expect(result.attendance_policy).toEqual(
      expect.objectContaining({
        version: 4,
        source_scope: 'ROLE',
        location_required: true,
        selfie_required: true,
      }),
    );
    expect(prismaMock.attendanceSession.findFirst).toHaveBeenCalledWith(
      expect.objectContaining({
        where: expect.objectContaining({
          organization_id: 'org-1',
          branch_id: 'branch-1',
          member_id: 'member-1',
          state: 'OPEN',
        }),
      }),
    );
  });

  it('returns pending and inactive states without exposing attendance action', async () => {
    prismaMock.inviteToken.findUnique.mockResolvedValue(invite());
    prismaMock.member.findFirst.mockResolvedValueOnce(null);
    prismaMock.joinRequest.findFirst.mockResolvedValue({
      id: 'join-1',
      created_at: new Date(),
    });

    const pending = await resolveInvite('user-1', 'raw-token');
    expect(pending.joinability).toBe('ALREADY_PENDING');
    expect(pending.attendance_action).toBeNull();

    prismaMock.member.findFirst.mockResolvedValueOnce({
      id: 'member-1',
      status: 'INACTIVE',
      shift: null,
    });
    prismaMock.joinRequest.findFirst.mockResolvedValue(null);

    const inactive = await resolveInvite('user-1', 'raw-token');
    expect(inactive.joinability).toBe('MEMBERSHIP_INACTIVE');
    expect(inactive.attendance_action).toBeNull();
  });

  it('exposes a disabled attendance state when the effective policy does not require punches', async () => {
    prismaMock.inviteToken.findUnique.mockResolvedValue(invite());
    prismaMock.member.findFirst.mockResolvedValue({
      id: 'member-1',
      status: 'ACTIVE',
      shift: null,
    });
    prismaMock.joinRequest.findFirst.mockResolvedValue(null);
    prismaMock.attendanceSession.findFirst.mockResolvedValue(null);
    attendanceMock.getEffectivePolicyForMember.mockResolvedValue({
      version: 5,
      source_scope: 'MEMBER',
      punch_required: false,
      selfie_on_clock_in: false,
      selfie_on_clock_out: false,
      location_on_clock_in: false,
      location_on_clock_out: false,
      geofence_enabled: false,
      shift_enforcement_enabled: false,
    });

    const result = await resolveInvite('user-1', 'raw-token');

    expect(result.attendance_action).toBe('ATTENDANCE_DISABLED');
    expect(result.attendance_available).toBe(false);
    expect(result.attendance_policy).toEqual(
      expect.objectContaining({ punch_required: false }),
    );
  });

  it('keeps clock-out available for an existing open session after a disabled policy snapshot', async () => {
    prismaMock.inviteToken.findUnique.mockResolvedValue(invite());
    prismaMock.member.findFirst.mockResolvedValue({
      id: 'member-1',
      status: 'ACTIVE',
      shift: null,
    });
    prismaMock.joinRequest.findFirst.mockResolvedValue(null);
    prismaMock.attendanceSession.findFirst.mockResolvedValue({
      id: 'session-1',
      clock_in_at: new Date(),
      policy_version: 3,
      policy_snapshot: { version: 3, punch_required: false },
    });
    attendanceMock.getEffectivePolicyForMember.mockResolvedValue({
      version: 4,
      source_scope: 'MEMBER',
      punch_required: false,
      geofence_enabled: false,
      selfie_on_clock_in: false,
      selfie_on_clock_out: false,
      location_on_clock_in: false,
      location_on_clock_out: false,
      shift_enforcement_enabled: false,
    });

    const result = await resolveInvite('user-1', 'raw-token');

    expect(result.attendance_action).toBe('CLOCK_OUT');
    expect(result.attendance_available).toBe(true);
  });

  it('rejects revoked and expired gate credentials', async () => {
    prismaMock.inviteToken.findUnique.mockResolvedValue(invite({ revoked_at: new Date() }));
    await expect(resolveInvite('user-1', 'raw-token')).rejects.toBeInstanceOf(NotFoundError);

    prismaMock.inviteToken.findUnique.mockResolvedValue(
      invite({ expires_at: new Date(Date.now() - 1_000) }),
    );
    await expect(resolveInvite('user-1', 'raw-token')).rejects.toBeInstanceOf(NotFoundError);
  });
});
