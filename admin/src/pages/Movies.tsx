import { useEffect, useState } from "react";
import { ApiError, apiDelete, apiGet, apiPatch, apiPost } from "../lib/api";
import { dateOnly } from "../lib/format";
import { useApi } from "../lib/useApi";
import { Badge, Button, Card, EmptyState, ErrorState, Field, Icon, Input, Modal, PageHeader, Select, Skeleton } from "../components/ui";

interface MovieRow {
  id: string;
  title: string;
  posterUrl: string | null;
  ageRating: string;
  language: string;
  format: string;
  runtimeMin: number;
  releaseDate: string;
  trending: boolean;
  genres: string[];
}

interface MovieDetail extends MovieRow {
  description: string;
  trailerUrl: string | null;
}

interface FormState {
  title: string;
  description: string;
  runtimeMin: string;
  releaseDate: string;
  ageRating: string;
  language: string;
  format: string;
  posterUrl: string;
  trailerUrl: string;
  genres: string;
  trending: boolean;
}

const empty: FormState = {
  title: "",
  description: "",
  runtimeMin: "120",
  releaseDate: "",
  ageRating: "UA",
  language: "English",
  format: "TWO_D",
  posterUrl: "",
  trailerUrl: "",
  genres: "",
  trending: false,
};

function MovieModal({ id, onClose, onSaved }: { id: string | null; onClose: () => void; onSaved: () => void }) {
  const editing = id !== null;
  const [form, setForm] = useState<FormState>(empty);
  const [loading, setLoading] = useState(editing);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!editing) return;
    apiGet<MovieDetail>(`/movies/${id}`)
      .then((m) =>
        setForm({
          title: m.title,
          description: m.description,
          runtimeMin: String(m.runtimeMin),
          releaseDate: m.releaseDate.slice(0, 10),
          ageRating: m.ageRating,
          language: m.language,
          format: m.format,
          posterUrl: m.posterUrl ?? "",
          trailerUrl: m.trailerUrl ?? "",
          genres: m.genres.join(", "),
          trending: m.trending,
        }),
      )
      .catch((e: Error) => setError(e.message))
      .finally(() => setLoading(false));
  }, [id, editing]);

  const set = (patch: Partial<FormState>) => setForm((f) => ({ ...f, ...patch }));

  const save = async () => {
    setBusy(true);
    setError(null);
    const body = {
      title: form.title,
      description: form.description,
      runtimeMin: Number(form.runtimeMin),
      releaseDate: form.releaseDate,
      ageRating: form.ageRating,
      language: form.language,
      format: form.format,
      posterUrl: form.posterUrl || undefined,
      trailerUrl: form.trailerUrl || undefined,
      trending: form.trending,
      genres: form.genres.split(",").map((g) => g.trim()).filter(Boolean),
    };
    try {
      if (editing) await apiPatch(`/admin/movies/${id}`, body);
      else await apiPost("/admin/movies", body);
      onSaved();
    } catch (e) {
      setError(e instanceof ApiError ? e.message : "Save failed");
    } finally {
      setBusy(false);
    }
  };

  return (
    <Modal title={editing ? "Edit movie" : "Add movie"} onClose={onClose}>
      {loading ? (
        <Skeleton className="h-64 w-full" />
      ) : (
        <div className="space-y-4">
          <Field label="Title">
            <Input value={form.title} onChange={(e) => set({ title: e.target.value })} />
          </Field>
          <Field label="Description">
            <textarea
              className="w-full rounded-lg border border-line bg-surface-low px-3 py-2 text-sm text-fg outline-none focus:border-primary"
              rows={3}
              value={form.description}
              onChange={(e) => set({ description: e.target.value })}
            />
          </Field>
          <div className="grid grid-cols-2 gap-3">
            <Field label="Runtime (min)">
              <Input type="number" value={form.runtimeMin} onChange={(e) => set({ runtimeMin: e.target.value })} />
            </Field>
            <Field label="Release date">
              <Input type="date" value={form.releaseDate} onChange={(e) => set({ releaseDate: e.target.value })} />
            </Field>
            <Field label="Age rating">
              <Select value={form.ageRating} onChange={(e) => set({ ageRating: e.target.value })}>
                {["U", "UA", "A"].map((r) => (
                  <option key={r}>{r}</option>
                ))}
              </Select>
            </Field>
            <Field label="Format">
              <Select value={form.format} onChange={(e) => set({ format: e.target.value })}>
                <option value="TWO_D">2D</option>
                <option value="THREE_D">3D</option>
              </Select>
            </Field>
            <Field label="Language">
              <Input value={form.language} onChange={(e) => set({ language: e.target.value })} />
            </Field>
            <Field label="Genres (comma-separated)">
              <Input value={form.genres} onChange={(e) => set({ genres: e.target.value })} placeholder="Sci-Fi, Action" />
            </Field>
          </div>
          <Field label="Poster URL">
            <Input value={form.posterUrl} onChange={(e) => set({ posterUrl: e.target.value })} />
          </Field>
          <Field label="Trailer URL">
            <Input value={form.trailerUrl} onChange={(e) => set({ trailerUrl: e.target.value })} />
          </Field>
          <label className="flex items-center gap-2 text-sm text-subtle">
            <input type="checkbox" checked={form.trending} onChange={(e) => set({ trending: e.target.checked })} />
            Mark as trending
          </label>

          {error && <p className="text-sm text-danger">{error}</p>}
          <div className="flex justify-end gap-3 pt-2">
            <Button variant="ghost" onClick={onClose}>
              Cancel
            </Button>
            <Button onClick={save} disabled={busy || !form.title || !form.releaseDate}>
              {busy ? "Saving…" : "Save movie"}
            </Button>
          </div>
        </div>
      )}
    </Modal>
  );
}

