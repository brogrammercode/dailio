import { useEffect, useState } from "react";
import { Amount } from "../../components/data-display/Amount";
import { LoadingCard, StateCard } from "../../components/feedback/StateCard";
import { safeMessage } from "../../lib/errors";
import { getContext } from "../../lib/session";
import { listFees } from "./payments.api";
import type { FeeCard } from "../../types/domain";

export function MemberFeesPage({ onBuy }: { onBuy: () => void }) {
  const context = getContext();
  const [fees, setFees] = useState<FeeCard[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  useEffect(() => {
    if (!context) {
      setLoading(false);
      return;
    }
    listFees(context.branchId)
      .then(setFees)
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
  if (loading) return <LoadingCard label="Loading fees" />;
  if (error)
    return <StateCard title="Fees unavailable" message={error} tone="error" />;
  return (
    <div className="space-y-5">
      <div className="flex items-end justify-between">
        <div>
          <p className="section-title">Fees</p>
          <h2 className="mt-2 text-3xl font-semibold">Your plans</h2>
        </div>
        <button
          className="primary-button min-h-10 px-4 py-2 text-sm"
          onClick={onBuy}
        >
          Buy the plan
        </button>
      </div>
      <div className="flex gap-2 text-sm">
        <span className="rounded-full bg-brand-soft px-3 py-2 font-semibold text-brand">
          This month
        </span>
        <span className="rounded-full bg-white px-3 py-2 text-slate-500">
          History
        </span>
      </div>
      {fees.length === 0 ? (
        <StateCard
          title="No fee records"
          message="Scan a plan QR or use Buy the plan to start a request."
          action={
            <button className="secondary-button w-full" onClick={onBuy}>
              Buy the plan
            </button>
          }
        />
      ) : (
        <section className="space-y-3">
          {fees.map((fee, index) => (
            <div className="card p-4" key={String(fee.id ?? index)}>
              <div className="flex items-start justify-between gap-3">
                <div>
                  <p className="font-semibold">
                    {String(
                      (fee.subscription as { plan_name?: string } | undefined)
                        ?.plan_name ??
                        fee.plan_name ??
                        "Subscription",
                    )}
                  </p>
                  <p className="mt-1 text-xs text-slate-500">
                    {String(fee.status ?? "PENDING")}
                  </p>
                </div>
                <strong className="text-brand">
                  <Amount
                    minor={Number(
                      fee.amount_minor_unit ?? fee.balance_minor_unit ?? 0,
                    )}
                    currency={String(fee.currency ?? "INR")}
                  />
                </strong>
              </div>
              <p className="mt-3 text-sm text-slate-600">
                Payment state is confirmed by the branch server. Requested
                payments stay separate from Paid.
              </p>
            </div>
          ))}
        </section>
      )}
    </div>
  );
}
