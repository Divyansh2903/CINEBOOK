import Anthropic from "@anthropic-ai/sdk";
import { config } from "../config.js";
import { AppError } from "../lib/errors.js";
import type { ToolContext, ToolDef } from "./tools.js";

const client = new Anthropic({ apiKey: config.ANTHROPIC_API_KEY });

export interface ToolCallRecord {
  tool: string;
  input: unknown;
  output: unknown;
  success: boolean;
  errorType?: string;
  durationMs: number;
}

export interface RunResult {
  reply: string;
  messages: Anthropic.MessageParam[];
  toolCalls: ToolCallRecord[];
}

export interface RunOptions {
  system: string;
  messages: Anthropic.MessageParam[];
  tools: ToolDef[];
  ctx: ToolContext;
  maxIterations?: number;
}

// The custom agentic loop: call the model, run any tool calls it requests,
// feed the results back, and repeat until it stops asking for tools. No agent
// framework and no SDK tool-runner — this loop is the architecture being shown.
export async function runConversation(opts: RunOptions): Promise<RunResult> {
  if (!config.ANTHROPIC_API_KEY) {
    throw new AppError(503, "Chat is not configured. Set ANTHROPIC_API_KEY to enable the assistant.");
  }

  const toolDefs: Anthropic.Tool[] = opts.tools.map((t) => ({
    name: t.name,
    description: t.description,
    input_schema: t.inputSchema,
  }));
  const byName = new Map(opts.tools.map((t) => [t.name, t]));
  const messages: Anthropic.MessageParam[] = [...opts.messages];
  const toolCalls: ToolCallRecord[] = [];
  const maxIterations = opts.maxIterations ?? 12;

  let reply = "";

  for (let i = 0; i < maxIterations; i++) {
    const res = await client.messages.create({
      model: config.CHAT_MODEL,
      max_tokens: 4096,
      system: opts.system,
      tools: toolDefs,
      messages,
    });

    messages.push({ role: "assistant", content: res.content });

    if (res.stop_reason !== "tool_use") {
      reply = res.content
        .filter((b): b is Anthropic.TextBlock => b.type === "text")
        .map((b) => b.text)
        .join("\n")
        .trim();
      break;
    }

    const toolUses = res.content.filter((b): b is Anthropic.ToolUseBlock => b.type === "tool_use");
    const results: Anthropic.ToolResultBlockParam[] = [];

    for (const use of toolUses) {
      const def = byName.get(use.name);
      const start = Date.now();
      let output: unknown = null;
      let isError = false;
      let errorType: string | undefined;

      try {
        if (!def) throw new AppError(400, `Unknown tool: ${use.name}`);
        output = await def.handler(use.input, opts.ctx);
      } catch (err) {
        isError = true;
        errorType = err instanceof Error ? err.name : "Error";
        output = { error: err instanceof Error ? err.message : "Tool failed" };
      }

      toolCalls.push({
        tool: use.name,
        input: use.input,
        output,
        success: !isError,
        ...(errorType ? { errorType } : {}),
        durationMs: Date.now() - start,
      });

      results.push({
        type: "tool_result",
        tool_use_id: use.id,
        content: JSON.stringify(output ?? null),
        is_error: isError,
      });
    }

    messages.push({ role: "user", content: results });
  }

  return { reply, messages, toolCalls };
}
