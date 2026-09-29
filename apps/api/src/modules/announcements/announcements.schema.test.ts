import { describe, expect, it } from 'vitest';

import {
  CreateAnnouncementCommentSchema,
  CreateAnnouncementSchema,
  SetAnnouncementReactionSchema,
} from './announcements.schema';

describe('announcement schema', () => {
  it('accepts a scheduled role-targeted announcement', () => {
    const parsed = CreateAnnouncementSchema.parse({
      title: 'Holiday hours',
      body: 'The branch opens at 10:00.',
      audience: 'SELECTED_ROLES',
      role_ids: ['role-1'],
      publish_at: '2026-10-01T05:00:00.000Z',
    });
    expect(parsed.audience).toBe('SELECTED_ROLES');
    expect(parsed.role_ids).toEqual(['role-1']);
  });

  it('rejects oversized copy', () => {
    expect(() => CreateAnnouncementSchema.parse({ title: '', body: 'announcement' })).toThrow();
    expect(() =>
      CreateAnnouncementSchema.parse({ title: 'Announcement', body: 'x'.repeat(5001) }),
    ).toThrow();
  });

  it('accepts validated rich content and interaction payloads', () => {
    const announcement = CreateAnnouncementSchema.parse({
      title: 'New class',
      body: 'Registration is open.',
      content: [
        { type: 'heading', text: 'New class', marks: ['bold'] },
        { type: 'image', storage_key: 'organizations/o/branches/b/announcements/image-1' },
        {
          type: 'slide',
          storage_key: 'organizations/o/branches/b/announcements/image-2',
          slide_index: 1,
        },
      ],
    });
    expect(announcement.content).toHaveLength(3);
    expect(SetAnnouncementReactionSchema.parse({ reaction: 'LOVE' }).reaction).toBe('LOVE');
    expect(
      CreateAnnouncementCommentSchema.parse({ body: 'Looks great!', reply_to_id: 'comment-1' })
        .reply_to_id,
    ).toBe('comment-1');
  });

  it('rejects unsupported content and reactions', () => {
    expect(() =>
      CreateAnnouncementSchema.parse({ title: 'A', body: 'B', content: [{ type: 'video' }] }),
    ).toThrow();
    expect(() => SetAnnouncementReactionSchema.parse({ reaction: 'WOW' })).toThrow();
  });
});
