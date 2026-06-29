export function BarChart<T>({
  data,
  value,
  label,
  format,
}: {
  data: T[];
  value: (d: T) => number;
  label: (d: T) => string;
  format?: (n: number) => string;
}) {
  const max = Math.max(1, ...data.map(value));
  if (data.length === 0) return <p className="py-8 text-center text-sm text-muted">No data for this range.</p>;

  return (
    <div className="flex h-52 items-end gap-2">
      {data.map((d, i) => {
        const v = value(d);
        return (
          <div key={i} className="flex min-w-0 flex-1 flex-col items-center gap-2">
            <div className="flex w-full flex-1 items-end">
              <div
                className="w-full rounded-t bg-gradient-to-t from-primary-dim/40 to-primary transition-all hover:from-primary-dim hover:to-primary"
                style={{ height: `${Math.max(2, (v / max) * 100)}%` }}
                title={`${label(d)}: ${format ? format(v) : v}`}
              />
            </div>
            <span className="w-full truncate text-center text-[10px] text-muted">{label(d)}</span>
          </div>
        );
      })}
    </div>
  );
}
