import type { ReactNode } from "react";
import type { TenantContext, User } from "../../types/domain";

export function AppShell({
  user,
  context,
  active,
  onNavigate,
  onSignOut,
  children,
}: {
  user: User;
  context: TenantContext;
  active: "attendance" | "fees";
  onNavigate: (route: "attendance" | "fees") => void;
  onSignOut: () => void;
  children: ReactNode;
}) {
  return (
    <div className="page">
      <div className="shell pb-24">
        <header className="sticky top-0 z-10 border-b border-line bg-canvas/95 px-5 py-4 backdrop-blur">
          <div className="flex items-center justify-between">
            <div>
              <p className="text-xs font-semibold uppercase tracking-[.15em] text-brand">
                Dailio
              </p>
              <h1 className="mt-1 text-xl font-semibold">
                {context.branchName ?? "Your branch"}
              </h1>
              <p className="text-xs text-slate-500">
                {context.organizationName ?? "Organization"}
              </p>
            </div>
            <button
              className="rounded-full bg-white px-3 py-2 text-xs font-semibold text-slate-600 shadow-sm"
              onClick={onSignOut}
              aria-label="Sign out"
            >
              {user.name?.slice(0, 1).toUpperCase() ?? "U"} · Sign out
            </button>
          </div>
        </header>
        <main className="space-y-5 px-5 py-5">{children}</main>
        <nav
          className="fixed bottom-0 left-1/2 z-20 flex w-full max-w-[520px] -translate-x-1/2 gap-2 border-t border-line bg-white/95 p-3 shadow-soft backdrop-blur"
          aria-label="Member navigation"
        >
          <button
            className={`flex-1 rounded-xl px-3 py-3 text-sm font-semibold ${active === "attendance" ? "bg-brand-soft text-brand" : "text-slate-500"}`}
            onClick={() => onNavigate("attendance")}
          >
            ◷<span className="ml-2">Attendance</span>
          </button>
          <button
            className={`flex-1 rounded-xl px-3 py-3 text-sm font-semibold ${active === "fees" ? "bg-brand-soft text-brand" : "text-slate-500"}`}
            onClick={() => onNavigate("fees")}
          >
            ▣<span className="ml-2">Fees</span>
          </button>
        </nav>
      </div>
    </div>
  );
}
