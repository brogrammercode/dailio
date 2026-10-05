import { useState } from "react";

import { StateCard } from "../../components/feedback/StateCard";
import { Icon } from "../../components/ui/Icon";
import { safeMessage } from "../../lib/errors";
import { serveMealFromInvite } from "./attendance.api";
import type { Invite } from "../../types/domain";

export function MealAttendancePage({
  token,
  invite,
}: {
  token: string;
  invite: Invite;
}) {
  const slots = invite.meal_slots ?? [];
  const [selected, setSelected] = useState("");
  const [busy, setBusy] = useState(false);
  const [done, setDone] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function submit() {
    if (!selected || busy) return;
    setBusy(true);
    setError(null);
    try {
      await serveMealFromInvite(token, selected);
      setDone(true);
    } catch (cause) {
      setError(safeMessage(cause, "Meal attendance could not be marked."));
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="attendance-page space-y-6 pb-5">
      <div>
        <p className="section-title">{invite.branch.name}</p>
        <h1 className="mt-1 text-2xl font-semibold">Meal attendance</h1>
        <p className="mt-1 text-sm text-slate-600">
          Server-confirmed attendance for the selected meal window.
        </p>
      </div>
      {done ? (
        <StateCard
          title="Meal attendance marked"
          message="Dailio recorded your serving using the branch server time."
          tone="success"
        />
      ) : (
        <section className="attendance-panel space-y-4">
          <div className="flex items-center justify-between">
            <div>
              <p className="section-title">Today</p>
              <h2 className="mt-1 text-base font-semibold text-ink">
                Choose a meal
              </h2>
            </div>
            <span className="status-badge">QR SCAN</span>
          </div>
          {slots.length === 0 ? (
            <p className="text-sm text-slate-600">
              No active meal windows are configured for this branch.
            </p>
          ) : (
            <div className="space-y-2">
              {slots.map((slot) => (
                <button
                  aria-pressed={selected === slot.id}
                  className={
                    "meal-option " + (selected === slot.id ? "selected" : "")
                  }
                  key={slot.id}
                  onClick={() => setSelected(slot.id)}
                  type="button"
                >
                  <span className="meal-option-icon">
                    <Icon name="meals" size={19} />
                  </span>
                  <span className="min-w-0 flex-1">
                    <strong className="block truncate text-sm">
                      {slot.name}
                    </strong>
                    <span className="mt-1 block text-xs text-slate-500">
                      {slot.starts_at_local} - {slot.ends_at_local}
                    </span>
                  </span>
                  <span
                    className={
                      "meal-option-check " +
                      (selected === slot.id ? "selected" : "")
                    }
                  >
                    {selected === slot.id && <Icon name="check" size={14} />}
                  </span>
                </button>
              ))}
            </div>
          )}
          {error && <p className="text-sm text-red-600">{error}</p>}
          <button
            className="primary-button w-full"
            disabled={!selected || busy}
            onClick={() => void submit()}
            type="button"
          >
            {busy ? "Marking..." : "Mark meal attendance"}
          </button>
        </section>
      )}
    </div>
  );
}
