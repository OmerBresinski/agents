import { memo } from 'react';
import {
  Bar,
  BarChart,
  CartesianGrid,
  Cell,
  Pie,
  PieChart,
  Tooltip,
  XAxis,
  YAxis,
} from 'recharts';
import {
  type ChartConfig,
  ChartContainer,
  ChartLegend,
  ChartLegendContent,
} from '@/components/ui/chart';
import {
  type CostPerAgent,
  type TokensPerAgent,
  type ModelUsage,
  type StatusBreakdown,
} from '@/hooks/use-dashboard-stats';
import { formatCost, formatTokens } from '@/lib/format';

// ── Chart configs (hoisted to module level) ──

const costChartConfig = {
  cost: { label: 'Cost', color: 'var(--chart-1)' },
} satisfies ChartConfig;

const tokenChartConfig = {
  input: { label: 'Input', color: 'var(--chart-1)' },
  output: { label: 'Output', color: 'var(--chart-2)' },
  reasoning: { label: 'Reasoning', color: 'var(--chart-3)' },
} satisfies ChartConfig;

const modelChartConfig = {
  messages: { label: 'Messages', color: 'var(--chart-1)' },
} satisfies ChartConfig;

const statusChartConfig = {
  Idle: { label: 'Idle', color: 'var(--chart-1)' },
  Active: { label: 'Active', color: 'var(--chart-3)' },
  Busy: { label: 'Busy', color: 'var(--chart-2)' },
  Offline: { label: 'Offline', color: 'var(--chart-5)' },
} satisfies ChartConfig;

const MODEL_COLORS = ['var(--chart-1)', 'var(--chart-2)', 'var(--chart-3)', 'var(--chart-4)', 'var(--chart-5)'];

// ── Tooltip Shell ─────────────────────────────────────────────────────

interface TooltipRow {
  color: string;
  label: string;
  value: string;
}

function TooltipCard({ title, rows }: { title: string; rows: TooltipRow[] }) {
  return (
    <div className="rounded-lg border border-border bg-popover px-3 py-2.5 shadow-md">
      <p className="text-[12px] font-medium text-popover-foreground">{title}</p>
      <div className="my-1.5 h-px bg-border" />
      <div className="flex flex-col gap-1">
        {rows.map((row) => (
          <div key={row.label} className="flex items-center justify-between gap-6">
            <div className="flex items-center gap-2">
              <span className="size-2 rounded-full" style={{ backgroundColor: row.color }} />
              <span className="text-[11px] text-muted-foreground">{row.label}</span>
            </div>
            <span className="font-mono text-[11px] font-medium text-popover-foreground">
              {row.value}
            </span>
          </div>
        ))}
      </div>
    </div>
  );
}

// eslint-disable-next-line @typescript-eslint/no-explicit-any
type RechartPayload = any;

// ── Charts ────────────────────────────────────────────────────────────

export const CostChart = memo(function CostChart({ data }: { data: CostPerAgent[] }) {
  if (data.length === 0) return <EmptyChart />;

  return (
    <ChartContainer config={costChartConfig} className="h-full w-full">
      <BarChart accessibilityLayer data={data} maxBarSize={40}>
        <CartesianGrid vertical={false} />
        <XAxis dataKey="agent" tickLine={false} tickMargin={8} axisLine={false} fontSize={11} />
        <YAxis tickLine={false} axisLine={false} tickFormatter={(v) => `$${v}`} fontSize={11} />
        <Tooltip
          content={({ active, payload, label }: RechartPayload) => {
            if (!active || !payload?.length) return null;
            return (
              <TooltipCard
                title={label}
                rows={[{ color: 'var(--chart-1)', label: 'Cost', value: formatCost(payload[0].value) }]}
              />
            );
          }}
        />
        <Bar dataKey="cost" fill="var(--color-cost)" radius={[4, 4, 0, 0]} minPointSize={2} />
      </BarChart>
    </ChartContainer>
  );
});

