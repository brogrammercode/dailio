import { describe, expect, it, vi } from 'vitest';

const coordinatorMock = vi.hoisted(() => vi.fn());
vi.mock('../../config/env', () => ({ env: { CRON_SECRET: 'cron-secret' } }));
vi.mock('./daily-jobs.service', () => ({ runDailyNotificationCoordinator: coordinatorMock }));

import { runDailyCronHandler } from './daily-jobs.controller';

describe('daily cron controller', () => {
  it('rejects requests without the configured secret', async () => {
    const next = vi.fn();
    await runDailyCronHandler({ headers: {} } as never, {} as never, next);
    expect(next).toHaveBeenCalledWith(expect.objectContaining({ code: 'FORBIDDEN' }));
    expect(coordinatorMock).not.toHaveBeenCalled();
  });

  it('runs the coordinator with a valid bearer secret', async () => {
    coordinatorMock.mockResolvedValue({ status: 'completed' });
    const json = vi.fn();
    const res = { status: vi.fn().mockReturnThis(), json };
    await runDailyCronHandler(
      { headers: { authorization: 'Bearer cron-secret' } } as never,
      res as never,
      vi.fn(),
    );
    expect(coordinatorMock).toHaveBeenCalledOnce();
    expect(res.status).toHaveBeenCalledWith(200);
    expect(json).toHaveBeenCalledWith({ data: { status: 'completed' } });
  });
});
