import { apiRequest } from "../../lib/api-client";
import { newIdempotencyKey } from "../../lib/idempotency";

export type MealSlot = {
  id: string;
  code: string;
  name: string;
  starts_at_local: string;
  ends_at_local: string;
  is_active: boolean;
};
export type MealServing = {
  id: string;
  status: "CONFIRMED" | "VOID";
  local_date: string;
  served_at: string;
  serving_number: number;
  meal_slot: { name: string };
  member: { user: { name: string }; member_number?: string | null };
};
export type MealMember = {
  id: string;
  member_number?: string | null;
  user: { name: string };
};
export type MealEligibility = {
  entitled: boolean;
  eligible: boolean;
  window_open: boolean;
  served_count: number;
  remaining: number;
  max_servings_per_day: number;
};
export type MealEntitlement = {
  meal_slot_id: string;
  max_servings_per_day: number;
  is_active: boolean;
};
export type MealPlan = { id: string; name: string };
export type MealSummary = {
  from: string;
  to: string;
  member_id: string | null;
  total: number;
  slots: { meal_slot_id: string; name: string; code: string; count: number }[];
};

export async function listMealSlots(branchId: string) {
  const body = await apiRequest<{ data: MealSlot[] }>(
    `/branches/${branchId}/meal-slots`,
  );
  return body.data;
}
export async function listMealServings(
  branchId: string,
  page = 1,
  memberId?: string,
) {
  const query = new URLSearchParams({ page: String(page), limit: "30" });
  if (memberId) query.set("member_id", memberId);
  return apiRequest<{
    data: MealServing[];
    meta: { total: number; page: number; limit: number };
  }>(`/branches/${branchId}/meal-servings?${query.toString()}`);
}
export async function getMealSummary(branchId: string, memberId?: string) {
  const query = memberId ? `?member_id=${encodeURIComponent(memberId)}` : "";
  const body = await apiRequest<{ data: MealSummary }>(
    `/branches/${branchId}/meal-servings/summary${query}`,
  );
  return body.data;
}
export async function searchMealMembers(branchId: string, query: string) {
  const body = await apiRequest<{ data: MealMember[] }>(
    `/branches/${branchId}/meal-members?query=${encodeURIComponent(query)}`,
  );
  return body.data;
}
export async function getMealEligibility(
  branchId: string,
  slotId: string,
  memberId?: string,
) {
  const query = memberId ? `?member_id=${encodeURIComponent(memberId)}` : "";
  const body = await apiRequest<{ data: MealEligibility }>(
    `/branches/${branchId}/meal-slots/${slotId}/eligibility${query}`,
  );
  return body.data;
}
export async function serveMeal(
  branchId: string,
  memberId: string,
  slotId: string,
) {
  const body = await apiRequest<{ data: MealServing }>(
    `/branches/${branchId}/meal-servings`,
    {
      method: "POST",
      headers: { "Idempotency-Key": newIdempotencyKey("web-meal-serving") },
      body: JSON.stringify({ member_id: memberId, meal_slot_id: slotId }),
    },
  );
  return body.data;
}
export async function voidMeal(
  branchId: string,
  servingId: string,
  reason: string,
) {
  const body = await apiRequest<{ data: MealServing }>(
    `/branches/${branchId}/meal-servings/${servingId}/void`,
    { method: "POST", body: JSON.stringify({ reason }) },
  );
  return body.data;
}
export async function saveMealSlot(
  branchId: string,
  input: Omit<MealSlot, "id">,
  slotId?: string,
) {
  const body = await apiRequest<{ data: MealSlot }>(
    `/branches/${branchId}/meal-slots${slotId ? `/${slotId}` : ""}`,
    { method: slotId ? "PUT" : "POST", body: JSON.stringify(input) },
  );
  return body.data;
}
export async function listMealPlans(organizationId: string) {
  const body = await apiRequest<{ data: MealPlan[] }>(
    `/organizations/${organizationId}/plans`,
  );
  return body.data;
}
export async function listMealEntitlements(branchId: string, planId: string) {
  const body = await apiRequest<{ data: MealEntitlement[] }>(
    `/branches/${branchId}/plans/${planId}/meal-entitlements`,
  );
  return body.data;
}
export async function setMealEntitlement(
  branchId: string,
  planId: string,
  input: MealEntitlement,
) {
  const body = await apiRequest<{ data: MealEntitlement }>(
    `/branches/${branchId}/plans/${planId}/meal-entitlements`,
    { method: "PUT", body: JSON.stringify(input) },
  );
  return body.data;
}
