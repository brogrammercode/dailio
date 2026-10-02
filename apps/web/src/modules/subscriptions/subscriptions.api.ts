import { apiRequest } from "../../lib/api-client";
import type { SubscriptionDraft } from "../../types/domain";

export async function getSubscription(
  branchId: string,
  subscriptionId: string,
) {
  const body = await apiRequest<{ data: SubscriptionDraft }>(
    `/branches/${branchId}/subscriptions/${subscriptionId}`,
  );
  return body.data;
}
