import { useEffect, useState } from "react";
import { LoadingCard, StateCard } from "../../components/feedback/StateCard";
import { safeMessage } from "../../lib/errors";
import { getContext } from "../../lib/session";
import { getActiveSession, getAttendance } from "./attendance.api";
import type { AttendanceSession } from "../../types/domain";

export function MemberAttendancePage() {
  const context = getContext();
  const [active, setActive] = useState<AttendanceSession | null>(null);
  const [records, setRecords] = useState<AttendanceSession[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  useEffect(() => {
    if (!context) {
      setLoading(false);
      return;
    }
    Promise.all([
      getActiveSession(context.branchId),
      getAttendance(context.branchId),
    ])
      .then(([session, list]) => {
        setActive(session.session);
        setRecords(list);
      })
      .catch((cause) => setError(safeMessage(cause)))
      .finally(() => setLoading(false));
  }, [context?.branchId]);
  if (!context)
    return (
      <StateCard
        title="Choose your branch"
        message="Open a branch QR to establish a secure member context."
      />
    );
  if (loading) return <LoadingCard label="Loading attendance" />;
  if (error)
    return (
      <StateCard
        title="Attendance unavailable"
        message={error}
        tone="error"
        action={
          <button
            className="secondary-button w-full"
            onClick={() => window.location.reload()}
          >
            Retry
          </button>
        }
      />
    );
  return (
    <div className="space-y-5">
      <div>
        <p className="section-title">Self attendance</p>
        <h2 className="mt-2 text-3xl font-semibold">
          {active ? "You are checked in" : "Ready when you are"}
        </h2>
        <p className="mt-2 text-sm text-slate-600">
          Use the permanent gate QR at the branch to perform your next
          server-confirmed punch.
        </p>
      </div>
      <section
        className={`card p-5 ${active ? "border-brand bg-brand-soft" : ""}`}
      >
        <p className="text-sm font-semibold">Today</p>
        {active ? (
          <>
            <p className="mt-2 text-2xl font-semibold text-brand">
              Open session
            </p>
            <p className="mt-2 text-sm text-slate-600">
              Clocked in at{" "}
              {active.clock_in_at
                ? new Date(active.clock_in_at).toLocaleTimeString([], {
                    hour: "2-digit",
                    minute: "2-digit",
                  })
                : "server time"}
              .
            </p>
          </>
        ) : (
          <p className="mt-2 text-sm text-slate-600">
            No open attendance session.
          </p>
        )}
      </section>
      <section className="space-y-3">
        <p className="section-title">Recent record</p>
        {records.length === 0 ? (
          <StateCard
            title="No attendance yet"
            message="Your confirmed attendance records will appear here."
          />
        ) : (
          records.slice(0, 5).map((record) => (
            <div
              className="card flex items-center justify-between p-4"
              key={record.id}
            >
              <div>
                <p className="font-semibold">
                  {record.clock_in_at
                    ? new Date(record.clock_in_at).toLocaleDateString()
                    : "Attendance"}
                </p>
                <p className="mt-1 text-xs text-slate-500">
                  {record.derived_status ?? record.state}
                </p>
              </div>
              <span className="text-sm text-slate-600">
                {record.clock_in_at
                  ? new Date(record.clock_in_at).toLocaleTimeString([], {
                      hour: "2-digit",
                      minute: "2-digit",
                    })
                  : "—"}
              </span>
            </div>
          ))
        )}
      </section>
    </div>
  );
}
