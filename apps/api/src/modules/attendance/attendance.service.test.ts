import { beforeEach, describe, expect, it, vi } from 'vitest';

const prismaMock = vi.hoisted(() => ({
  member: { findFirst: vi.fn() },
  role: { findFirst: vi.fn() },
  attendancePolicy: { findFirst: vi.fn(), findMany: vi.fn(), update: vi.fn(), create: vi.fn() },
  attendanceSession: { findFirst: vi.fn(), update: vi.fn() },
  attendanceCorrection: { create: vi.fn() },
  auditLog: { create: vi.fn() },
  $transaction: vi.fn(),
}));

vi.mock('../../lib/prisma', () => ({ prisma: prismaMock }));

import { correctSession, getEffectivePolicyForMember, updatePolicy } from './attendance.service';

const policy = (scope: 'member' | 'role' | 'branch') => ({
  id: `${scope}-policy`,
  version: scope === 'member' ? 3 : 2,
  organization_id: 'org-1',
  branch_id: 'branch-1',
  role_id: scope === 'role' ? 'role-1' : null,
  member_id: scope === 'member' ? 'member-1' : null,
  effective_from: new Date('2026-09-01T00:00:00.000Z'),
  effective_to: null,
  punch_required: true,
});

describe('attendance policy resolution', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    prismaMock.member.findFirst.mockResolvedValue({ id: 'member-1', role_id: 'role-1' });
    prismaMock.$transaction.mockImplementation(async (callback: (tx: unknown) => unknown) =>
      callback(prismaMock),
    );
  });

  it('chooses a direct member policy before role and branch defaults', async () => {
    prismaMock.attendancePolicy.findMany.mockResolvedValue([
      policy('branch'),
      policy('role'),
      policy('member'),
    ]);

    const result = await getEffectivePolicyForMember('org-1', 'branch-1', 'member-1');

    expect(result.id).toBe('member-policy');
    expect(result.source_scope).toBe('MEMBER');
  });

  it('falls back from role policy to the branch default', async () => {
    prismaMock.attendancePolicy.findMany.mockResolvedValue([policy('branch')]);

    const result = await getEffectivePolicyForMember('org-1', 'branch-1', 'member-1');

    expect(result.id).toBe('branch-policy');
    expect(result.source_scope).toBe('BRANCH_DEFAULT');
  });

  it('returns the safe fallback when no effective policy exists', async () => {
    prismaMock.attendancePolicy.findMany.mockResolvedValue([]);

    const result = await getEffectivePolicyForMember('org-1', 'branch-1', 'member-1');

    expect(result.id).toBeNull();
    expect(result.source_scope).toBe('BRANCH_DEFAULT');
    expect(result.punch_required).toBe(true);
  });

  it('uses explicit role-assignment priority before role id ordering', async () => {
    prismaMock.member.findFirst.mockResolvedValue({
      id: 'member-1',
      role_id: 'role-1',
      role_assignments: [{ role_id: 'role-2' }, { role_id: 'role-1' }],
    });
    prismaMock.attendancePolicy.findMany.mockResolvedValue([
      { ...policy('branch'), role_id: null, member_id: null },
      { ...policy('role'), id: 'role-1-policy', role_id: 'role-1', member_id: null },
      { ...policy('role'), id: 'role-2-policy', role_id: 'role-2', member_id: null },
    ]);

    const result = await getEffectivePolicyForMember('org-1', 'branch-1', 'member-1');

    expect(result.id).toBe('role-2-policy');
    expect(result.source_scope).toBe('ROLE');
    expect(result.resolved_role_id).toBe('role-2');
  });

  it('rejects a member policy target from another tenant or branch', async () => {
    prismaMock.member.findFirst.mockResolvedValue(null);

    await expect(
      updatePolicy(
        'actor-1',
        'org-1',
        'branch-1',
        { member_id: 'foreign-member' },
        new Set(['ATTENDANCE_POLICY_MANAGE']),
      ),
    ).rejects.toThrow('Member policy target');
    expect(prismaMock.attendancePolicy.findFirst).not.toHaveBeenCalled();
  });

  it('rejects a role policy target outside the organization or branch', async () => {
    prismaMock.role.findFirst.mockResolvedValue(null);

    await expect(
      updatePolicy(
        'actor-1',
        'org-1',
        'branch-1',
        { role_id: 'foreign-role' },
        new Set(['ATTENDANCE_POLICY_MANAGE']),
      ),
    ).rejects.toThrow('Role policy target');
    expect(prismaMock.attendancePolicy.findFirst).not.toHaveBeenCalled();
  });

  it('rejects an enabled geofence without a radius before replacing the active policy', async () => {
    await expect(
      updatePolicy(
        'actor-1',
        'org-1',
        'branch-1',
        { geofence_enabled: true },
        new Set(['ATTENDANCE_POLICY_MANAGE']),
      ),
    ).rejects.toThrow('A geofence radius is required when geofencing is enabled');
    expect(prismaMock.attendancePolicy.update).not.toHaveBeenCalled();
    expect(prismaMock.attendancePolicy.create).not.toHaveBeenCalled();
  });

  it('enforces policy and correction permissions inside the service layer', async () => {
    await expect(updatePolicy('actor-1', 'org-1', 'branch-1', {}, new Set())).rejects.toThrow(
      'Attendance policy management permission is required',
    );
    await expect(
      correctSession(
        'actor-1',
        'org-1',
        'branch-1',
        'session-1',
        { correction_reason: 'Unauthorized correction attempt' },
        new Set(),
      ),
    ).rejects.toThrow('Attendance correction permission is required');
  });

  it('writes an immutable correction record before updating the current projection', async () => {
    const original = {
      id: 'session-1',
      organization_id: 'org-1',
      branch_id: 'branch-1',
      correction_version: 0,
      clock_in_at: new Date('2026-09-26T08:00:00.000Z'),
      clock_out_at: new Date('2026-09-26T16:00:00.000Z'),
      state: 'CLOSED',
      derived_status: 'PRESENT',
    };
    prismaMock.attendanceSession.findFirst.mockResolvedValue(original);
    prismaMock.attendanceSession.update.mockResolvedValue({
      ...original,
      correction_version: 1,
      clock_in_at: new Date('2026-09-26T08:15:00.000Z'),
      corrected_at: new Date('2026-09-26T17:00:00.000Z'),
      state: 'CORRECTED',
    });

    await correctSession(
      'actor-1',
      'org-1',
      'branch-1',
      'session-1',
      {
        clock_in_at: '2026-09-26T08:15:00.000Z',
        correction_reason: 'Manager corrected the recorded arrival time',
      },
      new Set(['ATTENDANCE_UPDATE']),
    );

    expect(prismaMock.attendanceCorrection.create).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({
          session_id: 'session-1',
          version: 1,
          previous_clock_in_at: original.clock_in_at,
          corrected_clock_in_at: new Date('2026-09-26T08:15:00.000Z'),
        }),
      }),
    );
    expect(prismaMock.attendanceSession.update).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({ correction_version: 1, state: 'CORRECTED' }),
      }),
    );
  });
});
