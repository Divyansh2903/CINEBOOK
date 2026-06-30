// In-memory metrics, Prometheus-ready. Counters and sum/count summaries are kept
// per label-set and rendered in the text exposition format. Swap this for a
// shared store (Redis/StatsD) when running more than one instance.

type Labels = Record<string, string | number>;

function key(labels: Labels): string {
  const keys = Object.keys(labels).sort();
  return keys.map((k) => `${k}=${labels[k]}`).join(",");
}

function escapeLabel(value: string): string {
  return value.replace(/\\/g, "\\\\").replace(/\n/g, "\\n").replace(/"/g, '\\"');
}

function renderLabels(labels: Labels): string {
  const parts = Object.keys(labels)
    .sort()
    .map((k) => `${k}="${escapeLabel(String(labels[k]))}"`);
  return parts.length ? `{${parts.join(",")}}` : "";
}

class Counter {
  private readonly series = new Map<string, { labels: Labels; value: number }>();
  constructor(
    readonly name: string,
    readonly help: string,
  ) {}

  inc(labels: Labels = {}, by = 1): void {
    const k = key(labels);
    const existing = this.series.get(k);
    if (existing) existing.value += by;
    else this.series.set(k, { labels, value: by });
  }

  entries() {
    return [...this.series.values()];
  }

  render(): string {
    const lines = [`# HELP ${this.name} ${this.help}`, `# TYPE ${this.name} counter`];
    for (const s of this.series.values()) lines.push(`${this.name}${renderLabels(s.labels)} ${s.value}`);
    return lines.join("\n");
  }
}

// Tracks count + sum per label-set; enough to derive averages (avg = sum/count).
class Summary {
  private readonly series = new Map<string, { labels: Labels; count: number; sum: number }>();
  constructor(
    readonly name: string,
    readonly help: string,
  ) {}

  observe(labels: Labels, value: number): void {
    const k = key(labels);
    const existing = this.series.get(k);
    if (existing) {
      existing.count += 1;
      existing.sum += value;
    } else {
      this.series.set(k, { labels, count: 1, sum: value });
    }
  }

  entries() {
    return [...this.series.values()];
  }

  render(): string {
    const lines = [`# HELP ${this.name} ${this.help}`, `# TYPE ${this.name} summary`];
    for (const s of this.series.values()) {
      lines.push(`${this.name}_sum${renderLabels(s.labels)} ${s.sum}`);
      lines.push(`${this.name}_count${renderLabels(s.labels)} ${s.count}`);
    }
    return lines.join("\n");
  }
}

const httpRequests = new Counter("http_requests_total", "Total HTTP requests by route and status.");
const httpDuration = new Summary("http_request_duration_ms", "HTTP request duration in ms by route.");
const errors = new Counter("errors_total", "Total error responses (status >= 400) by type and status.");
const toolCalls = new Counter("chatbot_tool_calls_total", "Chatbot tool invocations by tool and outcome.");
const toolDuration = new Summary("chatbot_tool_duration_ms", "Chatbot tool latency in ms by tool.");

const startedAt = Date.now();

export const metrics = {
  recordHttp(method: string, route: string, status: number, durationMs: number): void {
    httpRequests.inc({ method, route, status });
    httpDuration.observe({ route }, durationMs);
    if (status >= 400) errors.inc({ type: statusClass(status), status });
  },

  recordToolCall(tool: string, success: boolean, durationMs: number): void {
    toolCalls.inc({ tool, success: String(success) });
    toolDuration.observe({ tool }, durationMs);
  },

  render(extraGauges: Record<string, number> = {}): string {
    const blocks = [
      httpRequests.render(),
      httpDuration.render(),
      errors.render(),
      toolCalls.render(),
      toolDuration.render(),
      `# HELP process_uptime_seconds Process uptime in seconds.\n# TYPE process_uptime_seconds gauge\nprocess_uptime_seconds ${(Date.now() - startedAt) / 1000}`,
    ];
    for (const [name, value] of Object.entries(extraGauges)) {
      blocks.push(`# TYPE ${name} gauge\n${name} ${value}`);
    }
    return `${blocks.join("\n\n")}\n`;
  },

  // Rolled-up view for humans / the admin dashboard.
  summary() {
    const requestEntries = httpRequests.entries();
    const totalRequests = requestEntries.reduce((a, e) => a + e.value, 0);
    const errorRequests = requestEntries
      .filter((e) => Number(e.labels.status) >= 400)
      .reduce((a, e) => a + e.value, 0);

    const errorsByType: Record<string, number> = {};
    for (const e of errors.entries()) {
      errorsByType[String(e.labels.status)] = (errorsByType[String(e.labels.status)] ?? 0) + e.value;
    }

    const toolLatency: Record<string, { calls: number; avgMs: number }> = {};
    for (const e of toolDuration.entries()) {
      toolLatency[String(e.labels.tool)] = {
        calls: e.count,
        avgMs: Math.round(e.sum / e.count),
      };
    }

    const toolFailures = toolCalls
      .entries()
      .filter((e) => e.labels.success === "false")
      .reduce((a, e) => a + e.value, 0);
    const toolTotal = toolCalls.entries().reduce((a, e) => a + e.value, 0);

    return {
      uptimeSeconds: Math.round((Date.now() - startedAt) / 1000),
      requests: {
        total: totalRequests,
        errors: errorRequests,
        errorRate: totalRequests ? Number((errorRequests / totalRequests).toFixed(4)) : 0,
        byErrorStatus: errorsByType,
      },
      tools: {
        totalCalls: toolTotal,
        failureRate: toolTotal ? Number((toolFailures / toolTotal).toFixed(4)) : 0,
        latencyByTool: toolLatency,
      },
    };
  },
};

function statusClass(status: number): string {
  if (status >= 500) return "5xx";
  if (status >= 400) return "4xx";
  return "other";
}
