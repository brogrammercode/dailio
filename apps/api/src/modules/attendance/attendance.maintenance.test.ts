import { beforeEach, describe, expect, it, vi } from 'vitest';

const serviceMock = vi.hoisted(() => ({
  purgeExpiredAttendanceEvidence: vi.fn(),
  reviewOpenAttendanceSessions: vi.fn(),
}));

vi.mock('./attendance.service', () => serviceMock);

import {
  getAttendanceMaintenanceStatus,
  runAttendanceRetentionMaintenance,
  runAttendanceReviewMaintenance,
} from './attendance.maintenance';

describe('attendance maintenance status', () => {
  beforeEach(() => {
    vi.resetAllMocks();
    serviceMock.purgeExpiredAttendanceEvidence.mockResolvedValue({
      scanned: 2,
      purged: 1,
    });
    serviceMock.reviewOpenAttendanceSessions.mockResolvedValue({
      scanned: 3,
      notified: 1,
    });
  });

  it('records safe success summaries for both maintenance jobs', async () => {
    await runAttendanceRetentionMaintenance();
    await runAttendanceReviewMaintenance();

    const status = getAttendanceMaintenanceStatus();
    expect(status.status).toBe('ok');
    expect(status.jobs.retention).toMatchObject({
      consecutive_failures: 0,
      last_result: { scanned: 2, purged: 1 },
    });
    expect(status.jobs.open_session_review).toMatchObject({
      consecutive_failures: 0,
      last_result: { scanned: 3, notified: 1 },
    });
  });

  it('reports degraded state without exposing the raw failure', async () => {
    serviceMock.purgeExpiredAttendanceEvidence.mockRejectedValueOnce(
      new Error('database password must not be exposed'),
    );

    await expect(runAttendanceRetentionMaintenance()).rejects.toThrow(
      'database password must not be exposed',
    );

    const status = getAttendanceMaintenanceStatus();
    expect(status.status).toBe('degraded');
    expect(status.jobs.retention.consecutive_failures).toBeGreaterThan(0);
    expect(JSON.stringify(status)).not.toContain('database password');
  });

  it('deduplicates overlapping triggers for each job', async () => {
    let resolveRetention!: (value: { scanned: number; purged: number }) => void;
    serviceMock.purgeExpiredAttendanceEvidence.mockReturnValueOnce(
      new Promise((resolve) => {
        resolveRetention = resolve;
      }),
    );

    const first = runAttendanceRetentionMaintenance();
    const second = runAttendanceRetentionMaintenance();
    expect(first).toBe(second);
    expect(serviceMock.purgeExpiredAttendanceEvidence).toHaveBeenCalledTimes(1);

    resolveRetention({ scanned: 1, purged: 0 });
    await first;

    let resolveReview!: (value: { scanned: number; notified: number }) => void;
    serviceMock.reviewOpenAttendanceSessions.mockReturnValueOnce(
      new Promise((resolve) => {
        resolveReview = resolve;
      }),
    );
    const reviewFirst = runAttendanceReviewMaintenance();
    const reviewSecond = runAttendanceReviewMaintenance();
    expect(reviewFirst).toBe(reviewSecond);
    expect(serviceMock.reviewOpenAttendanceSessions).toHaveBeenCalledTimes(1);
    resolveReview({ scanned: 1, notified: 0 });
    await reviewFirst;
  });
});
