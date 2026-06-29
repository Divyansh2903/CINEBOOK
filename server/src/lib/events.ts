export type SeatEventType = "seat.held" | "seat.released" | "seat.booked";

export interface SeatEvent {
  type: SeatEventType;
  showId: string;
  seatIds: string[];
}

type Handler = (event: SeatEvent) => void;

// Per-show pub/sub for live seat updates. In-memory now; swap this impl for
// Redis pub/sub to fan out across backend instances without changing callers.
export interface EventBus {
  publish(event: SeatEvent): void;
  subscribe(showId: string, handler: Handler): () => void;
}

class InMemoryEventBus implements EventBus {
  private readonly topics = new Map<string, Set<Handler>>();

  publish(event: SeatEvent): void {
    for (const handler of this.topics.get(event.showId) ?? []) handler(event);
  }

  subscribe(showId: string, handler: Handler): () => void {
    const handlers = this.topics.get(showId) ?? new Set<Handler>();
    handlers.add(handler);
    this.topics.set(showId, handlers);
    return () => {
      handlers.delete(handler);
      if (handlers.size === 0) this.topics.delete(showId);
    };
  }
}

export const eventBus: EventBus = new InMemoryEventBus();
