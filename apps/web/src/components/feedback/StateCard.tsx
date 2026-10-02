import type { ReactNode } from "react";

export function StateCard({
  title,
  message,
  action,
  tone = "neutral",
  children,
}: {
  title: string;
  message?: string;
  action?: ReactNode;
  tone?: "neutral" | "error" | "success" | "pending";
  children?: ReactNode;
}) {
  const styles = {
    neutral: "border-line",
    error: "border-red-200 bg-red-50",
    success: "border-green-200 bg-green-50",
    pending: "border-amber-200 bg-amber-50",
  };
  return (
    <section
      className={`card p-5 ${styles[tone]}`}
      role={tone === "error" ? "alert" : undefined}
    >
      <h2 className="text-lg font-semibold">{title}</h2>
      {message && (
        <p className="mt-2 text-sm leading-6 text-slate-600">{message}</p>
      )}
      {children}
      {action && <div className="mt-4">{action}</div>}
    </section>
  );
}

export function LoadingCard({ label = "Loading…" }: { label?: string }) {
  return (
    <StateCard
      title={label}
      message="Please wait while Dailio confirms the latest state."
    />
  );
}
