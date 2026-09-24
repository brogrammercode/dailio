import { Request, Response, NextFunction } from 'express';

import { ValidationError } from '../../lib/errors';
import {
  AssignSubscriptionSchema,
  CancelSubscriptionSchema,
  RenewSubscriptionSchema,
  SubscriptionTransitionSchema,
  UpdateSubscriptionSchema,
} from './subscriptions.schema';
import * as SubscriptionsService from './subscriptions.service';

export async function assignSubscription(req: Request, res: Response, next: NextFunction) {
  try {
    const orgId = req.organization!.id;
    const branchId = req.branch!.id;
    const memberId = req.params.member_id;
    const actorId = req.user!.id;

    const data = AssignSubscriptionSchema.parse(req.body);

    const idempotencyKey = req.header('Idempotency-Key');
    if (!idempotencyKey?.trim()) throw new ValidationError('Idempotency-Key header is required');
    const subscription = await SubscriptionsService.assignSubscription(
      actorId,
      orgId,
      branchId,
      memberId,
      idempotencyKey,
      data,
    );

    res.status(201).json({ data: subscription });
  } catch (err) {
    next(err);
  }
}

export async function cancelSubscription(req: Request, res: Response, next: NextFunction) {
  try {
    const data = CancelSubscriptionSchema.parse(req.body);
    const subscription = await SubscriptionsService.cancelSubscription(
      req.user!.id,
      req.organization!.id,
      req.branch!.id,
      req.params.subscription_id,
      data,
    );
    res.json({ data: subscription });
  } catch (err) {
    next(err);
  }
}

export async function pauseSubscription(req: Request, res: Response, next: NextFunction) {
  try {
    const data = SubscriptionTransitionSchema.parse(req.body);
    const subscription = await SubscriptionsService.pauseSubscription(
      req.user!.id,
      req.organization!.id,
      req.branch!.id,
      req.params.subscription_id,
      data,
    );
    res.json({ data: subscription });
  } catch (err) {
    next(err);
  }
}

export async function resumeSubscription(req: Request, res: Response, next: NextFunction) {
  try {
    const data = SubscriptionTransitionSchema.parse(req.body);
    const subscription = await SubscriptionsService.resumeSubscription(
      req.user!.id,
      req.organization!.id,
      req.branch!.id,
      req.params.subscription_id,
      data,
    );
    res.json({ data: subscription });
  } catch (err) {
    next(err);
  }
}

export async function renewSubscription(req: Request, res: Response, next: NextFunction) {
  try {
    const data = RenewSubscriptionSchema.parse(req.body);
    const idempotencyKey = req.header('Idempotency-Key');
    if (!idempotencyKey?.trim()) throw new ValidationError('Idempotency-Key header is required');
    const subscription = await SubscriptionsService.renewSubscription(
      req.user!.id,
      req.organization!.id,
      req.branch!.id,
      req.params.subscription_id,
      idempotencyKey,
      data,
    );
    res.status(201).json({ data: subscription });
  } catch (err) {
    next(err);
  }
}

export async function listSubscriptions(req: Request, res: Response, next: NextFunction) {
  try {
    const orgId = req.organization!.id;
    const branchId = req.branch!.id;

    const permissions = req.permissions ?? new Set<string>();
    const canReadAll = permissions.has('ALL') || permissions.has('SUBSCRIPTION_READ_ALL');
    const subscriptions = await SubscriptionsService.listSubscriptions(
      orgId,
      branchId,
      req.member!.id,
      canReadAll,
    );
    res.json({ data: subscriptions });
  } catch (err) {
    next(err);
  }
}

export async function getSubscriptionDetail(req: Request, res: Response, next: NextFunction) {
  try {
    const orgId = req.organization!.id;
    const branchId = req.branch!.id;
    const subscriptionId = req.params.subscription_id;

    const subscription = await SubscriptionsService.getSubscriptionDetail(
      orgId,
      branchId,
      subscriptionId,
      req.member!.id,
      (req.permissions ?? new Set<string>()).has('ALL') ||
        (req.permissions ?? new Set<string>()).has('SUBSCRIPTION_READ_ALL'),
    );
    res.json({ data: subscription });
  } catch (err) {
    next(err);
  }
}

export async function updateSubscription(req: Request, res: Response, next: NextFunction) {
  try {
    const orgId = req.organization!.id;
    const branchId = req.branch!.id;
    const subscriptionId = req.params.subscription_id;
    const actorId = req.user!.id;

    const data = UpdateSubscriptionSchema.parse(req.body);

    const subscription = await SubscriptionsService.updateSubscription(
      actorId,
      orgId,
      branchId,
      subscriptionId,
      data,
    );

    res.json({ data: subscription });
  } catch (err) {
    next(err);
  }
}
