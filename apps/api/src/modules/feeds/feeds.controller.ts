import type { NextFunction, Request, Response } from 'express';

import { ForbiddenError } from '../../lib/errors';

import {
  AddFeedParticipantSchema,
  CreateFeedCommentSchema,
  FeedMediaSignatureSchema,
  FeedMediaUrlSchema,
  CreateFeedPostSchema,
  CreateFeedReportSchema,
  CreateFeedSchema,
  SetFeedReactionSchema,
  UpdateFeedPostSchema,
  UpdateFeedSchema,
} from './feeds.schema';
import * as feedsService from './feeds.service';

function assertOrganization(req: Request) {
  if (req.params.organization_id !== req.organization!.id)
    throw new ForbiddenError('Organization scope is invalid');
}

export async function listFeeds(req: Request, res: Response, next: NextFunction) {
  try {
    assertOrganization(req);
    res.json({
      data: await feedsService.listFeeds(
        req.organization!.id,
        req.branch!.id,
        req.member!.id,
        req.permissions ?? new Set(),
      ),
    });
  } catch (error) {
    next(error);
  }
}

export async function createFeed(req: Request, res: Response, next: NextFunction) {
  try {
    assertOrganization(req);
    res.status(201).json({
      data: await feedsService.createFeed(
        req.organization!.id,
        req.branch!.id,
        req.member!.id,
        req.user!.id,
        CreateFeedSchema.parse(req.body),
      ),
    });
  } catch (error) {
    next(error);
  }
}

export async function updateFeed(req: Request, res: Response, next: NextFunction) {
  try {
    assertOrganization(req);
    res.json({
      data: await feedsService.updateFeed(
        req.organization!.id,
        req.branch!.id,
        req.params.feed_id,
        req.user!.id,
        UpdateFeedSchema.parse(req.body),
      ),
    });
  } catch (error) {
    next(error);
  }
}

export async function addParticipant(req: Request, res: Response, next: NextFunction) {
  try {
    assertOrganization(req);
    const input = AddFeedParticipantSchema.parse(req.body);
    res.status(201).json({
      data: await feedsService.addParticipant(
        req.organization!.id,
        req.branch!.id,
        req.params.feed_id,
        req.user!.id,
        input.member_id,
      ),
    });
  } catch (error) {
    next(error);
  }
}

export async function removeParticipant(req: Request, res: Response, next: NextFunction) {
  try {
    assertOrganization(req);
    await feedsService.removeParticipant(
      req.organization!.id,
      req.branch!.id,
      req.params.feed_id,
      req.params.member_id,
      req.user!.id,
    );
    res.status(204).send();
  } catch (error) {
    next(error);
  }
}

export async function disbandFeed(req: Request, res: Response, next: NextFunction) {
  try {
    assertOrganization(req);
    res.json({
      data: await feedsService.disbandFeed(
        req.organization!.id,
        req.branch!.id,
        req.params.feed_id,
        req.user!.id,
      ),
    });
  } catch (error) {
    next(error);
  }
}

export async function listPosts(req: Request, res: Response, next: NextFunction) {
  try {
    assertOrganization(req);
    res.json({
      data: await feedsService.listPosts(
        req.organization!.id,
        req.branch!.id,
        req.params.feed_id,
        req.member!.id,
        req.permissions ?? new Set(),
      ),
    });
  } catch (error) {
    next(error);
  }
}

export async function createFeedMediaSignature(req: Request, res: Response, next: NextFunction) {
  try {
    assertOrganization(req);
    const input = FeedMediaSignatureSchema.parse(req.body);
    res.status(201).json({
      data: feedsService.createFeedMediaUploadSignature(
        req.organization!.id,
        req.branch!.id,
        input.filename,
      ),
    });
  } catch (error) {
    next(error);
  }
}

export async function getFeedMediaUrl(req: Request, res: Response, next: NextFunction) {
  try {
    assertOrganization(req);
    const input = FeedMediaUrlSchema.parse(req.query);
    const content = await feedsService.getFeedMediaContent(
      req.organization!.id,
      req.branch!.id,
      input.feed_id,
      input.post_id,
      req.member!.id,
      req.permissions ?? new Set(),
    );
    const blocks = Array.isArray(content) ? content : [];
    const ownsMedia = blocks.some(
      (block) =>
        block &&
        typeof block === 'object' &&
        (block as { storage_key?: unknown }).storage_key === input.storage_key,
    );
    if (!ownsMedia) throw new ForbiddenError('Feed media scope is invalid');
    res.json({
      data: feedsService.createFeedMediaDownloadUrl(
        req.organization!.id,
        req.branch!.id,
        input.storage_key,
        input.format,
      ),
    });
  } catch (error) {
    next(error);
  }
}

