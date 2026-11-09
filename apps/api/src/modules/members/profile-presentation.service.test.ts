import { beforeEach, expect, it, vi } from 'vitest';

const db = vi.hoisted(() => ({
  organizationMemberProfile: { findMany: vi.fn() },
  member: { findMany: vi.fn() },
}));
vi.mock('../../lib/prisma', () => ({ prisma: db }));
import {
  presentOrganizationProfiles,
  presentNotificationActors,
} from './profile-presentation.service';

beforeEach(() => {
  vi.resetAllMocks();
  db.organizationMemberProfile.findMany.mockResolvedValue([
    { user_id: 'user-a', name: 'Local name', phone: 'local-phone', avatar_url: 'new-photo' },
  ]);
});

it('refreshes notification actor photos using each notification organization', async () => {
  db.member.findMany.mockResolvedValue([{ id: 'member-a', user_id: 'user-a' }]);
  db.organizationMemberProfile.findMany.mockImplementation(async ({ where }) =>
    where.organization_id === 'org-a'
      ? [{ user_id: 'user-a', name: 'Local', avatar_url: 'new-photo', phone: null }]
      : [],
  );
  const notifications = ['org-a', 'org-b'].map((organization_id) => ({
    organization_id,
    data: { actor_member_id: 'member-a', actor_name: 'Original', actor_avatar_url: 'old-photo' },
  }));
  const result = await presentNotificationActors(notifications);
  expect(result[0].data.actor_avatar_url).toBe('new-photo');
  expect(result[1].data.actor_avatar_url).toBe('old-photo');
  expect(notifications[0].data.actor_avatar_url).toBe('old-photo');
});
it('projects the same identity across attendance, meal, payment and feed shapes', async () => {
  const user = { id: 'user-a', name: 'Old', avatar_url: 'old-photo' };
  const payload = {
    data: [
      { member: { user } },
      { subscription: { member: { user } } },
      { created_by: user },
      { comments: [{ actor: user }] },
    ],
  };
  const result = (await presentOrganizationProfiles('org-a', payload)) as typeof payload;
  expect(JSON.stringify(result)).not.toContain('old-photo');
  expect(result.data[0].member?.user.name).toBe('Local name');
  expect(JSON.stringify(result)).not.toContain('local-phone');
  expect(user.name).toBe('Old');
  expect(db.organizationMemberProfile.findMany).toHaveBeenCalledOnce();
  expect(db.organizationMemberProfile.findMany).toHaveBeenCalledWith(
    expect.objectContaining({ where: { organization_id: 'org-a', user_id: { in: ['user-a'] } } }),
  );
});
it('retains fallback fields in other organizations', async () => {
  db.organizationMemberProfile.findMany.mockResolvedValue([]);
  const payload = { data: { user: { id: 'user-a', name: 'Global' } } };
  expect(await presentOrganizationProfiles('org-b', payload)).toBe(payload);
});
it('projects the real flattened fee-list contract using the scoped membership ID', async () => {
  db.member.findMany.mockResolvedValue([{ id: 'membership-a', user_id: 'user-a' }]);
  const payload = {
    data: [
      {
        member: {
          id: 'membership-a',
          name: 'Old',
          avatar_url: 'old-photo',
          member_number: '42',
          role_name: 'Member',
        },
        balance_minor_unit: 3500,
      },
    ],
    meta: { total: 1 },
  };
  const result = (await presentOrganizationProfiles('org-a', payload)) as typeof payload;
  expect(result.data[0].member).toEqual({
    id: 'membership-a',
    name: 'Local name',
    avatar_url: 'new-photo',
    member_number: '42',
    role_name: 'Member',
  });
  expect(result.data[0].balance_minor_unit).toBe(3500);
  expect(db.member.findMany).toHaveBeenCalledWith({
    where: { organization_id: 'org-a', id: { in: ['membership-a'] } },
    select: { id: true, user_id: true },
  });
});
it('does not inspect rich content, snapshots or private arbitrary JSON', async () => {
  const user = { id: 'user-a', name: 'Historical', phone: 'unchanged' };
  const payload = {
    content: { user },
    shift_snapshot: { user },
    gateway_response: { user },
    earnings: [{ user }],
    data: [{ data: { user } }],
  };
  expect(await presentOrganizationProfiles('org-a', payload)).toBe(payload);
  expect(db.organizationMemberProfile.findMany).not.toHaveBeenCalled();
});
it('does not resolve a flattened membership outside the authorized organization', async () => {
  db.member.findMany.mockResolvedValue([]);
  const payload = {
    data: [{ member: { id: 'foreign-member', name: 'Original', avatar_url: 'original-photo' } }],
  };
  expect(await presentOrganizationProfiles('org-a', payload)).toBe(payload);
  expect(db.organizationMemberProfile.findMany).not.toHaveBeenCalled();
});
