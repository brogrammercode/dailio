import { describe, expect, it } from 'vitest';

import { CreateAnnouncementSchema } from './announcements.schema';

describe('announcement schema', () => {
  it('accepts a scheduled role-targeted announcement', () => {
    const parsed = CreateAnnouncementSchema.parse({ title: 'Holiday hours', body: 'The branch opens at 10:00.', audience: 'SELECTED_ROLES', role_ids: ['role-1'], publish_at: '2026-10-01T05:00:00.000Z' });
    expect(parsed.audience).toBe('SELECTED_ROLES');
    expect(parsed.role_ids).toEqual(['role-1']);
  });

  it('rejects oversized copy', () => {
    expect(() => CreateAnnouncementSchema.parse({ title: '', body: 'announcement' })).toThrow();
    expect(() => CreateAnnouncementSchema.parse({ title: 'Announcement', body: 'x'.repeat(5001) })).toThrow();
  });
});
