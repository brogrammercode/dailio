import { beforeEach, expect, it, vi } from 'vitest';

const db = vi.hoisted(() => ({
  member: { findFirst: vi.fn() },
  organizationMemberProfile: { upsert: vi.fn(), findMany: vi.fn() },
  auditLog: { create: vi.fn() },
  $transaction: vi.fn(),
}));
vi.mock('../../lib/prisma', () => ({ prisma: db }));
const upload = vi.hoisted(() => vi.fn());
vi.mock('../../lib/cloudinary', () => ({ cloudinary: { uploader: { upload } } }));
import {
  MemberProfileSchema,
  updateOrganizationMemberProfile,
  withOrganizationProfiles,
} from './member-profile.service';
beforeEach(() => {
  vi.resetAllMocks();
  db.$transaction.mockImplementation(async (fn) => fn(db));
});
it('uploads organization profile images at 60% while retaining avatar dimensions and scope', async () => {
  db.member.findFirst
    .mockResolvedValueOnce({ role: { system_key: 'OWNER', permissions: [] }, role_assignments: [] })
    .mockResolvedValue({ user_id: 'user' });
  upload.mockResolvedValue({ secure_url: 'https://example.invalid/new-avatar.jpg' });
  await updateOrganizationMemberProfile('actor', 'org', 'branch', 'member', {
    avatar_base64: 'data:image/jpeg;base64,AAAA',
  });
  expect(upload).toHaveBeenCalledWith(
    'data:image/jpeg;base64,AAAA',
    expect.objectContaining({
      folder: 'organizations/org/member-profiles/user',
      overwrite: false,
      transformation: [expect.objectContaining({ quality: 60, width: 400, height: 400 })],
    }),
  );
  expect(db.organizationMemberProfile.upsert).toHaveBeenCalledWith(
    expect.objectContaining({
      update: expect.objectContaining({ avatar_url: 'https://example.invalid/new-avatar.jpg' }),
    }),
  );
});
it('rejects unauthorized operators before looking up the target', async () => {
  db.member.findFirst.mockResolvedValue({ role: null, role_assignments: [] });
  await expect(
    updateOrganizationMemberProfile('actor', 'org', 'branch', 'member', { name: 'New' }),
  ).rejects.toThrow('not permitted');
  expect(db.organizationMemberProfile.upsert).not.toHaveBeenCalled();
});
it('rejects identifiers outside the authorized organization and branch', async () => {
  db.member.findFirst
    .mockResolvedValueOnce({ role: { system_key: 'OWNER', permissions: [] }, role_assignments: [] })
    .mockResolvedValue(null);
  await expect(
    updateOrganizationMemberProfile('actor', 'org', 'branch', 'foreign', { name: 'New' }),
  ).rejects.toThrow('not found');
  expect(db.organizationMemberProfile.upsert).not.toHaveBeenCalled();
});
it('writes only the organization profile and records an audit event', async () => {
  db.member.findFirst
    .mockResolvedValueOnce({ role: { system_key: 'OWNER', permissions: [] }, role_assignments: [] })
    .mockResolvedValue({ user_id: 'user' });
  await updateOrganizationMemberProfile('actor', 'org', 'branch', 'member', {
    name: 'New',
    phone: '',
  });
  expect(db.organizationMemberProfile.upsert).toHaveBeenCalledWith(
    expect.objectContaining({
      where: { organization_id_user_id: { organization_id: 'org', user_id: 'user' } },
    }),
  );
  expect(db.auditLog.create).toHaveBeenCalled();
});
it('overlays organization-only fields without mutating the global identity', async () => {
  db.organizationMemberProfile.findMany.mockResolvedValue([
    { user_id: 'user', name: 'Local', phone: '', avatar_url: null },
  ]);
  const original = { user_id: 'user', user: { name: 'Global', phone: '123', avatar_url: null } };
  const [result] = await withOrganizationProfiles('org', [original]);
  expect(result.user.name).toBe('Local');
  expect(result.user.phone).toBe('');
  expect(original.user.name).toBe('Global');
  expect(db.organizationMemberProfile.findMany).toHaveBeenCalledWith(
    expect.objectContaining({ where: { organization_id: 'org', user_id: { in: ['user'] } } }),
  );
});
it('rejects privilege fields and invalid image data at the boundary', () => {
  expect(MemberProfileSchema.safeParse({ name: 'New', role_id: 'owner' }).success).toBe(false);
  expect(
    MemberProfileSchema.safeParse({ avatar_base64: 'https://untrusted.invalid' }).success,
  ).toBe(false);
});
