import type Anthropic from "@anthropic-ai/sdk";
import { Prisma, type Role } from "@prisma/client";
import { prisma } from "../db.js";
import { notFound } from "../lib/errors.js";
import { metrics } from "../lib/metrics.js";
import { buildSystemPrompt } from "./prompt.js";
import { runConversation, type ToolCallRecord } from "./orchestrator.js";
import { customerTools, type ToolContext, type ToolDef } from "./tools.js";

// The sub-agent searches and holds, but never books or pays — those stay with
// the main assistant and the customer.
const SUB_AGENT_TOOLS = new Set([
  "searchMovies",
  "getMovieDetails",
  "getShowtimes",
  "suggestSimilar",
  "findTheatres",
  "getScreenInfo",
  "checkSeatAvailability",
  "holdSeats",
  "releaseSeats",
  "applyPromoCode",
]);
const subAgentTools = customerTools.filter((t) => SUB_AGENT_TOOLS.has(t.name));

const delegateBookingTool: ToolDef = {
  name: "delegateBooking",
  description:
    "Hand a complex booking off to a focused booking assistant. Give one clear instruction with the movie, party size, date/time, location, and seat preferences. It searches, picks a show, and HOLDS the best available seats (it does not pay), then returns a summary. Use it for multi-step 'book … for me' requests.",
  inputSchema: {
    type: "object",
    properties: { task: { type: "string", description: "Full natural-language booking instruction" } },
    required: ["task"],
  },
  handler: async (input: { task: string }, ctx) => {
    const user = await prisma.user.findUnique({ where: { id: ctx.userId } });
    const prefs = JSON.stringify(user?.preferences ?? {});
    const system = [
      "You are CineBook's booking assistant. Complete ONLY the given task, end-to-end up to holding seats.",
      `Today is ${new Date().toISOString().slice(0, 10)}. Prices are in ₹.`,
      "Steps: find the movie, find a suitable show (respect requested date/time/location/screen type), check seat availability, then HOLD the best available seats. Do NOT create a booking or take payment.",
      "Choose seats matching the requested category and quantity; prefer well-placed central seats. If several shows fit, pick the soonest evening show unless told otherwise.",
      "When done, STOP and reply with a concise summary: movie, theatre, screen type, showtime, the seat labels held, total price, and that they are held for 5 minutes. If you cannot finish, say exactly what is missing.",
      `Customer preferences: ${prefs}.`,
    ].join("\n");

    const sub = await runConversation({
      system,
      messages: [{ role: "user", content: input.task }],
      tools: subAgentTools,
      ctx,
      maxIterations: 10,
    });
    return { summary: sub.reply, toolsUsed: sub.toolCalls.map((c) => c.tool) };
  },
};

const mainTools: ToolDef[] = [...customerTools, delegateBookingTool];

// Folds successful tool calls into a small session-state object so the assistant
// keeps track of the in-flight movie / show / booking across many turns.
function deriveState(prev: Record<string, unknown>, toolCalls: ToolCallRecord[]): Record<string, unknown> {
  const state = { ...prev };
  for (const c of toolCalls) {
    if (!c.success) continue;
    const input = (c.input ?? {}) as Record<string, unknown>;
    const output = (c.output ?? {}) as Record<string, unknown>;
    switch (c.tool) {
      case "getMovieDetails":
      case "getCast":
      case "getShowtimes":
        if (input.movieId) state.lastMovieId = input.movieId;
        break;
      case "checkSeatAvailability":
        if (input.showId) state.currentShowId = input.showId;
        break;
      case "holdSeats":
        if (output.showId) {
          state.currentShowId = output.showId;
          state.heldSeatIds = output.seatIds;
        }
        break;
      case "createBooking":
        if (output.bookingId) state.currentBookingId = output.bookingId;
        break;
      case "confirmPayment":
        if (output.status === "CONFIRMED") {
          state.lastConfirmedBookingId = output.bookingId;
          delete state.currentBookingId;
          delete state.heldSeatIds;
        }
        break;
    }
  }
  return state;
}

const asJson = (v: unknown) => v as Prisma.InputJsonValue;
const asContent = (v: Prisma.JsonValue) => v as unknown as Anthropic.MessageParam["content"];

export interface ChatActor {
  userId: string;
  role: Role;
  traceId: string;
}

export async function chat(actor: ChatActor, message: string, conversationId?: string) {
  const user = await prisma.user.findUnique({ where: { id: actor.userId } });
  if (!user) throw notFound("User not found");

  let conversation = conversationId
    ? await prisma.conversation.findFirst({
        where: { id: conversationId, userId: user.id },
        include: { messages: { orderBy: { createdAt: "asc" } } },
      })
    : null;
  if (conversationId && !conversation) throw notFound("Conversation not found");
  if (!conversation) {
    conversation = await prisma.conversation.create({ data: { userId: user.id }, include: { messages: true } });
  }

  const prior: Anthropic.MessageParam[] = conversation.messages.map((m) => ({
    role: m.role as "user" | "assistant",
    content: asContent(m.content),
  }));
  const inputMessages: Anthropic.MessageParam[] = [...prior, { role: "user", content: message }];

  const state = (conversation.state ?? {}) as Record<string, unknown>;
  const ctx: ToolContext = { userId: user.id, role: actor.role, traceId: actor.traceId, conversationId: conversation.id };

  const run = await runConversation({
    system: buildSystemPrompt(user, state),
    messages: inputMessages,
    tools: mainTools,
    ctx,
    maxIterations: 14,
  });

  const newMessages = run.messages.slice(prior.length); // user turn + everything the loop appended
  const newState = deriveState(state, run.toolCalls);
  const conversationId2 = conversation.id;
  const setTitle = conversation.title ? {} : { title: message.slice(0, 60) };

  await prisma.$transaction(async (tx) => {
    for (const m of newMessages) {
      await tx.message.create({ data: { conversationId: conversationId2, role: m.role, content: asJson(m.content) } });
    }
    await tx.conversation.update({ where: { id: conversationId2 }, data: { state: asJson(newState), ...setTitle } });
    for (const c of run.toolCalls) {
      await tx.toolCallLog.create({
        data: {
          conversationId: conversationId2,
          traceId: actor.traceId,
          actorId: user.id,
          tool: c.tool,
          input: asJson(c.input),
          success: c.success,
          errorType: c.errorType ?? null,
          durationMs: c.durationMs,
        },
      });
    }
  });

  for (const c of run.toolCalls) metrics.recordToolCall(c.tool, c.success, c.durationMs);

  return {
    conversationId: conversation.id,
    reply: run.reply,
    actions: run.toolCalls.map((c) => ({ tool: c.tool, success: c.success, durationMs: c.durationMs })),
  };
}

export async function listConversations(userId: string) {
  return prisma.conversation.findMany({
    where: { userId },
    select: { id: true, title: true, createdAt: true, updatedAt: true },
    orderBy: { updatedAt: "desc" },
  });
}

export async function getConversation(userId: string, id: string) {
  const c = await prisma.conversation.findFirst({
    where: { id, userId },
    include: { messages: { orderBy: { createdAt: "asc" } } },
  });
  if (!c) throw notFound("Conversation not found");
  return {
    id: c.id,
    title: c.title,
    state: c.state,
    messages: c.messages.map((m) => ({ role: m.role, content: m.content })),
  };
}
