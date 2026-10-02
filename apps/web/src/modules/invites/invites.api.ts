import { apiRequest } from "../../lib/api-client";
import type { Invite, SubscriptionDraft } from "../../types/domain";

export async function resolveInvite(token: string) {
  const body = await apiRequest<{ data: Invite; server_time: string }>(
    `/invites/${encodeURIComponent(token)}`,
  );
  return body.data;
}

export async function submitJoinRequest(
  token: string,
  idempotencyKey: string,
  message?: string,
) {
  const body = await apiRequest<{ data: { id: string; status: string } }>(
    `/join-invites/${encodeURIComponent(token)}/requests`,
    {
      method: "POST",
      headers: { "Idempotency-Key": idempotencyKey },
      body: JSON.stringify(message ? { message } : {}),
    },
  );
  return body.data;
}

export async function createSubscriptionDraft(
  token: string,
  idempotencyKey: string,
  startDate: string,
) {
  const body = await apiRequest<{ data: SubscriptionDraft }>(
    `/purchase-invites/${encodeURIComponent(token)}/subscription-drafts`,
    {
      method: "POST",
      headers: { "Idempotency-Key": idempotencyKey },
      body: JSON.stringify({ start_date: startDate }),
    },
  );
  return body.data;
}
