import { useEffect, useState } from "react";
import { Amount } from "../../components/data-display/Amount";
import { LoadingCard, StateCard } from "../../components/feedback/StateCard";
import { ConfirmAction } from "../../components/feedback/ConfirmAction";
import { safeMessage } from "../../lib/errors";
import { getContext } from "../../lib/session";
import { formatMinorInput, parseMinorInput } from "../../lib/money";
import {
  createSettlementWaiver,
  listFees,
  listSettlementWaivers,
  reverseSettlementWaiver,
} from "./payments.api";
import type { SettlementWaiver } from "./payments.api";
import type { FeeCard } from "../../types/domain";

export function MemberFeesPage({ onBuy }: { onBuy: () => void }) {
  const context = getContext();
  const [fees, setFees] = useState<FeeCard[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);
  const [waiverSubscription, setWaiverSubscription] = useState<string | null>(
    null,
  );
  const [waiverAmount, setWaiverAmount] = useState("");
  const [waiverReason, setWaiverReason] = useState("");
  const [busy, setBusy] = useState(false);
  const [notice, setNotice] = useState<string | null>(null);
  const [confirmWaiver, setConfirmWaiver] = useState(false);
  const [waiverRevision, setWaiverRevision] = useState(0);
  const canWaive =
    context?.permissions?.includes("ALL") ||
    context?.permissions?.includes("PAYMENT_WAIVE");
  function submitWaiver(balance: number) {
    if (!context) return;
    const amount = parseMinorInput(waiverAmount);
    if (!amount || amount > balance || waiverReason.trim().length < 10) {
      setError(
        "Enter a valid waiver not exceeding the due, plus a reason of at least 10 characters.",
      );
      return;
    }
    setConfirmWaiver(true);
  }
  async function postWaiver() {
    if (!context || !waiverSubscription) return;
    const amount = parseMinorInput(waiverAmount);
    if (!amount) return;
    setBusy(true);
    setError(null);
    try {
      await createSettlementWaiver(
        context.branchId,
        waiverSubscription,
        amount,
        waiverReason.trim(),
      );
      setFees(await listFees(context.branchId));
      setWaiverRevision((value) => value + 1);
      setWaiverSubscription(null);
      setConfirmWaiver(false);
      setWaiverAmount("");
      setWaiverReason("");
      setNotice(
        "Waiver posted with an audit record. The remaining due has been recalculated.",
      );
    } catch (cause) {
      setError(safeMessage(cause));
    } finally {
      setBusy(false);
    }
  }
  useEffect(() => {
    setConfirmWaiver(false);
    setWaiverSubscription(null);
    if (!context) {
      setFees([]);
      setLoading(false);
      return;
    }
    let active = true;
    setFees([]);
    setLoading(true);
    setError(null);
    listFees(context.branchId)
      .then((next) => {
        if (active) setFees(next);
      })
      .catch((cause) => {
        if (active) setError(safeMessage(cause));
      })
      .finally(() => {
        if (active) setLoading(false);
      });
    return () => {
      active = false;
    };
  }, [context?.branchId]);
  if (!context)
    return (
      <StateCard
        title="Choose your branch"
        message="Open a branch QR to establish a secure member context."
      />
    );
  if (loading) return <LoadingCard label="Loading fees" />;
  return (
    <div className="space-y-5">
      {error && (
        <StateCard
          title="Fees unavailable"
          message={error}
          tone="error"
          action={
            <button className="secondary-button" onClick={() => setError(null)}>
              Dismiss
            </button>
          }
        />
      )}
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
      <p className="text-sm text-slate-600">This month’s fee records</p>
      {notice && <StateCard title="Updated" message={notice} tone="success" />}
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
            <div
              className="card p-4"
              key={`${context.branchId}:${fee.subscription?.id ?? fee.member?.id ?? index}`}
            >
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
                <strong className="text-brand" aria-label="Amount due">
                  <Amount
                    minor={Number(fee.balance_minor_unit ?? 0)}
                    currency={String(fee.currency ?? "INR")}
                  />
                </strong>
              </div>
              <div className="mt-3 grid grid-cols-3 gap-2 border-t border-line pt-3 text-xs">
                <p>
                  Charged
                  <strong className="block text-sm">
                    <Amount
                      minor={Number(fee.charged_amount_minor_unit ?? 0)}
                      currency={String(fee.currency ?? "INR")}
                    />
                  </strong>
                </p>
                <p>
                  Paid
                  <strong className="block text-sm">
                    <Amount
                      minor={Number(fee.paid_amount_minor_unit ?? 0)}
                      currency={String(fee.currency ?? "INR")}
                    />
                  </strong>
                </p>
                <p>
                  Waived
                  <strong className="block text-sm">
                    <Amount
                      minor={Number(fee.waived_amount_minor_unit ?? 0)}
                      currency={String(fee.currency ?? "INR")}
                    />
                  </strong>
                </p>
              </div>
              <p className="mt-2 text-xs text-slate-600">
                Due is calculated from posted ledger entries. Requests awaiting
                review do not count as paid.
              </p>
              {fee.subscription?.id && (
                <div className="mt-3 border-t border-line pt-3">
                  <WaiverHistory
                    branchId={context.branchId}
                    subscriptionId={fee.subscription.id}
                    currency={String(fee.currency ?? "INR")}
                    revision={waiverRevision}
                    canReverse={Boolean(canWaive)}
                    onChanged={async () => {
                      setFees(await listFees(context.branchId));
                      setWaiverRevision((value) => value + 1);
                    }}
                  />
                  {canWaive &&
                    Number(fee.balance_minor_unit ?? 0) > 0 &&
                    (waiverSubscription === fee.subscription.id ? (
                      <div className="space-y-3">
                        <p className="text-sm font-semibold">
                          Approve a negotiated concession
                        </p>
                        <p className="text-xs text-slate-600">
                          The original charge remains visible. This is not cash
                          received.
                        </p>
                        <label className="block text-sm">
                          Amount ({String(fee.currency ?? "INR")})
                          <input
                            className="field mt-1"
                            inputMode="decimal"
                            value={waiverAmount}
                            onChange={(event) =>
                              setWaiverAmount(event.target.value)
                            }
                          />
                        </label>
                        <label className="block text-sm">
                          Reason
                          <textarea
                            className="field mt-1"
                            maxLength={1000}
                            value={waiverReason}
                            onChange={(event) =>
                              setWaiverReason(event.target.value)
                            }
                          />
                        </label>
                        <div className="flex gap-2">
                          <button
                            type="button"
                            className="primary-button"
                            disabled={busy}
                            onClick={() =>
                              submitWaiver(Number(fee.balance_minor_unit))
                            }
                          >
                            Post waiver
                          </button>
                          <button
                            type="button"
                            className="secondary-button"
                            onClick={() => setWaiverSubscription(null)}
                          >
                            Cancel
                          </button>
                        </div>
                      </div>
                    ) : (
                      <button
                        type="button"
                        className="secondary-button"
                        onClick={() => {
                          setWaiverSubscription(fee.subscription!.id!);
                          setWaiverAmount(
                            formatMinorInput(Number(fee.balance_minor_unit)),
                          );
                          setWaiverReason("");
                        }}
                      >
                        Settle by waiver
                      </button>
                    ))}
                </div>
              )}
            </div>
          ))}
        </section>
      )}
      {confirmWaiver && (
        <ConfirmAction
          title="Approve this concession?"
          message="This posts a separate audited credit. It does not change the original charge or count as cash received."
          confirmLabel="Post waiver"
          pending={busy}
          onCancel={() => setConfirmWaiver(false)}
          onConfirm={() => void postWaiver()}
        />
      )}
    </div>
  );
}

