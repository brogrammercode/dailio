import { beforeEach, describe, expect, it, vi } from 'vitest';

const prismaMock = vi.hoisted(() => ({
  organization: { findUnique: vi.fn() },
  branch: { findUnique: vi.fn() },
  member: { findFirst: vi.fn() },
}));

const authorizationMock = vi.hoisted(() => ({
  permissionsForMember: vi.fn(),
}));

vi.mock('../lib/prisma', () => ({ prisma: prismaMock }));
vi.mock('../modules/authorization/authorization.service', () => authorizationMock);

import { resolveTenantContext } from './tenant';

describe('tenant context lifecycle boundaries', () => {
  beforeEach(() => {
    vi.resetAllMocks();
  });

  it('rejects archived branches before resolving membership or permissions', async () => {
    prismaMock.organization.findUnique.mockResolvedValue({ id: 'org-1', status: 'ACTIVE' });
    prismaMock.branch.findUnique.mockResolvedValue({
      id: 'branch-1',
      organization_id: 'org-1',
      status: 'ARCHIVED',
    });
    const next = vi.fn();

    await resolveTenantContext(
      {
        user: { id: 'user-1' },
        headers: { 'x-organization-id': 'org-1', 'x-branch-id': 'branch-1' },
        params: {},
      } as never,
      {} as never,
      next,
    );

    expect(next).toHaveBeenCalledWith(
      expect.objectContaining({ statusCode: 404, code: 'NOT_FOUND' }),
    );
    expect(prismaMock.member.findFirst).not.toHaveBeenCalled();
  });

  it('continues only for an active organization branch membership', async () => {
    const organization = { id: 'org-1', status: 'ACTIVE' };
    const branch = { id: 'branch-1', organization_id: 'org-1', status: 'ACTIVE' };
    const member = {
      id: 'member-1',
      organization_id: 'org-1',
      branch_id: 'branch-1',
      role: null,
      role_assignments: [],
    };
    prismaMock.organization.findUnique.mockResolvedValue(organization);
    prismaMock.branch.findUnique.mockResolvedValue(branch);
    prismaMock.member.findFirst.mockResolvedValue(member);
    authorizationMock.permissionsForMember.mockReturnValue(new Set(['ATTENDANCE_READ_SELF']));
    const next = vi.fn();
    const request = {
      user: { id: 'user-1' },
      headers: { 'x-organization-id': 'org-1', 'x-branch-id': 'branch-1' },
      params: {},
    } as never;

    await resolveTenantContext(request, {} as never, next);

    expect(next).toHaveBeenCalledWith();
    expect(request.organization).toBe(organization);
    expect(request.branch).toBe(branch);
    expect(request.member).toBe(member);
    expect(request.permissions).toEqual(new Set(['ATTENDANCE_READ_SELF']));
  });
});
