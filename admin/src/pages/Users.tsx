import { useState } from "react";
import { apiPatch, ApiError, apiGet } from "../lib/api";
import type { Role } from "../lib/auth";
import { dateOnly } from "../lib/format";
import { useApi } from "../lib/useApi";
import { Badge, Button, Card, EmptyState, ErrorState, Input, PageHeader, Select, Skeleton, Table, Td, Th } from "../components/ui";

interface UserRow {
  id: string;
  name: string;
  phone: string;
  role: Role;
  enabled: boolean;
  createdAt: string;
}

const ROLES: Role[] = ["CUSTOMER", "HALL_MANAGER", "ADMIN"];

export default function Users() {
  const [q, setQ] = useState("");
  const [role, setRole] = useState("");
  const [busyId, setBusyId] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  const params = new URLSearchParams();
  if (q) params.set("q", q);
  if (role) params.set("role", role);
  const users = useApi(() => apiGet<UserRow[]>(`/admin/users?${params.toString()}`), [q, role]);

  const patch = async (id: string, data: Record<string, unknown>) => {
    setBusyId(id);
    setError(null);
    try {
      await apiPatch(`/admin/users/${id}`, data);
      users.refetch();
    } catch (e) {
      setError(e instanceof ApiError ? e.message : "Update failed");
    } finally {
      setBusyId(null);
    }
  };

  return (
    <>
      <PageHeader title="Users" subtitle="View accounts, assign roles, and disable access." />

      <div className="mb-4 flex flex-wrap gap-3">
        <Input className="max-w-xs" placeholder="Search name or phone" value={q} onChange={(e) => setQ(e.target.value)} />
        <Select className="max-w-[180px]" value={role} onChange={(e) => setRole(e.target.value)}>
          <option value="">All roles</option>
          {ROLES.map((r) => (
            <option key={r} value={r}>
              {r}
            </option>
          ))}
        </Select>
      </div>

      {error && <p className="mb-3 text-sm text-danger">{error}</p>}

      <Card className="overflow-hidden p-0">
        {users.loading ? (
          <div className="space-y-3 p-5">
            {[0, 1, 2, 3].map((i) => (
              <Skeleton key={i} className="h-8 w-full" />
            ))}
          </div>
        ) : users.error ? (
          <ErrorState message={users.error} onRetry={users.refetch} />
        ) : users.data?.length ? (
          <Table
            head={
              <tr>
                <Th>Name</Th>
                <Th>Phone</Th>
                <Th>Role</Th>
                <Th>Status</Th>
                <Th>Joined</Th>
                <Th className="text-right">Action</Th>
              </tr>
            }
          >
            {users.data.map((u) => (
              <tr key={u.id}>
                <Td className="font-medium text-fg">{u.name}</Td>
                <Td>{u.phone}</Td>
                <Td>
                  <Select className="w-44" value={u.role} disabled={busyId === u.id} onChange={(e) => patch(u.id, { role: e.target.value })}>
                    {ROLES.map((r) => (
                      <option key={r} value={r}>
                        {r}
                      </option>
                    ))}
                  </Select>
                </Td>
                <Td>
                  <Badge tone={u.enabled ? "success" : "danger"}>{u.enabled ? "Active" : "Disabled"}</Badge>
                </Td>
                <Td>{dateOnly(u.createdAt)}</Td>
                <Td className="text-right">
                  <Button
                    variant={u.enabled ? "danger" : "secondary"}
                    disabled={busyId === u.id}
                    onClick={() => patch(u.id, { enabled: !u.enabled })}
                  >
                    {u.enabled ? "Disable" : "Enable"}
                  </Button>
                </Td>
              </tr>
            ))}
          </Table>
        ) : (
          <EmptyState icon="group" title="No users found" />
        )}
      </Card>
    </>
  );
}
