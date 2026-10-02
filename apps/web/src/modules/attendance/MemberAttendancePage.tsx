import { useEffect, useMemo, useState, type ReactNode } from "react";
import { MinimalLoading, StateCard } from "../../components/feedback/StateCard";
import { Icon } from "../../components/ui/Icon";
import { safeMessage } from "../../lib/errors";
import { getContext } from "../../lib/session";
import { getActiveSession, getAttendance } from "./attendance.api";
import type { AttendancePolicy, AttendanceSession } from "../../types/domain";

type AttendanceTab = "today" | "record";

function formatTime(value: string | null | undefined, timezone?: string) {
  if (!value) return "--:--";
  return new Intl.DateTimeFormat("en-IN", {
    hour: "2-digit",
    minute: "2-digit",
    hour12: true,
    timeZone: timezone,
  }).format(new Date(value));
}

function formatDate(date: Date, timezone?: string) {
  return new Intl.DateTimeFormat("en-IN", {
    month: "short",
    day: "2-digit",
    year: "numeric",
    weekday: "long",
    timeZone: timezone,
  }).format(date);
}

function formatDuration(minutes: number | null | undefined) {
  if (minutes === null || minutes === undefined || Number.isNaN(minutes))
    return "--:--";
  const hours = Math.floor(minutes / 60);
  const remaining = Math.max(0, minutes % 60);
  return hours ? `${hours}h ${remaining}m` : `${remaining}m`;
}

function elapsedMinutes(session: AttendanceSession | null) {
  if (!session?.clock_in_at || session.clock_out_at) return null;
  return Math.max(
    0,
    Math.floor((Date.now() - new Date(session.clock_in_at).getTime()) / 60_000),
  );
}

function PolicyItem({
  icon,
  label,
  value,
  required,
}: {
  icon: ReactNode;
  label: string;
  value: string;
  required?: boolean;
}) {
  return (
    <div className="min-w-0 text-center">
      <div className="mx-auto flex h-8 items-center justify-center text-xl text-brand">
        <span className="inline-flex text-brand">{icon}</span>
      </div>
      <p className="mt-1 truncate text-[11px] text-slate-500">{label}</p>
      <p
        className={`mt-0.5 text-[11px] font-semibold ${required ? "text-brand" : "text-ink"}`}
      >
        {value}
      </p>
    </div>
  );
}

function policyValues(policy: AttendancePolicy | null | undefined) {
  if (!policy)
    return {
      location: "—",
      selfie: "—",
      geofence: "—",
      lateGrace: "—",
      qr: "—",
      locationRequired: false,
      selfieRequired: false,
      geofenceRequired: false,
      qrRequired: false,
    };
  const locationRequired = Boolean(
    policy.location_on_clock_in || policy.location_on_clock_out,
  );
  const selfieRequired = Boolean(
    policy.selfie_on_clock_in || policy.selfie_on_clock_out,
  );
  const qrRequired = Boolean(
    policy.qr_scan_on_clock_in || policy.qr_scan_on_clock_out,
  );
  return {
    location: locationRequired ? "Required" : "Optional",
    selfie: selfieRequired ? "Required" : "Optional",
    geofence: policy.geofence_enabled ? "On" : "Off",
    lateGrace: policy.late_grace_minutes
      ? `${policy.late_grace_minutes} min`
      : "—",
    qr: qrRequired ? "Required" : "Optional",
    locationRequired,
    selfieRequired,
    geofenceRequired: Boolean(policy.geofence_enabled),
    qrRequired,
  };
}

