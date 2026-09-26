import { purgeExpiredAttendanceEvidence, reviewOpenAttendanceSessions } from './attendance.service';

type MaintenanceJobStatus = {
  in_progress: boolean;
  last_started_at: string | null;
  last_succeeded_at: string | null;
  last_failed_at: string | null;
  consecutive_failures: number;
  last_result: Record<string, number> | null;
};

const retentionStatus: MaintenanceJobStatus = {
  in_progress: false,
  last_started_at: null,
  last_succeeded_at: null,
  last_failed_at: null,
  consecutive_failures: 0,
  last_result: null,
};

const reviewStatus: MaintenanceJobStatus = {
  in_progress: false,
  last_started_at: null,
  last_succeeded_at: null,
  last_failed_at: null,
  consecutive_failures: 0,
  last_result: null,
};

function start(status: MaintenanceJobStatus) {
  status.in_progress = true;
  status.last_started_at = new Date().toISOString();
}

function succeed(status: MaintenanceJobStatus, result: Record<string, number>) {
  status.in_progress = false;
  status.last_succeeded_at = new Date().toISOString();
  status.consecutive_failures = 0;
  status.last_result = result;
}

function fail(status: MaintenanceJobStatus) {
  status.in_progress = false;
  status.last_failed_at = new Date().toISOString();
  status.consecutive_failures += 1;
}

let retentionInFlight: ReturnType<typeof purgeExpiredAttendanceEvidence> | null = null;

export function runAttendanceRetentionMaintenance() {
  if (retentionInFlight) return retentionInFlight;
  retentionInFlight = (async () => {
    start(retentionStatus);
    try {
      const result = await purgeExpiredAttendanceEvidence();
      succeed(retentionStatus, { scanned: result.scanned, purged: result.purged });
      return result;
    } catch (error) {
      fail(retentionStatus);
      throw error;
    } finally {
      retentionInFlight = null;
    }
  })();
  return retentionInFlight;
}

let reviewInFlight: ReturnType<typeof reviewOpenAttendanceSessions> | null = null;

export function runAttendanceReviewMaintenance() {
  if (reviewInFlight) return reviewInFlight;
  reviewInFlight = (async () => {
    start(reviewStatus);
    try {
      const result = await reviewOpenAttendanceSessions();
      succeed(reviewStatus, { scanned: result.scanned, notified: result.notified });
      return result;
    } catch (error) {
      fail(reviewStatus);
      throw error;
    } finally {
      reviewInFlight = null;
    }
  })();
  return reviewInFlight;
}

export function getAttendanceMaintenanceStatus() {
  const jobs = {
    retention: { ...retentionStatus },
    open_session_review: { ...reviewStatus },
  };
  const hasFailure = Object.values(jobs).some((job) => job.consecutive_failures > 0);
  const hasRun = Object.values(jobs).every((job) => job.last_started_at !== null);
  return {
    status: hasFailure ? 'degraded' : hasRun ? 'ok' : 'starting',
    jobs,
  } as const;
}
