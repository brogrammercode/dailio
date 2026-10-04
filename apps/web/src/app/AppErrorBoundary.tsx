import { Component, type ReactNode } from "react";

export class AppErrorBoundary extends Component<
  { children: ReactNode },
  { failed: boolean }
> {
  state = { failed: false };

  static getDerivedStateFromError() {
    return { failed: true };
  }

  render() {
    if (this.state.failed)
      return (
        <main className="page flex min-h-screen items-center justify-center px-5">
          <section className="card w-full max-w-md space-y-4 p-6 text-center">
            <h1 className="text-xl font-semibold">Dailio could not open</h1>
            <p className="text-sm text-slate-600">
              Something went wrong while showing this page. Your account is
              still safe; please reload to try again.
            </p>
            <button
              className="primary-button w-full"
              onClick={() => window.location.reload()}
              type="button"
            >
              Reload
            </button>
          </section>
        </main>
      );
    return this.props.children;
  }
}
