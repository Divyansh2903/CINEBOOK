import { useState } from "react";
import { ApiError, apiDelete, apiGet, apiPost } from "../lib/api";
import { useApi } from "../lib/useApi";
import { Badge, Button, Card, EmptyState, ErrorState, Field, Icon, Input, Modal, PageHeader, Select, Skeleton } from "../components/ui";

interface Chain {
  id: string;
  name: string;
}
interface Theatre {
  id: string;
  name: string;
  chain: string;
  location: string;
  address: string;
  screens: { id: string; name: string; screenType: string }[];
}

const SCREEN_TYPES = ["STANDARD", "IMAX", "FOUR_DX", "DOLBY_ATMOS"];
const CATEGORIES = ["FRONT", "STANDARD", "PREMIUM", "RECLINER"] as const;
const DEFAULT_BANDS = [
  { category: "FRONT", rows: 2, multiplier: 0.8 },
  { category: "STANDARD", rows: 5, multiplier: 1.0 },
  { category: "PREMIUM", rows: 2, multiplier: 1.4 },
  { category: "RECLINER", rows: 1, multiplier: 2.0 },
];

function useSubmit(onDone: () => void) {
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const run = async (fn: () => Promise<unknown>) => {
    setBusy(true);
    setError(null);
    try {
      await fn();
      onDone();
    } catch (e) {
      setError(e instanceof ApiError ? e.message : "Something went wrong");
    } finally {
      setBusy(false);
    }
  };
  return { busy, error, run };
}

function ChainModal({ onClose, onSaved }: { onClose: () => void; onSaved: () => void }) {
  const [name, setName] = useState("");
  const { busy, error, run } = useSubmit(onSaved);
  return (
    <Modal title="Add theatre chain" onClose={onClose}>
      <div className="space-y-4">
        <Field label="Chain name">
          <Input value={name} onChange={(e) => setName(e.target.value)} placeholder="PVR, INOX…" autoFocus />
        </Field>
        {error && <p className="text-sm text-danger">{error}</p>}
        <div className="flex justify-end gap-3">
          <Button variant="ghost" onClick={onClose}>
            Cancel
          </Button>
          <Button disabled={busy || !name} onClick={() => run(() => apiPost("/admin/chains", { name }))}>
            Save
          </Button>
        </div>
      </div>
    </Modal>
  );
}

function TheatreModal({ chains, onClose, onSaved }: { chains: Chain[]; onClose: () => void; onSaved: () => void }) {
  const [form, setForm] = useState({ chainId: chains[0]?.id ?? "", name: "", location: "", address: "" });
  const { busy, error, run } = useSubmit(onSaved);
  const set = (p: Partial<typeof form>) => setForm((f) => ({ ...f, ...p }));
  return (
    <Modal title="Add theatre" onClose={onClose}>
      <div className="space-y-4">
        <Field label="Chain">
          <Select value={form.chainId} onChange={(e) => set({ chainId: e.target.value })}>
            {chains.map((c) => (
              <option key={c.id} value={c.id}>
                {c.name}
              </option>
            ))}
          </Select>
        </Field>
        <Field label="Name">
          <Input value={form.name} onChange={(e) => set({ name: e.target.value })} placeholder="PVR Phoenix" />
        </Field>
        <div className="grid grid-cols-2 gap-3">
          <Field label="Location / area">
            <Input value={form.location} onChange={(e) => set({ location: e.target.value })} placeholder="Whitefield" />
          </Field>
          <Field label="Address">
            <Input value={form.address} onChange={(e) => set({ address: e.target.value })} />
          </Field>
        </div>
        {error && <p className="text-sm text-danger">{error}</p>}
        <div className="flex justify-end gap-3">
          <Button variant="ghost" onClick={onClose}>
            Cancel
          </Button>
          <Button
            disabled={busy || !form.chainId || !form.name || !form.location}
            onClick={() => run(() => apiPost("/admin/theatres", form))}
          >
            Save theatre
          </Button>
        </div>
      </div>
    </Modal>
  );
}

function ScreenModal({ theatre, onClose, onSaved }: { theatre: Theatre; onClose: () => void; onSaved: () => void }) {
  const [name, setName] = useState("");
  const [screenType, setScreenType] = useState("STANDARD");
  const [seatsPerRow, setSeatsPerRow] = useState(12);
  const [bands, setBands] = useState(DEFAULT_BANDS);
  const { busy, error, run } = useSubmit(onSaved);

  const updateBand = (i: number, patch: Partial<(typeof bands)[number]>) =>
    setBands((bs) => bs.map((b, idx) => (idx === i ? { ...b, ...patch } : b)));
  const capacity = bands.reduce((acc, b) => acc + b.rows, 0) * seatsPerRow;

  return (
    <Modal title={`Add screen — ${theatre.name}`} onClose={onClose}>
      <div className="space-y-4">
        <div className="grid grid-cols-2 gap-3">
          <Field label="Screen name">
            <Input value={name} onChange={(e) => setName(e.target.value)} placeholder="Screen 1" />
          </Field>
          <Field label="Type">
            <Select value={screenType} onChange={(e) => setScreenType(e.target.value)}>
              {SCREEN_TYPES.map((t) => (
                <option key={t} value={t}>
                  {t.replace("_", " ")}
                </option>
              ))}
            </Select>
          </Field>
        </div>
        <Field label="Seats per row">
          <Input type="number" value={seatsPerRow} onChange={(e) => setSeatsPerRow(Number(e.target.value))} />
        </Field>

        <div>
          <p className="mb-2 text-xs font-semibold uppercase tracking-wide text-muted">Seating layout</p>
          <div className="space-y-2">
            {bands.map((b, i) => (
              <div key={b.category} className="grid grid-cols-[1fr_auto_auto] items-center gap-2 text-sm">
                <Select value={b.category} onChange={(e) => updateBand(i, { category: e.target.value })}>
                  {CATEGORIES.map((c) => (
                    <option key={c}>{c}</option>
                  ))}
                </Select>
                <Input
                  type="number"
                  className="w-20"
                  value={b.rows}
                  onChange={(e) => updateBand(i, { rows: Number(e.target.value) })}
                  title="Rows"
                />
                <Input
                  type="number"
                  step="0.1"
                  className="w-24"
                  value={b.multiplier}
                  onChange={(e) => updateBand(i, { multiplier: Number(e.target.value) })}
                  title="Price ×"
                />
              </div>
            ))}
          </div>
          <p className="mt-2 text-xs text-muted">
            Rows × seats/row · Total capacity: <b className="text-subtle">{capacity}</b> seats
          </p>
        </div>

        {error && <p className="text-sm text-danger">{error}</p>}
        <div className="flex justify-end gap-3">
          <Button variant="ghost" onClick={onClose}>
            Cancel
          </Button>
          <Button
            disabled={busy || !name}
            onClick={() => run(() => apiPost("/admin/screens", { theatreId: theatre.id, name, screenType, seatsPerRow, bands }))}
          >
            Create screen
          </Button>
        </div>
      </div>
    </Modal>
  );
}

