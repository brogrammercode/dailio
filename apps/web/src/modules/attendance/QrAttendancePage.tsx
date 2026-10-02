import { useEffect, useMemo, useState } from "react";
import { SelfieCapture } from "../../components/media/SelfieCapture";
import { MinimalLoading, StateCard } from "../../components/feedback/StateCard";
import { Icon } from "../../components/ui/Icon";
import { readBrowserLocation } from "../../lib/browser-capabilities";
import { safeMessage } from "../../lib/errors";
import { setContext } from "../../lib/session";
import { contextFromInvite } from "../branches/branches.api";
import {
  createSelfieUploadSignature,
  getActiveSession,
  getAttendance,
  qrPunch,
  requiredAttendanceEvidence,
  uploadAttendanceSelfie,
} from "./attendance.api";
import type { ReactNode } from "react";
import type {
  AttendancePolicy,
  AttendanceSession,
  Invite,
} from "../../types/domain";

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

function policyValues(
  policy: AttendancePolicy | null | undefined,
  requirements: ReturnType<typeof requiredAttendanceEvidence>,
) {
  return {
    location: requirements.location ? "Required" : "Optional",
    selfie: requirements.selfie ? "Required" : "Optional",
    geofence: policy?.geofence_enabled ? "On" : "Off",
    lateGrace: policy?.late_grace_minutes
      ? `${policy.late_grace_minutes} min`
      : "--",
    qr: "Required",
    locationRequired: requirements.location,
    selfieRequired: requirements.selfie,
    geofenceRequired: Boolean(policy?.geofence_enabled),
    qrRequired: true,
  };
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
        {icon}
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

export function QrAttendancePage({
  token,
  invite,
  onDone,
}: {
  token: string;
  invite: Invite;
  onDone: (session: AttendanceSession) => void;
}) {
  const [selfie, setSelfie] = useState<File | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [active, setActive] = useState<AttendanceSession | null>(null);
  const [records, setRecords] = useState<AttendanceSession[]>([]);
  const [loading, setLoading] = useState(true);
  const [tab, setTab] = useState<AttendanceTab>("today");
  const requirements = requiredAttendanceEvidence(invite);
  const action =
    invite.attendance_action === "CLOCK_OUT" ? "Clock out" : "Clock in";
  const context = useMemo(() => contextFromInvite(invite), [invite]);

  useEffect(() => {
    setContext(context);
  }, [context]);

  useEffect(() => {
    let mounted = true;
    setLoading(true);
    Promise.all([
      getActiveSession(invite.branch.id),
      getAttendance(invite.branch.id),
    ])
      .then(([session, attendance]) => {
        if (!mounted) return;
        setActive(session.session);
        setRecords(attendance);
        setError(null);
      })
      .catch((cause) => {
        if (mounted) setError(safeMessage(cause, "Attendance is unavailable."));
      })
      .finally(() => {
        if (mounted) setLoading(false);
      });
    return () => {
      mounted = false;
    };
  }, [invite.branch.id]);

  const policy = active?.policy_snapshot ?? invite.attendance_policy;
  const values = useMemo(
    () => policyValues(policy, requirements),
    [policy, requirements.location, requirements.selfie],
  );
  const now = new Date();
  const latest = records[0];
  const totalMinutes = active?.worked_minutes ?? elapsedMinutes(active);

  async function submit() {
    setBusy(true);
    setError(null);
    try {
      const evidence: Record<string, string | number> = {};
      if (requirements.location)
        Object.assign(evidence, await readBrowserLocation());
      if (requirements.selfie) {
        if (!selfie)
          throw new Error(
            "A live selfie is required before attendance can be submitted.",
          );
        const signature = await createSelfieUploadSignature(
          invite.branch.id,
          selfie.name,
        );
        const upload = await uploadAttendanceSelfie(signature, selfie);
        evidence.selfie_storage_key = String(
          signature.storage_key ?? upload.public_id ?? "",
        );
        evidence.selfie_upload_token = String(signature.upload_token ?? "");
        evidence.selfie_content_type = selfie.type;
        evidence.selfie_size_bytes = selfie.size;
      }
      onDone(await qrPunch(token, evidence, invite.attendance_policy?.version));
    } catch (cause) {
      setError(safeMessage(cause, "Attendance could not be confirmed."));
    } finally {
      setBusy(false);
    }
  }

  if (
    invite.attendance_action === "ATTENDANCE_DISABLED" ||
    invite.joinability !== "ALREADY_MEMBER"
  )
    return (
      <StateCard
        title="Attendance is unavailable"
        message="This QR can be used for branch access, but the server has not allowed an attendance punch for this account."
      />
    );

  if (loading) return <MinimalLoading label="Loading attendance" />;

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
        <div className="space-y-6 pb-5">
          <section className="text-center">
            <p className="attendance-time">
              {new Intl.DateTimeFormat("en-IN", {
                hour: "2-digit",
                minute: "2-digit",
                hour12: true,
                timeZone: invite.branch.timezone,
              }).format(now)}
            </p>
            <p className="mt-2 text-sm text-slate-500">
              {formatDate(now, invite.branch.timezone)}
            </p>
          </section>

          <section className="flex justify-center">
            <div
              className="attendance-action-ring"
              aria-label={`${action} status`}
            >
              <span className="attendance-ring ring-one" />
              <span className="attendance-ring ring-two" />
              <span className="attendance-ring ring-three" />
              <span className="attendance-ring ring-four" />
              <button
                aria-label={`Confirm ${action}`}
                className="attendance-action-core border-0 p-0"
                disabled={busy || (requirements.selfie && !selfie)}
                onClick={() => void submit()}
                type="button"
              >
                <Icon
                  name={action === "Clock out" ? "log-out" : "log-in"}
                  size={36}
                />
                <span className="mt-1 text-base font-medium text-ink">
                  {action}
                </span>
                <span className="mt-1 text-[11px] text-slate-500">
                  Confirm below
                </span>
              </button>
            </div>
          </section>

          <section className="grid grid-cols-3 gap-3 text-center">
            <Metric
              value={formatTime(active?.clock_in_at ?? latest?.clock_in_at)}
              label="Check in"
              icon={<Icon name="log-in" size={24} />}
            />
            <Metric
              value={formatTime(active?.clock_out_at ?? latest?.clock_out_at)}
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
          </section>

          {requirements.selfie && (
            <section className="attendance-panel space-y-3">
              <h2 className="text-base font-semibold">Live selfie required</h2>
              {selfie ? (
                <StateCard
                  title="Selfie captured"
                  message="The image is ready for this attendance attempt."
                  tone="success"
                  action={
                    <button
                      className="secondary-button w-full"
                      onClick={() => setSelfie(null)}
                      type="button"
                    >
                      Capture again
                    </button>
                  }
                />
              ) : (
                <SelfieCapture onCapture={setSelfie} />
              )}
            </section>
          )}

          {error && (
            <StateCard title="Could not submit" message={error} tone="error" />
          )}
          <button
            className="primary-button w-full"
            disabled={busy}
            onClick={() => void submit()}
            type="button"
          >
            {busy ? "Confirming..." : `Confirm ${action}`}
          </button>

          <Timeline
            active={active}
            latest={latest}
            timezone={invite.branch.timezone}
          />
          <p className="text-center text-xs leading-5 text-slate-500">
            Dailio uses the server timestamp. A browser retry is safe and will
            not create a duplicate session.
          </p>
        </div>
      ) : (
        <AttendanceRecord records={records} timezone={invite.branch.timezone} />
      )}
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
        <h2 className="text-base font-semibold">Today's timeline</h2>
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
                ? `${formatDuration(elapsedMinutes(active))} - awaiting clock-out`
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
