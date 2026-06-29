import { useMemo, useState } from "react";
import { ApiError, apiDelete, apiGet, apiPost } from "../lib/api";
import { dateTime, inr, toLocalInput } from "../lib/format";
import { useApi } from "../lib/useApi";
import { Badge, Button, Card, EmptyState, Field, Icon, Input, Modal, PageHeader, Select, Skeleton } from "../components/ui";

interface ManagedScreen {
  id: string;
  name: string;
  screenType: string;
  theatre: { name: string; chain: string; location: string };
}
interface MovieOption {
  id: string;
  title: string;
}
interface Show {
  id: string;
  startsAt: string;
  endsAt: string;
  basePrice: number;
  movie: { id: string; title: string };
  screen: { id: string; name: string; screenType: string };
  theatre: { name: string; chain: string };
}

function ScheduleModal({
  screen,
  movies,
  onClose,
  onSaved,
}: {
  screen: ManagedScreen;
  movies: MovieOption[];
  onClose: () => void;
  onSaved: () => void;
}) {
  const tomorrow = new Date(Date.now() + 86_400_000);
  tomorrow.setHours(18, 0, 0, 0);
  const [movieId, setMovieId] = useState(movies[0]?.id ?? "");
  const [startsAt, setStartsAt] = useState(toLocalInput(tomorrow));
  const [basePrice, setBasePrice] = useState(250);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const save = async () => {
    setBusy(true);
    setError(null);
    try {
      await apiPost("/shows", { movieId, screenId: screen.id, startsAt, basePrice });
      onSaved();
    } catch (e) {
      setError(e instanceof ApiError ? e.message : "Couldn't schedule the show");
    } finally {
      setBusy(false);
    }
  };

  return (
    <Modal title={`Schedule show — ${screen.name}`} onClose={onClose}>
      <div className="space-y-4">
        <Field label="Movie">
          <Select value={movieId} onChange={(e) => setMovieId(e.target.value)}>
            {movies.map((m) => (
              <option key={m.id} value={m.id}>
                {m.title}
              </option>
            ))}
          </Select>
        </Field>
        <div className="grid grid-cols-2 gap-3">
          <Field label="Starts at">
            <Input type="datetime-local" value={startsAt} onChange={(e) => setStartsAt(e.target.value)} />
          </Field>
          <Field label="Base price (₹)">
            <Input type="number" value={basePrice} onChange={(e) => setBasePrice(Number(e.target.value))} />
          </Field>
        </div>
        <p className="text-xs text-muted">End time is set automatically from the movie's runtime. Up to 30 days ahead; 30-min gap between shows.</p>
        {error && (
          <p className="flex items-start gap-2 rounded-lg bg-danger/10 px-3 py-2 text-sm text-danger">
            <Icon name="error" className="text-base" />
            {error}
          </p>
        )}
        <div className="flex justify-end gap-3">
          <Button variant="ghost" onClick={onClose}>
            Cancel
          </Button>
          <Button disabled={busy || !movieId} onClick={save}>
            {busy ? "Scheduling…" : "Schedule"}
          </Button>
        </div>
      </div>
    </Modal>
  );
}

export default function Shows() {
  const screens = useApi(() => apiGet<ManagedScreen[]>("/manager/screens"));
  const movies = useApi(() => apiGet<MovieOption[]>("/movies"));
  const shows = useApi(() => apiGet<Show[]>("/shows"));
  const [screenId, setScreenId] = useState<string>("");
  const [scheduleFor, setScheduleFor] = useState<ManagedScreen | null>(null);
  const [error, setError] = useState<string | null>(null);

  const selectedScreen = screens.data?.find((s) => s.id === screenId) ?? screens.data?.[0];
  const screenShows = useMemo(
    () => (shows.data ?? []).filter((s) => s.screen.id === selectedScreen?.id),
    [shows.data, selectedScreen],
  );

  const remove = async (id: string) => {
    if (!confirm("Delete this show?")) return;
    setError(null);
    try {
      await apiDelete(`/shows/${id}`);
      shows.refetch();
    } catch (e) {
      setError(e instanceof ApiError ? e.message : "Couldn't delete the show");
    }
  };

  return (
    <>
      <PageHeader
        title="Shows"
        subtitle="Schedule and manage shows for your screens."
        action={
          <Button onClick={() => selectedScreen && setScheduleFor(selectedScreen)} disabled={!selectedScreen || !movies.data?.length}>
            <Icon name="add" className="text-lg" /> Schedule show
          </Button>
        }
      />

      {screens.loading ? (
        <Skeleton className="h-10 w-72" />
      ) : screens.data?.length ? (
        <div className="mb-5 flex flex-wrap gap-2">
          {screens.data.map((s) => (
            <button
              key={s.id}
              onClick={() => setScreenId(s.id)}
              className={`rounded-lg px-3 py-2 text-sm font-semibold transition ${
                s.id === selectedScreen?.id ? "gold-glow bg-surface-container text-primary" : "bg-surface-low text-muted hover:text-primary"
              }`}
            >
              {s.theatre.chain} · {s.name}
              <span className="ml-2 text-xs opacity-70">{s.screenType.replace("_", " ")}</span>
            </button>
          ))}
        </div>
      ) : (
        <EmptyState icon="event_seat" title="No screens assigned" hint="An admin needs to assign screens to you." />
      )}

      {error && <p className="mb-3 text-sm text-danger">{error}</p>}

      {selectedScreen && (
        <Card className="p-5">
          <div className="mb-3 flex items-center justify-between">
            <h2 className="text-lg font-bold">{selectedScreen.theatre.name}</h2>
            <span className="text-sm text-muted">{selectedScreen.theatre.location}</span>
          </div>
          {shows.loading ? (
            <Skeleton className="h-24 w-full" />
          ) : screenShows.length ? (
            <ul className="divide-y divide-line/60">
              {screenShows.map((s) => (
                <li key={s.id} className="flex items-center justify-between gap-3 py-3">
                  <div>
                    <p className="font-semibold text-fg">{s.movie.title}</p>
                    <p className="text-sm text-muted">
                      {dateTime(s.startsAt)} → {new Date(s.endsAt).toLocaleTimeString("en-IN", { hour: "2-digit", minute: "2-digit" })}
                    </p>
                  </div>
                  <div className="flex items-center gap-3">
                    <Badge tone="muted">{inr(s.basePrice)} base</Badge>
                    <button className="text-muted hover:text-danger" onClick={() => remove(s.id)} title="Delete show">
                      <Icon name="delete" />
                    </button>
                  </div>
                </li>
              ))}
            </ul>
          ) : (
            <EmptyState icon="schedule" title="No upcoming shows" hint="Schedule one for this screen." />
          )}
        </Card>
      )}

      {scheduleFor && movies.data && (
        <ScheduleModal
          screen={scheduleFor}
          movies={movies.data}
          onClose={() => setScheduleFor(null)}
          onSaved={() => {
            setScheduleFor(null);
            shows.refetch();
          }}
        />
      )}
    </>
  );
}
