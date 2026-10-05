import { apiRequest } from "../../lib/api-client";
import { newIdempotencyKey } from "../../lib/idempotency";
import type { AttendanceSession, Invite } from "../../types/domain";

export type EvidenceInput = {
  latitude?: number;
  longitude?: number;
  accuracy?: number;
  selfie_storage_key?: string;
  selfie_upload_token?: string;
  selfie_content_type?: string;
  selfie_size_bytes?: number;
};

export async function qrPunch(
  token: string,
  evidence: EvidenceInput,
  policyVersion?: number,
) {
  const body = await apiRequest<{
    data: AttendanceSession;
    server_time: string;
  }>("/attendance/qr-punch", {
    method: "POST",
    headers: { "Idempotency-Key": newIdempotencyKey("web-qr-punch") },
    body: JSON.stringify({
      token,
      policy_version: policyVersion,
      timezone: Intl.DateTimeFormat().resolvedOptions().timeZone,
      client_time: new Date().toISOString(),
      device_info: { source: "web" },
      ...evidence,
    }),
  });
  return body.data;
}

export async function getActiveSession(branchId: string) {
  const body = await apiRequest<{
    session: AttendanceSession | null;
    server_time: string;
  }>(`/branches/${branchId}/attendance/active-session`);
  return body;
}

export async function getAttendance(branchId: string, period = "this_month") {
  const body = await apiRequest<{
    data: AttendanceSession[];
    meta?: { next_cursor?: string };
  }>(`/branches/${branchId}/attendance?period=${period}`);
  return body.data;
}

export async function createSelfieUploadSignature(
  branchId: string,
  filename: string,
) {
  const body = await apiRequest<{
    data: Record<string, string | number | null>;
  }>(`/branches/${branchId}/attendance/evidence/upload-signature`, {
    method: "POST",
    body: JSON.stringify({ filename, content_type: "image/jpeg" }),
  });
  return body.data;
}

export async function uploadAttendanceSelfie(
  signature: Record<string, string | number | null>,
  file: File,
) {
  const form = new FormData();
  form.append("file", file);
  form.append("api_key", String(signature.api_key ?? ""));
  form.append("timestamp", String(signature.timestamp ?? ""));
  form.append("signature", String(signature.signature ?? ""));
  form.append("folder", String(signature.folder ?? ""));
  form.append("public_id", String(signature.public_id ?? ""));
  form.append("type", String(signature.type ?? "authenticated"));
  const response = await fetch(
    `https://api.cloudinary.com/v1_1/${String(signature.cloud_name ?? "")}/image/upload`,
    { method: "POST", body: form },
  );
  if (!response.ok) throw new Error("Selfie upload failed.");
  return (await response.json()) as {
    public_id?: string;
    secure_url?: string;
    bytes?: number;
    format?: string;
  };
}

export function requiredAttendanceEvidence(invite: Invite) {
  const action =
    invite.attendance_action === "CLOCK_OUT" ? "clock_out" : "clock_in";
  const policy = invite.attendance_policy;
  return {
    selfie:
      action === "clock_out"
        ? Boolean(policy?.selfie_on_clock_out)
        : Boolean(policy?.selfie_on_clock_in),
    location:
      action === "clock_out"
        ? Boolean(policy?.location_on_clock_out || policy?.geofence_enabled)
        : Boolean(policy?.location_on_clock_in || policy?.geofence_enabled),
  };
}

export async function serveMealFromInvite(token: string, mealSlotId: string) {
  const body = await apiRequest<{ data: Record<string, unknown> }>(
    `/meal-attendance-invites/${token}/serve`,
    {
      method: "POST",
      headers: { "Idempotency-Key": newIdempotencyKey("web-meal-qr") },
      body: JSON.stringify({ meal_slot_id: mealSlotId }),
    },
  );
  return body.data;
}