export function MemberAttendancePage() {
  const context = getContext();
  const [active, setActive] = useState<AttendanceSession | null>(null);
  const [records, setRecords] = useState<AttendanceSession[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const [tab, setTab] = useState<AttendanceTab>("today");

  useEffect(() => {
    if (!context) {
      setLoading(false);
      return;
    }
    setLoading(true);
    Promise.all([
      getActiveSession(context.branchId),
      getAttendance(context.branchId),
    ])
      .then(([session, list]) => {
        setActive(session.session);
        setRecords(list);
        setError(null);
      })
      .catch((cause) => setError(safeMessage(cause)))
      .finally(() => setLoading(false));
  }, [context?.branchId]);

  const policy = active?.policy_snapshot;
  const values = useMemo(() => policyValues(policy), [policy]);
  const now = new Date();
  const totalMinutes = active?.worked_minutes ?? elapsedMinutes(active);
  const latest = records[0];

  if (!context)
    return (
      <StateCard
        title="Choose your branch"
        message="Open a branch QR to establish a secure member context."
      />
    );
  if (loading) return <MinimalLoading label="Loading attendance" />;
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
            type="button"
          >
            Retry
          </button>
        }
      />
    );

  return (
    <div className="attendance-page">
      <div
        className="attendance-tabs"
        role="tablist"
        aria-label="Attendance views"
      >
        <button
          aria-selected={tab === "today"}
          className={
            tab === "today" ? "attendance-tab active" : "attendance-tab"
          }
          onClick={() => setTab("today")}
          role="tab"
          type="button"
        >
          Today
        </button>
        <button
          aria-selected={tab === "record"}
          className={
            tab === "record" ? "attendance-tab active" : "attendance-tab"
          }
          onClick={() => setTab("record")}
          role="tab"
          type="button"
        >
          Attendance record
        </button>
      </div>

      {tab === "today" ? (
        <TodayAttendance
          active={active}
          date={formatDate(now, context.timezone)}
          latest={latest}
          policy={policy}
          time={new Intl.DateTimeFormat("en-IN", {
            hour: "2-digit",
            minute: "2-digit",
            hour12: true,
            timeZone: context.timezone,
          }).format(now)}
          timezone={context.timezone}
          totalMinutes={totalMinutes}
          values={values}
        />
      ) : (
        <AttendanceRecord records={records} timezone={context.timezone} />
      )}
    </div>
  );
}

function TodayAttendance({
  active,
  date,
  latest,
  policy,
  time,
  totalMinutes,
  timezone,
  values,
}: {
  active: AttendanceSession | null;
  date: string;
  latest: AttendanceSession | undefined;
  policy: AttendancePolicy | null | undefined;
  time: string;
  timezone?: string;
  totalMinutes: number | null | undefined;
  values: ReturnType<typeof policyValues>;
}) {
  const session = active ?? latest;
  const isOpen = Boolean(active);
  const action = isOpen ? "Clock out" : "Clock in";
  return (
    <div className="space-y-6 pb-5">
      <section className="text-center">
        <p className="attendance-time">{time}</p>
        <p className="mt-2 text-sm text-slate-500">{date}</p>
      </section>

      <section className="flex justify-center">
        <div className="attendance-action-ring" aria-label={`${action} status`}>
          <span className="attendance-ring ring-one" />
          <span className="attendance-ring ring-two" />
          <span className="attendance-ring ring-three" />
          <span className="attendance-ring ring-four" />
          <div className="attendance-action-core">
            <Icon name={isOpen ? "log-out" : "log-in"} size={36} />
            <span className="mt-1 text-base font-medium text-ink">
              {action}
            </span>
            <span className="mt-1 text-[11px] text-slate-500">
              Scan gate QR
            </span>
          </div>
        </div>
      </section>

      <section className="grid grid-cols-3 gap-3 text-center">
        <Metric
          value={formatTime(session?.clock_in_at)}
          label="Check in"
          icon={<Icon name="log-in" size={24} />}
        />
        <Metric
          value={formatTime(session?.clock_out_at)}
          label="Check out"
          icon={<Icon name="log-out" size={24} />}
        />
        <Metric
          value={formatDuration(totalMinutes)}
          label="Total hrs"
          icon={<Icon name="clock" size={24} />}
        />
      </section>

      <section className="attendance-panel">
        <h2 className="text-base font-semibold">
          Policy applied to this punch
        </h2>
        <div className="mt-5 grid grid-cols-5 gap-1">
          <PolicyItem
            icon={<Icon name="location" size={20} />}
            label="Location"
            value={values.location}
            required={values.locationRequired}
          />
          <PolicyItem
            icon={<Icon name="camera" size={20} />}
            label="Selfie"
            value={values.selfie}
            required={values.selfieRequired}
          />
          <PolicyItem
            icon={<Icon name="geofence" size={20} />}
            label="Geofence"
            value={values.geofence}
            required={values.geofenceRequired}
          />
          <PolicyItem
            icon={<Icon name="clock" size={20} />}
            label="Late grace"
            value={values.lateGrace}
          />
          <PolicyItem
            icon={<Icon name="qr" size={20} />}
            label="QR scan"
            value={values.qr}
            required={values.qrRequired}
          />
        </div>
        {!policy && (
          <p className="mt-4 text-center text-xs text-slate-500">
            The active branch policy will be shown when the server returns it.
          </p>
        )}
      </section>

      <Timeline active={active} latest={latest} timezone={timezone} />
    </div>
  );
}

