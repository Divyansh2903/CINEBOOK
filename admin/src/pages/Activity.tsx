import { apiGet } from "../lib/api";
import { dateTime } from "../lib/format";
import { useApi } from "../lib/useApi";
import { Badge, Card, EmptyState, ErrorState, PageHeader, Skeleton, Table, Td, Th } from "../components/ui";

interface ActivityRow {
  id: string;
  actor: string;
  actorRole: string;
  action: string;
  entity: string;
  entityId: string | null;
  createdAt: string;
}

export default function Activity() {
  const activity = useApi(() => apiGet<ActivityRow[]>("/admin/activity?limit=200"));

  return (
    <>
      <PageHeader title="Activity log" subtitle="An audit trail of admin and scheduling actions." />

      <Card className="overflow-hidden p-0">
        {activity.loading ? (
          <div className="space-y-3 p-5">
            {[0, 1, 2, 3, 4].map((i) => (
              <Skeleton key={i} className="h-7 w-full" />
            ))}
          </div>
        ) : activity.error ? (
          <ErrorState message={activity.error} onRetry={activity.refetch} />
        ) : activity.data?.length ? (
          <Table
            head={
              <tr>
                <Th>When</Th>
                <Th>Actor</Th>
                <Th>Action</Th>
                <Th>Entity</Th>
              </tr>
            }
          >
            {activity.data.map((a) => (
              <tr key={a.id}>
                <Td className="whitespace-nowrap text-xs text-muted">{dateTime(a.createdAt)}</Td>
                <Td>
                  <span className="text-fg">{a.actor}</span>
                  <span className="ml-2 text-xs text-muted">{a.actorRole}</span>
                </Td>
                <Td>
                  <Badge tone="muted">{a.action}</Badge>
                </Td>
                <Td>
                  {a.entity}
                  {a.entityId && <span className="ml-1 text-xs text-muted/60">#{a.entityId.slice(-6)}</span>}
                </Td>
              </tr>
            ))}
          </Table>
        ) : (
          <EmptyState icon="history" title="No activity yet" />
        )}
      </Card>
    </>
  );
}