export async function createPost(req: Request, res: Response, next: NextFunction) {
  try {
    assertOrganization(req);
    res.status(201).json({
      data: await feedsService.createPost(
        req.organization!.id,
        req.branch!.id,
        req.params.feed_id,
        req.member!.id,
        req.user!.id,
        CreateFeedPostSchema.parse(req.body),
        req.permissions ?? new Set(),
      ),
    });
  } catch (error) {
    next(error);
  }
}

export async function markPostRead(req: Request, res: Response, next: NextFunction) {
  try {
    assertOrganization(req);
    res.json({
      data: await feedsService.markPostRead(
        req.organization!.id,
        req.branch!.id,
        req.params.feed_id,
        req.params.post_id,
        req.member!.id,
        req.permissions ?? new Set(),
      ),
    });
  } catch (error) {
    next(error);
  }
}

export async function getPost(req: Request, res: Response, next: NextFunction) {
  try {
    assertOrganization(req);
    res.json({
      data: await feedsService.getPost(
        req.organization!.id,
        req.branch!.id,
        req.params.feed_id,
        req.params.post_id,
        req.member!.id,
        req.permissions ?? new Set(),
      ),
    });
  } catch (error) {
    next(error);
  }
}

export async function updatePost(req: Request, res: Response, next: NextFunction) {
  try {
    assertOrganization(req);
    res.json({
      data: await feedsService.updatePost(
        req.organization!.id,
        req.branch!.id,
        req.params.feed_id,
        req.params.post_id,
        req.member!.id,
        req.user!.id,
        UpdateFeedPostSchema.parse(req.body),
        req.permissions ?? new Set(),
      ),
    });
  } catch (error) {
    next(error);
  }
}

export async function deletePost(req: Request, res: Response, next: NextFunction) {
  try {
    assertOrganization(req);
    await feedsService.deletePost(
      req.organization!.id,
      req.branch!.id,
      req.params.feed_id,
      req.params.post_id,
      req.member!.id,
      req.user!.id,
      req.permissions ?? new Set(),
    );
    res.status(204).send();
  } catch (error) {
    next(error);
  }
}

export async function setReaction(req: Request, res: Response, next: NextFunction) {
  try {
    assertOrganization(req);
    res.json({
      data: await feedsService.setReaction(
        req.organization!.id,
        req.branch!.id,
        req.params.feed_id,
        req.params.post_id,
        req.member!.id,
        req.user!.id,
        SetFeedReactionSchema.parse(req.body),
        req.permissions ?? new Set(),
      ),
    });
  } catch (error) {
    next(error);
  }
}

export async function removeReaction(req: Request, res: Response, next: NextFunction) {
  try {
    assertOrganization(req);
    await feedsService.removeReaction(
      req.organization!.id,
      req.branch!.id,
      req.params.feed_id,
      req.params.post_id,
      req.member!.id,
      req.permissions ?? new Set(),
    );
    res.status(204).send();
  } catch (error) {
    next(error);
  }
}

export async function listComments(req: Request, res: Response, next: NextFunction) {
  try {
    assertOrganization(req);
    res.json({
      data: await feedsService.listComments(
        req.organization!.id,
        req.branch!.id,
        req.params.feed_id,
        req.params.post_id,
        req.member!.id,
        req.permissions ?? new Set(),
      ),
    });
  } catch (error) {
    next(error);
  }
}

export async function createComment(req: Request, res: Response, next: NextFunction) {
  try {
    assertOrganization(req);
    res.status(201).json({
      data: await feedsService.createComment(
        req.organization!.id,
        req.branch!.id,
        req.params.feed_id,
        req.params.post_id,
        req.member!.id,
        req.user!.id,
        CreateFeedCommentSchema.parse(req.body),
        req.permissions ?? new Set(),
      ),
    });
  } catch (error) {
    next(error);
  }
}

export async function deleteComment(req: Request, res: Response, next: NextFunction) {
  try {
    assertOrganization(req);
    await feedsService.deleteComment(
      req.organization!.id,
      req.branch!.id,
      req.params.comment_id,
      req.user!.id,
      req.permissions ?? new Set(),
    );
    res.status(204).send();
  } catch (error) {
    next(error);
  }
}

export async function reportPost(req: Request, res: Response, next: NextFunction) {
  try {
    assertOrganization(req);
    const input = CreateFeedReportSchema.parse(req.body);
    res.status(201).json({
      data: await feedsService.reportPost(
        req.organization!.id,
        req.branch!.id,
        req.params.feed_id,
        req.params.post_id,
        req.member!.id,
        req.user!.id,
        input.reason,
        req.permissions ?? new Set(),
      ),
    });
  } catch (error) {
    next(error);
  }
}
