import { Link } from "react-router-dom";
import { apiGet } from "../lib/api";
import { useAuth } from "../lib/auth";
import { dateTime, inr } from "../lib/format";
import { useApi } from "../lib/useApi";
import { BarChart } from "../components/BarChart";
import { Badge, Card, EmptyState, Icon, PageHeader, Skeleton } from "../components/ui";

interface Stats {
  bookingsToday: number;
  revenueToday: number;
  upcomingShows: number;
  totalUsers: number;
}
interface Report {
  summary: { totalBookings: number; totalRevenue: number };
  topMovies: { title: string; bookings: number; revenue: number }[];
  series: { period: string; bookings: number; revenue: number }[];
}
interface ActivityRow {
  id: string;
  actor: string;
  action: string;
  entity: string;
  createdAt: string;
}
interface ManagedScreen {
  id: string;
  name: string;
  screenType: string;
  theatre: { name: string; chain: string; location: string };
}

function StatCard({ icon, label, value, loading }: { icon: string; label: string; value: string; loading: boolean }) {
  return (
    <Card className="p-5">
      <div className="flex items-center justify-between">
        <span className="text-xs font-semibold uppercase tracking-wide text-muted">{label}</span>
        <Icon name={icon} className="text-xl text-primary" />
      </div>
      {loading ? <Skeleton className="mt-3 h-8 w-24" /> : <p className="mt-2 text-3xl font-bold text-fg">{value}</p>}
    </Card>
  );
}

function AdminHome() {
  const stats = useApi(() => apiGet<Stats>("/admin/stats"));
  const report = useApi(() => apiGet<Report>("/admin/reports?granularity=daily"));
  const activity = useApi(() => apiGet<ActivityRow[]>("/admin/activity?limit=6"));

  return (
    <>
      <PageHeader title="Overview" subtitle="Today at a glance across CineBook." />

      <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 xl:grid-cols-4">
        <StatCard icon="confirmation_number" label="Bookings (24h)" value={String(stats.data?.bookingsToday ?? 0)} loading={stats.loading} />
        <StatCard icon="payments" label="Revenue (24h)" value={inr(stats.data?.revenueToday ?? 0)} loading={stats.loading} />
        <StatCard icon="event_seat" label="Upcoming shows" value={String(stats.data?.upcomingShows ?? 0)} loading={stats.loading} />
        <StatCard icon="group" label="Users" value={String(stats.data?.totalUsers ?? 0)} loading={stats.loading} />
      </div>

      <div className="mt-6 grid grid-cols-1 gap-6 lg:grid-cols-3">
        <Card className="p-5 lg:col-span-2">
          <h2 className="mb-4 text-lg font-bold">Revenue — last 30 days</h2>
          {report.loading ? (
            <Skeleton className="h-52 w-full" />
          ) : (
            <BarChart
              data={report.data?.series ?? []}
              value={(d) => d.revenue}
              label={(d) => d.period.slice(5)}
              format={inr}
            />
          )}
        </Card>

        <Card className="p-5">
          <h2 className="mb-4 text-lg font-bold">Top movies</h2>
          {report.loading ? (
            <div className="space-y-3">
              {[0, 1, 2].map((i) => (
                <Skeleton key={i} className="h-6 w-full" />
              ))}
            </div>
          ) : report.data?.topMovies.length ? (
            <ul className="space-y-3">
              {report.data.topMovies.map((m, i) => (
                <li key={m.title} className="flex items-center justify-between gap-3 text-sm">
                  <span className="flex min-w-0 items-center gap-2">
                    <span className="text-muted">{i + 1}.</span>
                    <span className="truncate text-subtle">{m.title}</span>
                  </span>
                  <span className="shrink-0 font-semibold text-primary">{inr(m.revenue)}</span>
                </li>
              ))}
            </ul>
          ) : (
            <EmptyState icon="movie" title="No bookings yet" />
          )}
        </Card>
      </div>

      <Card className="mt-6 p-5">
        <h2 className="mb-4 text-lg font-bold">Recent activity</h2>
        {activity.loading ? (
          <Skeleton className="h-24 w-full" />
        ) : activity.data?.length ? (
          <ul className="divide-y divide-line/60">
            {activity.data.map((a) => (
              <li key={a.id} className="flex items-center justify-between gap-3 py-2.5 text-sm">
                <span className="flex items-center gap-2">
                  <Badge tone="muted">{a.action}</Badge>
                  <span className="text-subtle">{a.entity}</span>
                  <span className="text-muted">by {a.actor}</span>
                </span>
                <span className="shrink-0 text-xs text-muted">{dateTime(a.createdAt)}</span>
              </li>
            ))}
          </ul>
        ) : (
          <EmptyState icon="history" title="No activity yet" />
        )}
      </Card>
    </>
  );
}

function ManagerHome() {
  const screens = useApi(() => apiGet<ManagedScreen[]>("/manager/screens"));
  return (
    <>
      <PageHeader title="Your screens" subtitle="Screens you can schedule shows for." />
      {screens.loading ? (
        <Skeleton className="h-32 w-full" />
      ) : screens.data?.length ? (
        <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 xl:grid-cols-3">
          {screens.data.map((s) => (
            <Card key={s.id} className="p-5">
              <div className="flex items-center justify-between">
                <h3 className="text-lg font-bold">{s.name}</h3>
                <Badge tone="warning">{s.screenType.replace("_", " ")}</Badge>
              </div>
              <p className="mt-1 text-sm text-muted">
                {s.theatre.chain} · {s.theatre.name}, {s.theatre.location}
              </p>
              <Link to="/shows" className="mt-4 inline-flex items-center gap-1 text-sm font-semibold text-primary hover:underline">
                Manage shows <Icon name="arrow_forward" className="text-base" />
              </Link>
            </Card>
          ))}
        </div>
      ) : (
        <EmptyState icon="event_seat" title="No screens assigned" hint="An admin needs to assign screens to you." />
      )}
    </>
  );
}

export default function Dashboard() {
  const { user } = useAuth();
  return user?.role === "HALL_MANAGER" ? <ManagerHome /> : <AdminHome />;
}
