import { useState } from "react";
import { Amount } from "../../components/data-display/Amount";
import { StateCard } from "../../components/feedback/StateCard";
import { safeMessage } from "../../lib/errors";
import { newIdempotencyKey } from "../../lib/idempotency";
import { formatMinorInput, parseMinorInput } from "../../lib/money";
import {
  createPaymentRequest,
  createEvidenceUploadSignature,
  uploadToCloudinary,
} from "../payments/payments.api";
import { createSubscriptionDraft } from "../invites/invites.api";
import type {
  Invite,
  PaymentRequest,
  SubscriptionDraft,
} from "../../types/domain";

export function PurchasePage({
  token,
  invite,
  onDone,
}: {
  token: string;
  invite: Invite;
  onDone: (request: PaymentRequest) => void;
}) {
  const plan = invite.plan;
  const [startDate, setStartDate] = useState(
    new Date().toISOString().slice(0, 10),
  );
  const [draft, setDraft] = useState<SubscriptionDraft | null>(null);
  const [method, setMethod] = useState("UPI");
  const [reference, setReference] = useState("");
  const [note, setNote] = useState("");
  const [paidAmount, setPaidAmount] = useState("");
  const [file, setFile] = useState<File | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  async function makeDraft() {
    setBusy(true);
    setError(null);
    try {
      const prepared = await createSubscriptionDraft(
        token,
        newIdempotencyKey("web-subscription-draft"),
        `${startDate}T00:00:00.000Z`,
      );
      setDraft(prepared);
      setPaidAmount(
        formatMinorInput(
          prepared.agreed_amount_minor +
            plan!.joining_fee_minor -
            (prepared.discount_minor ?? 0),
        ),
      );
    } catch (cause) {
      setError(safeMessage(cause, "The plan could not be prepared."));
    } finally {
      setBusy(false);
    }
  }

  async function submitRequest() {
    if (!draft || !plan) return;
    if (!file && !reference.trim()) {
      setError(
        "Add a payment reference or upload payment evidence before submitting.",
      );
      return;
    }
    const totalMinor =
      draft.agreed_amount_minor +
      plan.joining_fee_minor -
      (draft.discount_minor ?? 0);
    const paidMinor = parseMinorInput(paidAmount);
    if (paidMinor === null || paidMinor > totalMinor) {
      setError(
        "Enter a payment amount greater than zero and no more than the plan total.",
      );
      return;
    }
    setBusy(true);
    setError(null);
    try {
      const evidence = [] as Array<{
        storage_key: string;
        content_type: string;
        size_bytes?: number;
        reference?: string;
        note?: string;
      }>;
      if (file) {
        const signature = await createEvidenceUploadSignature(
          invite.branch.id,
          file.name,
          file.type,
        );
        await uploadToCloudinary(signature, file);
        evidence.push({
          storage_key: String(signature.storage_key ?? ""),
          content_type: file.type,
          size_bytes: file.size,
          reference: reference || undefined,
          note: note || undefined,
        });
      }
      onDone(
        await createPaymentRequest(invite.branch.id, {
          subscription_id: draft.id,
          amount_minor_unit: paidMinor,
          currency: draft.currency,
          method,
          reference: reference || undefined,
          note: note || undefined,
          evidence,
        }),
      );
    } catch (cause) {
      setError(safeMessage(cause, "Payment request could not be submitted."));
    } finally {
      setBusy(false);
    }
  }

  if (!plan || invite.joinability !== "ALREADY_MEMBER")
    return (
      <StateCard
        title="Plan purchase unavailable"
        message="This plan QR is available to active members of the branch only."
      />
    );
  return (
    <div className="space-y-5">
      <div>
        <p className="section-title">Buy the plan</p>
        <h2 className="mt-2 text-3xl font-semibold">{plan.name}</h2>
        <p className="mt-2 text-sm text-slate-600">
          {invite.organization.name} · {invite.branch.name}
        </p>
      </div>
      <section className="card space-y-3 p-5">
        <div className="flex items-center justify-between">
          <span className="font-semibold">Plan price</span>
          <strong className="text-xl text-brand">
            <Amount
              minor={plan.amount_minor_unit + plan.joining_fee_minor}
              currency={plan.currency}
            />
          </strong>
        </div>
        <div className="grid grid-cols-2 gap-3 text-sm text-slate-600">
          <p>
            Duration{" "}
            <strong className="block text-ink">
              {plan.duration_days} days
            </strong>
          </p>
          <p>
            Joining fee{" "}
            <strong className="block text-ink">
              <Amount minor={plan.joining_fee_minor} currency={plan.currency} />
            </strong>
          </p>
        </div>
      </section>
      {!draft ? (
        <section className="card space-y-4 p-5">
          <label className="block text-sm font-semibold">
            Coverage starts
            <input
              className="field mt-2"
              type="date"
              value={startDate}
              onChange={(event) => setStartDate(event.target.value)}
            />
          </label>
          {error && (
            <StateCard
              title="Could not prepare plan"
              message={error}
              tone="error"
            />
          )}
          <button
            className="primary-button w-full"
            disabled={busy}
            onClick={() => void makeDraft()}
          >
            {busy ? "Preparing…" : "Continue"}
          </button>
        </section>
      ) : (
        <section className="card space-y-4 p-5">
          <div>
            <p className="section-title">Review</p>
            <p className="mt-2 text-sm text-slate-600">
              Coverage:{" "}
              <strong className="text-ink">
                {draft.start_date.slice(0, 10)} to {draft.end_date.slice(0, 10)}
              </strong>
            </p>
            <p className="mt-1 text-sm text-slate-600">
              Amount:{" "}
              <strong className="text-ink">
                <Amount
                  minor={
                    draft.agreed_amount_minor +
                    plan.joining_fee_minor -
                    (draft.discount_minor ?? 0)
                  }
                  currency={draft.currency}
                />
              </strong>
            </p>
          </div>
          <label className="block text-sm font-semibold">
            Amount paid now ({draft.currency})
            <input
              className="field mt-2"
              type="text"
              inputMode="decimal"
              value={paidAmount}
              onChange={(event) => setPaidAmount(event.target.value)}
              placeholder="0.00"
              aria-describedby="payment-balance-help"
            />
          </label>
          <p id="payment-balance-help" className="text-xs text-slate-600">
            Remaining due after confirmation:{" "}
            <Amount
              minor={Math.max(
                0,
                draft.agreed_amount_minor +
                  plan.joining_fee_minor -
                  (draft.discount_minor ?? 0) -
                  (parseMinorInput(paidAmount) ?? 0),
              )}
              currency={draft.currency}
            />
            . A request is not paid until the branch confirms it.
          </p>
          <label className="block text-sm font-semibold">
            Payment method
            <select
              className="field mt-2"
              value={method}
              onChange={(event) => setMethod(event.target.value)}
            >
              <option value="UPI">UPI</option>
              <option value="CASH">Cash</option>
              <option value="BANK_TRANSFER">Bank transfer</option>
              <option value="CARD">Card</option>
            </select>
          </label>
          <label className="block text-sm font-semibold">
            Reference
            <input
              className="field mt-2"
              value={reference}
              maxLength={200}
              onChange={(event) => setReference(event.target.value)}
              placeholder="Optional transaction ID"
            />
          </label>
          <label className="block text-sm font-semibold">
            Evidence
            <input
              className="field mt-2 p-2"
              type="file"
              accept="image/*,application/pdf"
              onChange={(event) => setFile(event.target.files?.[0] ?? null)}
            />
          </label>
          <label className="block text-sm font-semibold">
            Note
            <textarea
              className="field mt-2 min-h-24"
              value={note}
              maxLength={1000}
              onChange={(event) => setNote(event.target.value)}
              placeholder="Optional note for the reviewer"
            />
          </label>
          {error && (
            <StateCard title="Could not submit" message={error} tone="error" />
          )}
          <button
            className="primary-button w-full"
            disabled={busy}
            onClick={() => void submitRequest()}
          >
            {busy ? "Submitting…" : "Submit payment request"}
          </button>
          <p className="text-xs leading-5 text-slate-500">
            Manual evidence stays Requested until an authorized reviewer
            confirms it. It is not counted as paid yet.
          </p>
        </section>
      )}
    </div>
  );
}
