export function Amount({
  minor,
  currency = "INR",
}: {
  minor?: number | null;
  currency?: string;
}) {
  if (minor == null) return <span>—</span>;
  return (
    <span>
      {new Intl.NumberFormat("en-IN", { style: "currency", currency }).format(
        minor / 100,
      )}
    </span>
  );
}
