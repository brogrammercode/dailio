import { useState } from "react";
import { SelfieCapture } from "../../components/media/SelfieCapture";
import { StateCard } from "../../components/feedback/StateCard";
import { readBrowserLocation } from "../../lib/browser-capabilities";
import { safeMessage } from "../../lib/errors";
import { setContext } from "../../lib/session";
import { contextFromInvite } from "../branches/branches.api";
import {
  createSelfieUploadSignature,
  qrPunch,
  requiredAttendanceEvidence,
  uploadAttendanceSelfie,
} from "./attendance.api";
import type { Invite, AttendanceSession } from "../../types/domain";

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
  const requirements = requiredAttendanceEvidence(invite);
  const action =
    invite.attendance_action === "CLOCK_OUT" ? "Clock out" : "Clock in";
  setContext(contextFromInvite(invite));

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
  return (
    <div className="space-y-5">
      <div>
        <p className="section-title">Gate attendance</p>
        <h2 className="mt-2 text-3xl font-semibold">{action}</h2>
        <p className="mt-2 text-sm text-slate-600">
          {invite.organization.name} · {invite.branch.name}
        </p>
      </div>
      <section className="card space-y-4 p-5">
        <div>
          <p className="text-sm font-semibold">Server-confirmed next action</p>
          <p className="mt-1 text-2xl font-semibold text-brand">{action}</p>
        </div>
        <div className="grid gap-3 text-sm text-slate-600">
          <p>
            Branch time zone:{" "}
            <strong className="text-ink">{invite.branch.timezone}</strong>
          </p>
          {invite.attendance_policy?.shift && (
            <p>
              Shift:{" "}
              <strong className="text-ink">
                {invite.attendance_policy.shift.name}
              </strong>
            </p>
          )}
          <p>
            Required evidence:{" "}
            <strong className="text-ink">
              {[
                requirements.selfie && "live selfie",
                requirements.location && "fresh location",
              ]
                .filter(Boolean)
                .join(" + ") || "none"}
            </strong>
          </p>
        </div>
      </section>
      {requirements.selfie && (
        <section className="space-y-3">
          <p className="section-title">Live evidence</p>
          {selfie ? (
            <StateCard
              title="Selfie captured"
              message="The image is ready for this one attendance attempt."
              tone="success"
              action={
                <button
                  className="secondary-button w-full"
                  onClick={() => setSelfie(null)}
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
      {
        <button
          className="primary-button w-full"
          disabled={busy}
          onClick={() => void submit()}
        >
          {busy ? "Confirming…" : `Confirm ${action}`}
        </button>
      }
      <p className="text-center text-xs leading-5 text-slate-500">
        Dailio uses the server timestamp. A browser retry is safe and will not
        create a duplicate session.
      </p>
    </div>
  );
}
