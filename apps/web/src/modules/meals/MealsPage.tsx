import { useEffect, useRef, useState } from "react";

import { LoadingCard, StateCard } from "../../components/feedback/StateCard";
import { ConfirmAction } from "../../components/feedback/ConfirmAction";
import { PickerField } from "../../components/ui/PickerField";
import { safeMessage } from "../../lib/errors";
import { getContext } from "../../lib/session";
import {
  getMealEligibility,
  getMealSummary,
  listMealEntitlements,
  listMealPlans,
  listMealServings,
  listMealSlots,
  saveMealSlot,
  searchMealMembers,
  serveMeal,
  setMealEntitlement,
  voidMeal,
  type MealEligibility,
  type MealEntitlement,
  type MealMember,
  type MealPlan,
  type MealServing,
  type MealSummary,
  type MealSlot,
} from "./meals.api";

type Tab = "history" | "register" | "configure";

export function MealsPage() {
  const context = getContext();
  const branchId = context?.branchId ?? "";
  const permissions = context?.permissions ?? [];
  const can = (name: string) =>
    permissions.includes("ALL") || permissions.includes(name);
  const canServe = can("MEAL_SERVE");
  const canReadBranch = can("MEAL_READ_BRANCH");
  const canRead = can("MEAL_READ_SELF") || canReadBranch;
  const canManage = can("MEAL_MANAGE");
  const canVoid = can("MEAL_VOID");
  const [tab, setTab] = useState<Tab>(
    canRead ? "history" : canServe ? "register" : "configure",
  );
  const [slots, setSlots] = useState<MealSlot[]>([]);
  const [servings, setServings] = useState<MealServing[]>([]);
  const [summary, setSummary] = useState<MealSummary | null>(null);
  const [historyMember, setHistoryMember] = useState("");
  const [historyMemberName, setHistoryMemberName] = useState("");
  const [servingPage, setServingPage] = useState(1);
  const [servingTotal, setServingTotal] = useState(0);
  const [members, setMembers] = useState<MealMember[]>([]);
  const [plans, setPlans] = useState<MealPlan[]>([]);
  const [entitlements, setEntitlements] = useState<MealEntitlement[]>([]);
  const [selectedMember, setSelectedMember] = useState("");
  const [selectedSlot, setSelectedSlot] = useState("");
  const [selectedPlan, setSelectedPlan] = useState("");
  const [query, setQuery] = useState("");
  const [eligibility, setEligibility] = useState<MealEligibility | null>(null);
  const [slotForm, setSlotForm] = useState({
    code: "",
    name: "",
    starts_at_local: "07:00",
    ends_at_local: "10:00",
    is_active: true,
  });
  const [maxServings, setMaxServings] = useState(1);
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);
  const [confirmServing, setConfirmServing] = useState(false);
  const [voidTarget, setVoidTarget] = useState<string | null>(null);
  const [voidReason, setVoidReason] = useState("");
  const reloadSequence = useRef(0);

  useEffect(() => {
    setHistoryMember("");
    setHistoryMemberName("");
    setSelectedMember("");
    setQuery("");
    setTab(canRead ? "history" : canServe ? "register" : "configure");
  }, [branchId]);

  async function reload() {
    if (!branchId) return;
    const sequence = ++reloadSequence.current;
    setLoading(true);
    setSlots([]);
    setServings([]);
    setSummary(null);
    setError(null);
    try {
      const [nextSlots, nextServings, nextSummary] = await Promise.all([
        listMealSlots(branchId),
        canRead
          ? listMealServings(branchId, 1, historyMember || undefined)
          : Promise.resolve(null),
        canRead
          ? getMealSummary(branchId, historyMember || undefined)
          : Promise.resolve(null),
      ]);
      if (sequence !== reloadSequence.current) return;
      setSlots(nextSlots);
      setServings(nextServings?.data ?? []);
      setSummary(nextSummary);
      setServingPage(1);
      setServingTotal(nextServings?.meta.total ?? 0);
      if (!selectedSlot && nextSlots.length) setSelectedSlot(nextSlots[0].id);
    } catch (cause) {
      if (sequence === reloadSequence.current)
        setError(safeMessage(cause, "Meals could not be loaded."));
    } finally {
      if (sequence === reloadSequence.current) setLoading(false);
    }
  }

  useEffect(() => {
    void reload();
  }, [branchId, historyMember]);
  useEffect(() => {
    if (
      !branchId ||
      !(
        (canServe && tab === "register") ||
        (canReadBranch && tab === "history")
      )
    )
      return;
    searchMealMembers(branchId, query)
      .then(setMembers)
      .catch((cause) => setError(safeMessage(cause)));
  }, [branchId, query, tab, canServe, canReadBranch]);
  useEffect(() => {
    if (!context || !canManage || tab !== "configure") return;
    listMealPlans(context.organizationId)
      .then(setPlans)
      .catch((cause) => setError(safeMessage(cause)));
  }, [context?.organizationId, tab, canManage]);
  useEffect(() => {
    if (!branchId || !selectedPlan) return;
    listMealEntitlements(branchId, selectedPlan)
      .then(setEntitlements)
      .catch((cause) => setError(safeMessage(cause)));
  }, [branchId, selectedPlan]);
  useEffect(() => {
    if (!branchId || !selectedSlot || tab !== "register" || !selectedMember) {
      setEligibility(null);
      return;
    }
    getMealEligibility(branchId, selectedSlot, selectedMember)
      .then(setEligibility)
      .catch((cause) => setError(safeMessage(cause)));
  }, [branchId, selectedSlot, selectedMember, tab, servings.length]);

  async function perform(action: () => Promise<unknown>, success: string) {
    setBusy(true);
    setError(null);
    setNotice(null);
    try {
      await action();
      setNotice(success);
      await reload();
    } catch (cause) {
      setError(safeMessage(cause));
    } finally {
      setBusy(false);
    }
  }

  async function loadMore() {
    setBusy(true);
    try {
      const next = await listMealServings(
        branchId,
        servingPage + 1,
        historyMember || undefined,
      );
      setServings((current) => [...current, ...next.data]);
      setServingPage(next.meta.page);
      setServingTotal(next.meta.total);
    } catch (cause) {
      setError(safeMessage(cause));
    } finally {
      setBusy(false);
    }
  }

  if (!context)
    return (
      <StateCard
        title="Choose a branch"
        message="Open a branch before viewing meals."
      />
    );
  if (loading) return <LoadingCard label="Loading meals" />;
  return (
    <div className="space-y-4 pb-4">
      <div>
        <p className="section-title">{context.branchName}</p>
        <h2 className="mt-1 text-2xl font-semibold">Meals</h2>
        <p className="mt-1 text-sm text-slate-600">
          Branch-local servings, confirmed by staff.
        </p>
      </div>
      <div
        className="flex gap-2 border-b border-line text-sm"
        role="tablist"
        aria-label="Meal sections"
      >
        {(
          [
            ...(canRead ? ["history"] : []),
            ...(canServe ? ["register"] : []),
            ...(canManage ? ["configure"] : []),
          ] as Tab[]
        ).map((item) => (
          <button
            key={item}
            type="button"
            role="tab"
            aria-selected={tab === item}
            className={`px-3 py-2 capitalize ${tab === item ? "border-b-2 border-brand font-semibold text-brand" : "text-slate-600"}`}
            onClick={() => {
              setTab(item);
              setError(null);
              setNotice(null);
            }}
          >
            {item === "history"
              ? "History"
              : item === "register"
                ? "Serve"
                : "Configure"}
          </button>
        ))}
      </div>
      {error && (
        <StateCard
          title="Action unavailable"
          message={error}
          tone="error"
          action={
            <button className="secondary-button" onClick={() => void reload()}>
              Retry
            </button>
          }
        />
      )}
      {notice && <StateCard title="Done" message={notice} tone="success" />}
      {tab === "history" && (
        <>
          {canReadBranch && (
            <div className="card space-y-2 p-4">
              <label className="block text-sm font-semibold">
                Filter member
                <input
                  className="field mt-2"
                  value={query}
                  onChange={(event) => setQuery(event.target.value)}
                  placeholder="Search name or member number"
                />
              </label>
              <PickerField
                label="History member"
                value={historyMember}
                onChange={(value) => {
                  setHistoryMember(value);
                  setHistoryMemberName(
                    members.find((member) => member.id === value)?.user.name ??
                      historyMemberName,
                  );
                }}
                options={[
                  { value: "", label: "All branch members" },
                  ...(historyMember &&
                  !members.some((member) => member.id === historyMember)
                    ? [{ value: historyMember, label: historyMemberName }]
                    : []),
                  ...members.map((member) => ({
                    value: member.id,
                    label: member.user.name,
                  })),
                ]}
              />
            </div>
          )}
          {summary && (
            <section className="card p-4">
              <p className="section-title">Servings · last 30 days</p>
              <p className="mt-1 text-xs text-slate-500">
                {summary.from} – {summary.to}
              </p>
              <div className="mt-3 grid grid-cols-2 gap-2">
                {summary.slots.map((slot) => (
                  <div
                    key={slot.meal_slot_id}
                    className="rounded-xl bg-brand-soft p-3"
                  >
                    <strong className="block text-2xl text-brand">
                      {slot.count}
                    </strong>
                    <span className="text-sm">{slot.name}</span>
                  </div>
                ))}
              </div>
              <p className="mt-3 text-sm font-semibold">
                Total confirmed: {summary.total}
              </p>
            </section>
          )}
          {slots.length === 0 && (
            <StateCard
              title="No meal slots yet"
              message="An authorized operator can configure breakfast, lunch, or dinner for this branch."
            />
          )}
          <div className="grid grid-cols-2 gap-3">
            {slots
              .filter((slot) => slot.is_active)
              .map((slot) => (
                <div className="card p-4" key={slot.id}>
                  <p className="font-semibold">{slot.name}</p>
                  <p className="mt-1 text-xs text-slate-600">
                    {slot.starts_at_local}–{slot.ends_at_local}
                  </p>
                </div>
              ))}
          </div>
          <p className="section-title">Serving history</p>
          {servings.length === 0 ? (
            <StateCard
              title="No servings recorded"
              message="Confirmed meals will appear here."
            />
          ) : (
            <section className="card divide-y divide-line">
              {servings.map((serving) => (
                <div
                  key={serving.id}
                  className="meal-setting-row"
                >
                  <div>
                    <p className="font-semibold">{serving.meal_slot.name}</p>
                    <p className="text-xs text-slate-600">
                      {serving.member.user.name} ·{" "}
                      {serving.local_date.slice(0, 10)} · #
                      {serving.serving_number}
                    </p>
                  </div>
                  <div className="text-right">
                    <p
                      className={
                        serving.status === "VOID"
                          ? "text-slate-500"
                          : "text-brand"
                      }
                    >
                      {serving.status === "VOID" ? "Voided" : "Served"}
                    </p>
                    {canVoid && serving.status === "CONFIRMED" && (
                      <button
                        className="mt-1 text-xs underline"
                        type="button"
                        disabled={busy}
                        onClick={() => {
                          setVoidTarget(serving.id);
                          setVoidReason("");
                        }}
                      >
                        Void
                      </button>
                    )}
                  </div>
                </div>
              ))}
            </section>
          )}
          {servings.length < servingTotal && (
            <button
              type="button"
              className="secondary-button w-full"
              disabled={busy}
              onClick={() => void loadMore()}
            >
              Load more servings
            </button>
          )}
        </>
      )}
      {tab === "register" && canServe && (
        <section className="attendance-panel space-y-3">
          <p className="section-title">Staff-confirmed serving</p>
          <label className="block text-sm font-semibold">
            Find member
            <input
              className="field mt-2"
              value={query}
              onChange={(event) => setQuery(event.target.value)}
              placeholder="Name or member number"
            />
          </label>
          <PickerField
            label="Member"
            value={selectedMember}
            placeholder="Select member"
            onChange={setSelectedMember}
            options={[
              { value: "", label: "Select member" },
              ...members.map((member) => ({
                value: member.id,
                label: `${member.user.name}${member.member_number ? ` - ${member.member_number}` : ""}`,
              })),
            ]}
          />
          <label className="hidden">
            Member
            <select
              className="field mt-2"
              value={selectedMember}
              onChange={(event) => setSelectedMember(event.target.value)}
            >
              <option value="">Select member</option>
              {members.map((member) => (
                <option key={member.id} value={member.id}>
                  {member.user.name}
                  {member.member_number ? ` · ${member.member_number}` : ""}
                </option>
              ))}
            </select>
          </label>
          <PickerField
            label="Meal slot"
            value={selectedSlot}
            placeholder="Select slot"
            onChange={setSelectedSlot}
            options={[
              { value: "", label: "Select slot" },
              ...slots
                .filter((slot) => slot.is_active)
                .map((slot) => ({
                  value: slot.id,
                  label: `${slot.name} - ${slot.starts_at_local}-${slot.ends_at_local}`,
                })),
            ]}
          />
          <label className="hidden">
            Meal slot
            <select
              className="field mt-2"
              value={selectedSlot}
              onChange={(event) => setSelectedSlot(event.target.value)}
            >
              <option value="">Select slot</option>
              {slots
                .filter((slot) => slot.is_active)
                .map((slot) => (
                  <option key={slot.id} value={slot.id}>
                    {slot.name} · {slot.starts_at_local}–{slot.ends_at_local}
                  </option>
                ))}
            </select>
          </label>
          {eligibility && (
            <p className="text-sm text-slate-600">
              {eligibility.entitled
                ? `${eligibility.remaining} of ${eligibility.max_servings_per_day} remaining today`
                : "No active plan entitlement"}
              {!eligibility.window_open ? " · Slot closed now" : ""}
            </p>
          )}
          <button
            type="button"
            className="primary-button w-full"
            disabled={busy || !eligibility?.eligible}
            onClick={() => setConfirmServing(true)}
          >
            Confirm serving
          </button>
        </section>
      )}
      {tab === "configure" && canManage && (
        <div className="space-y-4">
          <section className="attendance-panel space-y-3">
            <p className="section-title">Branch meal slots</p>
            {slots.map((slot) => (
              <button
                key={slot.id}
                className="meal-setting-row w-full text-left"
                type="button"
                onClick={() => setSlotForm(slot)}
              >
                <span>
                  {slot.name} · {slot.starts_at_local}–{slot.ends_at_local}
                </span>
                <span>{slot.is_active ? "Active" : "Inactive"}</span>
              </button>
            ))}
            <label className="block text-sm">
              Code
              <input
                className="field mt-1"
                value={slotForm.code}
                onChange={(event) =>
                  setSlotForm({ ...slotForm, code: event.target.value })
                }
                placeholder="breakfast"
              />
            </label>
            <label className="block text-sm">
              Name
              <input
                className="field mt-1"
                value={slotForm.name}
                onChange={(event) =>
                  setSlotForm({ ...slotForm, name: event.target.value })
                }
                placeholder="Breakfast"
              />
            </label>
            <div className="grid grid-cols-2 gap-3">
              <label className="text-sm">
                From
                <input
                  className="field mt-1"
                  type="time"
                  value={slotForm.starts_at_local}
                  onChange={(event) =>
                    setSlotForm({
                      ...slotForm,
                      starts_at_local: event.target.value,
                    })
                  }
                />
              </label>
              <label className="text-sm">
                To
                <input
                  className="field mt-1"
                  type="time"
                  value={slotForm.ends_at_local}
                  onChange={(event) =>
                    setSlotForm({
                      ...slotForm,
                      ends_at_local: event.target.value,
                    })
                  }
                />
              </label>
            </div>
            <label className="flex gap-2 text-sm">
              <input
                type="checkbox"
                checked={slotForm.is_active}
                onChange={(event) =>
                  setSlotForm({ ...slotForm, is_active: event.target.checked })
                }
              />
              Active
            </label>
            <div className="flex gap-2">
              <button
                className="primary-button"
                type="button"
                disabled={busy || !slotForm.code || !slotForm.name}
                onClick={() =>
                  void perform(
                    () =>
                      saveMealSlot(
                        branchId,
                        slotForm,
                        "id" in slotForm ? String(slotForm.id) : undefined,
                      ),
                    "Meal slot saved.",
                  )
                }
              >
                Save slot
              </button>
              <button
                className="secondary-button"
                type="button"
                onClick={() =>
                  setSlotForm({
                    code: "",
                    name: "",
                    starts_at_local: "07:00",
                    ends_at_local: "10:00",
                    is_active: true,
                  })
                }
              >
                New slot
              </button>
            </div>
          </section>
          <section className="attendance-panel space-y-3">
            <p className="section-title">Plan entitlements</p>
            <p className="text-xs text-slate-600">
              Changes apply to future subscriptions. Existing snapshots stay
              unchanged.
            </p>
            <PickerField
              label="Plan"
              value={selectedPlan}
              placeholder="Select plan"
              onChange={setSelectedPlan}
              options={[
                { value: "", label: "Select plan" },
                ...plans.map((plan) => ({ value: plan.id, label: plan.name })),
              ]}
            />
            <select
              className="hidden"
              value={selectedPlan}
              onChange={(event) => setSelectedPlan(event.target.value)}
            >
              <option value="">Select plan</option>
              {plans.map((plan) => (
                <option key={plan.id} value={plan.id}>
                  {plan.name}
                </option>
              ))}
            </select>
            {selectedPlan &&
              slots.map((slot) => {
                const current = entitlements.find(
                  (item) => item.meal_slot_id === slot.id,
                );
                return (
                  <div
                    key={slot.id}
                    className="meal-setting-row border-t border-line text-sm"
                  >
                    <div>
                      <p className="font-semibold">{slot.name}</p>
                      <p className="text-xs text-slate-500">
                        {current?.is_active
                          ? `${current.max_servings_per_day} per day`
                          : "Not included"}
                      </p>
                    </div>
                    <div className="flex gap-2">
                      <button
                        type="button"
                        className="secondary-button px-3 py-1"
                        disabled={busy}
                        onClick={() =>
                          void perform(async () => {
                            await setMealEntitlement(branchId, selectedPlan, {
                              meal_slot_id: slot.id,
                              max_servings_per_day: maxServings,
                              is_active: true,
                            });
                            setEntitlements(
                              await listMealEntitlements(
                                branchId,
                                selectedPlan,
                              ),
                            );
                          }, "Plan entitlement saved.")
                        }
                      >
                        Include
                      </button>
                      {current?.is_active && (
                        <button
                          type="button"
                          className="secondary-button px-3 py-1"
                          disabled={busy}
                          onClick={() =>
                            void perform(async () => {
                              await setMealEntitlement(branchId, selectedPlan, {
                                meal_slot_id: slot.id,
                                max_servings_per_day:
                                  current.max_servings_per_day,
                                is_active: false,
                              });
                              setEntitlements(
                                await listMealEntitlements(
                                  branchId,
                                  selectedPlan,
                                ),
                              );
                            }, "Entitlement disabled for future subscriptions.")
                          }
                        >
                          Remove
                        </button>
                      )}
                    </div>
                  </div>
                );
              })}
            {selectedPlan && (
              <label className="block text-sm">
                Servings per day
                <input
                  className="field mt-1"
                  type="number"
                  min={1}
                  max={10}
                  value={maxServings}
                  onChange={(event) =>
                    setMaxServings(Number(event.target.value))
                  }
                />
              </label>
            )}
          </section>
        </div>
      )}
      {confirmServing && (
        <ConfirmAction
          title="Confirm meal served?"
          message="This will record one serving for the selected member and meal slot."
          confirmLabel="Confirm serving"
          pending={busy}
          onCancel={() => setConfirmServing(false)}
          onConfirm={() => {
            setConfirmServing(false);
            void perform(
              () => serveMeal(branchId, selectedMember, selectedSlot),
              "Meal serving confirmed by the server.",
            );
          }}
        />
      )}
      {voidTarget && (
        <ConfirmAction
          title="Void this serving?"
          message="The original serving stays in history. A reason and approver are recorded."
          confirmLabel="Void serving"
          pending={busy}
          confirmDisabled={voidReason.trim().length < 10}
          onCancel={() => setVoidTarget(null)}
          onConfirm={() => {
            const target = voidTarget;
            setVoidTarget(null);
            void perform(
              () => voidMeal(branchId, target, voidReason.trim()),
              "Serving voided with an audit record.",
            );
          }}
        >
          <label className="block text-sm font-semibold">
            Reason
            <textarea
              className="field mt-2"
              maxLength={1000}
              value={voidReason}
              onChange={(event) => setVoidReason(event.target.value)}
            />
          </label>
          <p className="mt-1 text-xs text-slate-600">At least 10 characters.</p>
        </ConfirmAction>
      )}
    </div>
  );
}