function Metric({
  icon,
  label,
  value,
}: {
  icon: ReactNode;
  label: string;
  value: string;
}) {
  return (
    <div>
      <span className="inline-flex text-brand">{icon}</span>
      <p className="mt-1 text-sm font-medium text-ink">{value}</p>
      <p className="mt-1 text-xs text-slate-500">{label}</p>
    </div>
  );
}

function Timeline({
  active,
  latest,
  timezone,
}: {
  active: AttendanceSession | null;
  latest: AttendanceSession | undefined;
  timezone?: string;
}) {
  const session = active ?? latest;
  return (
    <section className="attendance-panel">
      <div className="flex items-center justify-between">
        <h2 className="text-base font-semibold">Today’s timeline</h2>
        <span className="status-badge">{active ? "ONGOING" : "RECORDED"}</span>
      </div>
      {!session ? (
        <p className="mt-5 text-sm text-slate-500">
          No attendance recorded today.
        </p>
      ) : (
        <div className="timeline mt-5">
          <div className="timeline-row">
            <span className="timeline-dot">
              <Icon name="log-in" size={16} />
            </span>
            <span className="font-medium">Clocked in</span>
            <time className="ml-auto text-sm text-slate-500">
              {formatTime(session.clock_in_at, timezone)}
            </time>
          </div>
          <div className="timeline-row">
            <span className="timeline-dot">
              <Icon name="clock" size={16} />
            </span>
            <span className="font-medium">
              {active ? "In progress" : "Completed"}
            </span>
            <span className="ml-auto text-right text-sm text-slate-500">
              {active
                ? `${formatDuration(elapsedMinutes(active))} · awaiting clock-out`
                : formatTime(session.clock_out_at, timezone)}
            </span>
          </div>
        </div>
      )}
    </section>
  );
}

function AttendanceRecord({
  records,
  timezone,
}: {
  records: AttendanceSession[];
  timezone?: string;
}) {
  return (
    <section className="space-y-3 pb-5">
      {records.length === 0 ? (
        <StateCard
          title="No attendance yet"
          message="Your confirmed attendance records will appear here."
        />
      ) : (
        records.map((record) => (
          <div className="attendance-record-row" key={record.id}>
            <div>
              <p className="font-medium text-ink">
                {record.clock_in_at
                  ? new Intl.DateTimeFormat("en-IN", {
                      day: "2-digit",
                      month: "short",
                      year: "numeric",
                      timeZone: timezone,
                    }).format(new Date(record.clock_in_at))
                  : "Attendance"}
              </p>
              <p className="mt-1 text-xs text-slate-500">
                {record.derived_status ?? record.state}
              </p>
            </div>
            <div className="text-right text-sm text-slate-500">
              <p>{formatTime(record.clock_in_at, timezone)}</p>
              <p className="mt-1">{formatDuration(record.worked_minutes)}</p>
            </div>
          </div>
        ))
      )}
    </section>
  );
}
