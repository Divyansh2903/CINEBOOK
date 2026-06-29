import websocket from "@fastify/websocket";
import type { FastifyInstance } from "fastify";
import { eventBus } from "../lib/events.js";

// Subscribe a client to live seat events for one show. Read-only: inbound
// messages are ignored; the server pushes seat.held / seat.released / seat.booked.
export async function registerWs(app: FastifyInstance): Promise<void> {
  await app.register(websocket);

  app.get("/ws/shows/:showId", { websocket: true }, (socket, req) => {
    const { showId } = req.params as { showId: string };
    const unsubscribe = eventBus.subscribe(showId, (event) => {
      socket.send(JSON.stringify(event));
    });
    socket.on("close", unsubscribe);
    socket.on("error", unsubscribe);
  });
}
