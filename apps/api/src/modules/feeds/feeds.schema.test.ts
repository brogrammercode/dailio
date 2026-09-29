import { describe, expect, it } from 'vitest';

import {
  CreateFeedCommentSchema,
  CreateFeedPostSchema,
  CreateFeedSchema,
  SetFeedReactionSchema,
} from './feeds.schema';

describe('feed schema', () => {
  it('defaults safe feed controls and accepts participants', () => {
    const feed = CreateFeedSchema.parse({ name: 'Trainers', member_ids: ['member-1'] });
    expect(feed.participants_can_post).toBe(false);
    expect(feed.report_threshold).toBe(3);
    expect(feed.member_ids).toEqual(['member-1']);
  });

  it('validates post timeout and post content', () => {
    expect(() => CreateFeedSchema.parse({ name: 'Team', post_timeout: 0 })).toThrow();
    const post = CreateFeedPostSchema.parse({ title: 'Update', body: 'The session starts at 7.' });
    expect(post.title).toBe('Update');
  });

  it('accepts image and slide blocks for rich posts', () => {
    const post = CreateFeedPostSchema.parse({
      title: 'Slides',
      body: 'Weekly update',
      content: [
        { type: 'image', storage_key: 'organizations/org/branches/branch/feeds/image' },
        {
          type: 'slide',
          storage_key: 'organizations/org/branches/branch/feeds/slide',
          slide_index: 0,
        },
      ],
    });
    expect(post.content).toHaveLength(2);
  });

  it('supports reactions, replies, and idempotency keys', () => {
    expect(SetFeedReactionSchema.parse({ reaction: 'CELEBRATE' }).reaction).toBe('CELEBRATE');
    const comment = CreateFeedCommentSchema.parse({
      body: 'Thanks!',
      reply_to_id: 'comment-1',
      idempotency_key: 'mobile-comment-1234',
    });
    expect(comment.reply_to_id).toBe('comment-1');
  });
});