function WaiverHistory({
  branchId,
  subscriptionId,
  currency,
  revision,
  canReverse,
  onChanged,
}: {
  branchId: string;
  subscriptionId: string;
  currency: string;
  revision: number;
  canReverse: boolean;
  onChanged: () => Promise<void>;
}) {
  const [open, setOpen] = useState(false);
  const [items, setItems] = useState<SettlementWaiver[]>([]);
  const [page, setPage] = useState(1);
  const [total, setTotal] = useState(0);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [reverseId, setReverseId] = useState<string | null>(null);
  const [reason, setReason] = useState("");
  const [busy, setBusy] = useState(false);
  useEffect(() => {
    if (!open) return;
    let active = true;
    setLoading(true);
    listSettlementWaivers(branchId, subscriptionId, page)
      .then((response) => {
        if (!active) return;
        setItems(response.data);
        setTotal(response.meta.total);
        setError(null);
      })
      .catch((cause) => {
        if (active) setError(safeMessage(cause));
      })
      .finally(() => {
        if (active) setLoading(false);
      });
    return () => {
      active = false;
    };
  }, [open, branchId, subscriptionId, page, revision]);
  async function submitReversal() {
    if (!reverseId || reason.trim().length < 10) return;
    setBusy(true);
    try {
      await reverseSettlementWaiver(
        branchId,
        subscriptionId,
        reverseId,
        reason.trim(),
      );
      setReverseId(null);
      setReason("");
      await onChanged();
    } catch (cause) {
      setError(safeMessage(cause));
    } finally {
      setBusy(false);
    }
  }
  return (
    <div className="mb-3">
      <button
        type="button"
        className="text-sm font-semibold text-brand underline"
        onClick={() => setOpen((value) => !value)}
      >
        {open ? "Hide waiver history" : "View waiver history"}
      </button>
      {open && (
        <div className="mt-3 space-y-2">
          {loading && (
            <p className="text-sm text-slate-500">Loading waiver history…</p>
          )}
          {error && (
            <p role="alert" className="text-sm text-red-700">
              {error}
            </p>
          )}
          {!loading && !error && items.length === 0 && (
            <p className="text-sm text-slate-500">No waivers recorded.</p>
          )}
          {items.map((item) => (
            <div
              key={item.id}
              className="rounded-xl border border-line p-3 text-sm"
            >
              <div className="flex items-center justify-between gap-2">
                <strong>
                  <Amount minor={item.amount_minor_unit} currency={currency} />
                </strong>
                <span>{item.reversal_id ? "Reversed" : "Posted"}</span>
              </div>
              <p className="mt-1 text-slate-600">{item.reason}</p>
              <p className="mt-1 text-xs text-slate-500">
                {new Date(item.created_at).toLocaleString()}
              </p>
              {canReverse && !item.reversal_id && (
                <button
                  type="button"
                  className="secondary-button mt-2"
                  onClick={() => {
                    setReverseId(item.id);
                    setReason("");
                  }}
                >
                  Reverse waiver
                </button>
              )}
            </div>
          ))}
          {total > 20 && (
            <div className="flex items-center gap-3 text-sm">
              <button
                type="button"
                className="secondary-button"
                disabled={page === 1}
                onClick={() => setPage((value) => value - 1)}
              >
                Previous
              </button>
              <span>Page {page}</span>
              <button
                type="button"
                className="secondary-button"
                disabled={page * 20 >= total}
                onClick={() => setPage((value) => value + 1)}
              >
                Next
              </button>
            </div>
          )}
        </div>
      )}
      {reverseId && (
        <ConfirmAction
          title="Reverse this waiver?"
          message="This posts a new charge to restore the due. The original waiver remains in history."
          confirmLabel="Restore due"
          pending={busy}
          confirmDisabled={reason.trim().length < 10}
          onCancel={() => setReverseId(null)}
          onConfirm={() => void submitReversal()}
        >
          <label className="block text-sm">
            Reason
            <textarea
              className="field mt-1"
              value={reason}
              maxLength={1000}
              onChange={(event) => setReason(event.target.value)}
            />
          </label>
        </ConfirmAction>
      )}
    </div>
  );
}