export default function Movies() {
  const movies = useApi(() => apiGet<MovieRow[]>("/movies"));
  const [modal, setModal] = useState<{ id: string | null } | null>(null);
  const [error, setError] = useState<string | null>(null);

  const remove = async (id: string, title: string) => {
    if (!confirm(`Delete "${title}"? This can't be undone.`)) return;
    setError(null);
    try {
      await apiDelete(`/admin/movies/${id}`);
      movies.refetch();
    } catch (e) {
      setError(e instanceof ApiError ? e.message : "Delete failed");
    }
  };

  return (
    <>
      <PageHeader
        title="Movie catalog"
        subtitle="Add and manage the films CineBook offers."
        action={
          <Button onClick={() => setModal({ id: null })}>
            <Icon name="add" className="text-lg" /> Add movie
          </Button>
        }
      />

      {error && <p className="mb-3 text-sm text-danger">{error}</p>}

      {movies.loading ? (
        <div className="grid grid-cols-2 gap-4 sm:grid-cols-3 lg:grid-cols-4">
          {[0, 1, 2, 3].map((i) => (
            <Skeleton key={i} className="h-72 w-full" />
          ))}
        </div>
      ) : movies.error ? (
        <ErrorState message={movies.error} onRetry={movies.refetch} />
      ) : movies.data?.length ? (
        <div className="grid grid-cols-2 gap-4 sm:grid-cols-3 lg:grid-cols-4">
          {movies.data.map((m) => (
            <Card key={m.id} className="overflow-hidden">
              <div className="aspect-[2/3] bg-surface-high">
                {m.posterUrl && <img src={m.posterUrl} alt={m.title} className="h-full w-full object-cover" />}
              </div>
              <div className="p-3">
                <div className="flex items-start justify-between gap-2">
                  <h3 className="truncate font-semibold text-fg" title={m.title}>
                    {m.title}
                  </h3>
                  {m.trending && <Badge tone="warning">Trending</Badge>}
                </div>
                <p className="mt-1 text-xs text-muted">
                  {m.language} · {m.format === "THREE_D" ? "3D" : "2D"} · {m.ageRating} · {dateOnly(m.releaseDate)}
                </p>
                <div className="mt-3 flex gap-2">
                  <Button variant="secondary" className="flex-1 !py-1.5 text-xs" onClick={() => setModal({ id: m.id })}>
                    Edit
                  </Button>
                  <Button variant="danger" className="!px-2 !py-1.5" onClick={() => remove(m.id, m.title)}>
                    <Icon name="delete" className="text-base" />
                  </Button>
                </div>
              </div>
            </Card>
          ))}
        </div>
      ) : (
        <EmptyState icon="movie" title="No movies yet" hint="Add your first film to the catalog." />
      )}

      {modal && (
        <MovieModal
          id={modal.id}
          onClose={() => setModal(null)}
          onSaved={() => {
            setModal(null);
            movies.refetch();
          }}
        />
      )}
    </>
  );
}
