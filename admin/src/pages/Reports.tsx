import { useState } from "react";
import { apiGet } from "../lib/api";
import { inr } from "../lib/format";
import { useApi } from "../lib/useApi";
import { BarChart } from "../components/BarChart";
import { Card, EmptyState, ErrorState, Field, Icon, PageHeader, Select, Skeleton, Table, Td, Th } from "../components/ui";

interface Report {
  granularity: string;
  summary: { totalBookings: number; totalRevenue: number };
  series: { period: string; bookings: number; revenue: number }[];
  topMovies: { title: string; bookings: number; revenue: number }[];
}

const isoDate = (d: Date) => d.toISOString().slice(0, 10);

export default function Reports() {
  const [from, setFrom] = useState(isoDate(new Date(Date.now() - 30 * 86_400_000)));
  const [to, setTo] = useState(isoDate(new Date()));
  const [granularity, setGranularity] = useState("daily");

  const params = new URLSearchParams({ from, to, granularity });
  const report = useApi(() => apiGet<Report>(`/admin/reports?${params.toString()}`), [from, to, granularity]);

  return (
    <>
      <PageHeader title="Reports" subtitle="Booking and revenue summaries." />

      <div className="mb-5 flex flex-wrap items-end gap-3">
        <Field label="From">
          <input
            type="date"
            value={from}
            onChange={(e) => setFrom(e.target.value)}
            className="rounded-lg border border-line bg-surface-low px-3 py-2 text-sm text-fg outline-none focus:border-primary"
          />
        </Field>
        <Field label="To">
          <input
            type="date"
            value={to}
            onChange={(e) => setTo(e.target.value)}
            className="rounded-lg border border-line bg-surface-low px-3 py-2 text-sm text-fg outline-none focus:border-primary"
          />
        </Field>
        <Field label="Granularity">
          <Select value={granularity} onChange={(e) => setGranularity(e.target.value)}>
            <option value="daily">Daily</option>
            <option value="weekly">Weekly</option>
            <option value="monthly">Monthly</option>
          </Select>
        </Field>
      </div>

      {report.loading ? (
        <Skeleton className="h-64 w-full" />
      ) : report.error ? (
        <ErrorState message={report.error} onRetry={report.refetch} />
      ) : report.data ? (
        <>
          <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
            <Card className="p-5">
              <div className="flex items-center justify-between">
                <span className="text-xs font-semibold uppercase tracking-wide text-muted">Total bookings</span>
                <Icon name="confirmation_number" className="text-xl text-primary" />
              </div>
              <p className="mt-2 text-3xl font-bold">{report.data.summary.totalBookings}</p>
            </Card>
            <Card className="p-5">
              <div className="flex items-center justify-between">
                <span className="text-xs font-semibold uppercase tracking-wide text-muted">Total revenue</span>
                <Icon name="payments" className="text-xl text-primary" />
              </div>
              <p className="mt-2 text-3xl font-bold">{inr(report.data.summary.totalRevenue)}</p>
            </Card>
          </div>

          <Card className="mt-6 p-5">
            <h2 className="mb-4 text-lg font-bold">Revenue over time</h2>
            <BarChart
              data={report.data.series}
              value={(d) => d.revenue}
              label={(d) => d.period.replace(/^\d{4}-/, "")}
              format={inr}
            />
          </Card>

          <Card className="mt-6 overflow-hidden p-0">
            <h2 className="px-5 pt-5 text-lg font-bold">Top movies by revenue</h2>
            {report.data.topMovies.length ? (
              <Table
                head={
                  <tr>
                    <Th>Movie</Th>
                    <Th className="text-right">Bookings</Th>
                    <Th className="text-right">Revenue</Th>
                  </tr>
                }
              >
                {report.data.topMovies.map((m) => (
                  <tr key={m.title}>
                    <Td className="font-medium text-fg">{m.title}</Td>
                    <Td className="text-right">{m.bookings}</Td>
                    <Td className="text-right font-semibold text-primary">{inr(m.revenue)}</Td>
                  </tr>
                ))}
              </Table>
            ) : (
              <EmptyState icon="bar_chart" title="No bookings in this range" />
            )}
          </Card>
        </>
      ) : null}
    </>
  );
}
