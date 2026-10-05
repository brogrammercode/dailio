import type { ReactNode } from "react";

export function ConfirmAction({
  title,
  message,
  confirmLabel,
  pending,
  confirmDisabled,
  onCancel,
  onConfirm,
  children,
}: {
  title: string;
  message: string;
  confirmLabel: string;
  pending?: boolean;
  confirmDisabled?: boolean;
  onCancel: () => void;
  onConfirm: () => void;
  children?: ReactNode;
}) {
  return (
    <div className="confirm-backdrop" role="presentation">
      <section
        className="confirm-dialog"
        role="dialog"
        aria-modal="true"
        aria-label={title}
      >
        <p className="section-title">Confirm action</p>
        <h2 className="mt-2 text-xl font-semibold">{title}</h2>
        <p className="mt-2 text-sm leading-6 text-slate-600">{message}</p>
        {children && <div className="mt-4">{children}</div>}
        <div className="mt-5 grid grid-cols-2 gap-3">
          <button
            type="button"
            className="secondary-button"
            disabled={pending}
            onClick={onCancel}
          >
            Cancel
          </button>
          <button
            type="button"
            className="primary-button"
            disabled={pending || confirmDisabled}
            onClick={onConfirm}
          >
            {pending ? "Working…" : confirmLabel}
          </button>
        </div>
      </section>
    </div>
  );
}