export default function Theatres() {
  const theatres = useApi(() => apiGet<Theatre[]>("/theatres"));
  const chains = useApi(() => apiGet<Chain[]>("/admin/chains"));
  const [modal, setModal] = useState<"chain" | "theatre" | null>(null);
  const [screenFor, setScreenFor] = useState<Theatre | null>(null);
  const [error, setError] = useState<string | null>(null);

  const refresh = () => {
    theatres.refetch();
    chains.refetch();
  };

  const removeScreen = async (id: string) => {
    if (!confirm("Delete this screen?")) return;
    setError(null);
    try {
      await apiDelete(`/admin/screens/${id}`);
      theatres.refetch();
    } catch (e) {
      setError(e instanceof ApiError ? e.message : "Delete failed");
    }
  };

  const removeTheatre = async (id: string) => {
    if (!confirm("Delete this theatre and its screens?")) return;
    setError(null);
    try {
      await apiDelete(`/admin/theatres/${id}`);
      theatres.refetch();
    } catch (e) {
      setError(e instanceof ApiError ? e.message : "Delete failed");
    }
  };

  return (
    <>
      <PageHeader
        title="Theatres"
        subtitle="Manage chains, locations, and screen configurations."
        action={
          <div className="flex gap-2">
            <Button variant="secondary" onClick={() => setModal("chain")}>
              <Icon name="add" className="text-lg" /> Chain
            </Button>
            <Button onClick={() => setModal("theatre")} disabled={!chains.data?.length}>
              <Icon name="add" className="text-lg" /> Theatre
            </Button>
          </div>
        }
      />

      {error && <p className="mb-3 text-sm text-danger">{error}</p>}

      {theatres.loading ? (
        <Skeleton className="h-40 w-full" />
      ) : theatres.error ? (
        <ErrorState message={theatres.error} onRetry={theatres.refetch} />
      ) : theatres.data?.length ? (
        <div className="grid grid-cols-1 gap-4 lg:grid-cols-2">
          {theatres.data.map((t) => (
            <Card key={t.id} className="p-5">
              <div className="flex items-start justify-between gap-3">
                <div>
                  <h3 className="text-lg font-bold">{t.name}</h3>
                  <p className="text-sm text-muted">
                    {t.chain} · {t.location}
                  </p>
                  <p className="text-xs text-muted/70">{t.address}</p>
                </div>
                <button className="text-muted hover:text-danger" onClick={() => removeTheatre(t.id)} title="Delete theatre">
                  <Icon name="delete" />
                </button>
              </div>

              <div className="mt-4 space-y-2">
                {t.screens.map((s) => (
                  <div key={s.id} className="flex items-center justify-between rounded-lg bg-surface-low px-3 py-2 text-sm">
                    <span className="flex items-center gap-2">
                      <Icon name="event_seat" className="text-base text-muted" />
                      {s.name}
                      <Badge tone="warning">{s.screenType.replace("_", " ")}</Badge>
                    </span>
                    <button className="text-muted hover:text-danger" onClick={() => removeScreen(s.id)} title="Delete screen">
                      <Icon name="close" className="text-base" />
                    </button>
                  </div>
                ))}
                {t.screens.length === 0 && <p className="text-xs text-muted">No screens yet.</p>}
              </div>

              <Button variant="ghost" className="mt-3 !px-0" onClick={() => setScreenFor(t)}>
                <Icon name="add" className="text-base" /> Add screen
              </Button>
            </Card>
          ))}
        </div>
      ) : (
        <EmptyState icon="theaters" title="No theatres yet" hint="Add a chain, then a theatre." />
      )}

      {modal === "chain" && <ChainModal onClose={() => setModal(null)} onSaved={() => { setModal(null); refresh(); }} />}
      {modal === "theatre" && chains.data && (
        <TheatreModal chains={chains.data} onClose={() => setModal(null)} onSaved={() => { setModal(null); refresh(); }} />
      )}
      {screenFor && (
        <ScreenModal theatre={screenFor} onClose={() => setScreenFor(null)} onSaved={() => { setScreenFor(null); theatres.refetch(); }} />
      )}
    </>
  );
}