export const TokenChart = memo(function TokenChart({ data }: { data: TokensPerAgent[] }) {
  if (data.length === 0) return <EmptyChart />;

  return (
    <ChartContainer config={tokenChartConfig} className="h-full w-full">
      <BarChart accessibilityLayer data={data} maxBarSize={40}>
        <CartesianGrid vertical={false} />
        <XAxis dataKey="agent" tickLine={false} tickMargin={8} axisLine={false} fontSize={11} />
        <YAxis tickLine={false} axisLine={false} tickFormatter={(v) => formatTokens(v as number)} fontSize={11} />
        <Tooltip
          content={({ active, payload, label }: RechartPayload) => {
            if (!active || !payload?.length) return null;
            const rows: TooltipRow[] = payload.map((entry: RechartPayload) => ({
              color: entry.color ?? 'var(--chart-1)',
              label: String(entry.name).charAt(0).toUpperCase() + String(entry.name).slice(1),
              value: `${formatTokens(entry.value)} tokens`,
            }));
            return <TooltipCard title={label} rows={rows} />;
          }}
        />
        <ChartLegend content={<ChartLegendContent />} />
        <Bar dataKey="input" stackId="tokens" fill="var(--color-input)" radius={0} />
        <Bar dataKey="output" stackId="tokens" fill="var(--color-output)" radius={0} />
        <Bar dataKey="reasoning" stackId="tokens" fill="var(--color-reasoning)" radius={[4, 4, 0, 0]} />
      </BarChart>
    </ChartContainer>
  );
});

export const ModelChart = memo(function ModelChart({ data }: { data: ModelUsage[] }) {
  if (data.length === 0) return <EmptyChart />;

  return (
    <ChartContainer config={modelChartConfig} className="h-full w-full">
      <BarChart accessibilityLayer data={data} layout="vertical" maxBarSize={40}>
        <CartesianGrid horizontal={false} />
        <XAxis type="number" tickLine={false} axisLine={false} fontSize={11} />
        <YAxis
          type="category"
          dataKey="model"
          tickLine={false}
          axisLine={false}
          width={140}
          fontSize={11}
          tickFormatter={(v: string) => (v.length > 18 ? `${v.slice(0, 16)}…` : v)}
        />
        <Tooltip
          content={({ active, payload }: RechartPayload) => {
            if (!active || !payload?.length) return null;
            const d = payload[0].payload as ModelUsage;
            return (
              <TooltipCard
                title={d.model}
                rows={[{ color: payload[0].color ?? 'var(--chart-1)', label: 'Messages', value: `${payload[0].value}` }]}
              />
            );
          }}
        />
        <Bar dataKey="messages" radius={[0, 4, 4, 0]} minPointSize={2}>
          {data.map((_, i) => (
            <Cell key={i} fill={MODEL_COLORS[i % MODEL_COLORS.length]} />
          ))}
        </Bar>
      </BarChart>
    </ChartContainer>
  );
});

export const StatusChart = memo(function StatusChart({ data, total }: { data: StatusBreakdown[]; total: number }) {
  if (data.length === 0) return <EmptyChart />;

  return (
    <ChartContainer config={statusChartConfig} className="mx-auto h-full max-w-[280px]">
      <PieChart>
        <Tooltip
          content={({ active, payload }: RechartPayload) => {
            if (!active || !payload?.length) return null;
            const d = payload[0].payload as StatusBreakdown;
            return (
              <TooltipCard
                title={d.status}
                rows={[{ color: d.fill, label: 'Agents', value: `${payload[0].value}` }]}
              />
            );
          }}
        />
        <ChartLegend content={<ChartLegendContent nameKey="status" />} />
        <Pie
          data={data}
          dataKey="count"
          nameKey="status"
          innerRadius="50%"
          outerRadius="75%"
          strokeWidth={2}
          stroke="var(--background)"
        >
          {data.map((entry) => (
            <Cell key={entry.status} fill={entry.fill} />
          ))}
        </Pie>
        <text
          x="50%"
          y="45%"
          textAnchor="middle"
          dominantBaseline="central"
          className="fill-foreground font-heading text-2xl"
        >
          {total}
        </text>
        <text
          x="50%"
          y="57%"
          textAnchor="middle"
          dominantBaseline="central"
          className="fill-muted-foreground text-[10px]"
        >
          agents
        </text>
      </PieChart>
    </ChartContainer>
  );
});

function EmptyChart() {
  return (
    <div className="flex h-full items-center justify-center">
      <p className="text-sm text-muted-foreground">No data available</p>
    </div>
  );
}
