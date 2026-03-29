import { AnimateNumber } from 'motion-number';
import { HugeiconsIcon } from '@hugeicons/react';
import { Copy01Icon } from '@hugeicons/core-free-icons';
import { toast } from 'sonner';
import { Progress } from '@/components/ui/progress';
import { ScrollArea } from '@/components/ui/scroll-area';
import { formatCost } from '@/lib/format';
import type { Agent, SessionHistoryItem } from '@/types/agent';

interface AgentDetailProps {
  agent: Agent;
  recentSessions: SessionHistoryItem[];
}

const springTransition = {
  duration: 0.8,
  type: 'spring' as const,
  bounce: 0.15,
};

export function AgentDetail({ agent, recentSessions }: AgentDetailProps) {
  const agentSessions = recentSessions.filter((s) => s.agentId === agent.id);

  const metrics: {
    label: string;
    numericValue?: number;
    textValue?: string;
    suffix?: string;
    isCurrency?: boolean;
    showProgress?: boolean;
  }[] = [
    { label: 'CPU', numericValue: agent.resources.cpu, suffix: '%', showProgress: true },
    { label: 'Memory', numericValue: agent.resources.memory, suffix: ' MB' },
    { label: 'Uptime', textValue: agent.uptime },
    { label: 'Cost', numericValue: agent.session.cost ?? 0, isCurrency: true },
  ];

  return (
    <div className="flex h-full flex-col bg-card">
      {/* ── Metrics (fixed at top) ───────────────────────────── */}
      <div className="grid shrink-0 grid-cols-4 border-b border-border">
        {metrics.map((metric, i) => (
          <div
            key={metric.label}
            className={`flex h-[200px] flex-col justify-center gap-2 pb-8 pl-16 pr-8 pt-8 ${i > 0 ? 'border-l border-border' : ''}`}
          >
            <span className="text-[11px] text-muted-foreground">{metric.label}</span>
            <div className="font-heading text-[42px] font-normal leading-tight">
              {metric.numericValue !== undefined ? (
                <AnimateNumber
                  transition={springTransition}
                  prefix={metric.isCurrency ? '$' : undefined}
                  suffix={metric.suffix}
                  format={
                    metric.isCurrency
                      ? { minimumFractionDigits: 2, maximumFractionDigits: 2 }
                      : undefined
                  }
                >
                  {metric.numericValue}
                </AnimateNumber>
              ) : (
                <span>{metric.textValue}</span>
              )}
            </div>
            {metric.showProgress && <Progress value={agent.resources.cpu} />}
          </div>
        ))}
      </div>

      {/* ── Recent Sessions ──────────────────────────────────── */}
      <div className="flex min-h-0 flex-1 flex-col">
        <div className="shrink-0 px-8 pl-16 pt-8">
          <span className="text-[0.6875rem] font-medium uppercase tracking-widest text-muted-foreground">
            Recent Sessions
          </span>
        </div>
        {agentSessions.length > 0 ? (
          <>
            {/* Fixed header */}
            <div className="shrink-0 border-b border-border px-8 pl-16 pt-4">
              <table className="w-full">
                <thead>
                  <tr>
                    <th className="w-[48px] pb-3" />
                    <th className="pb-3 text-left text-sm font-medium text-muted-foreground">Session</th>
                    <th className="w-[120px] pb-3 text-left text-sm font-medium text-muted-foreground">Duration</th>
                    <th className="w-[120px] pb-3 text-left text-sm font-medium text-muted-foreground">Cost</th>
                    <th className="w-[120px] pb-3 text-right text-sm font-medium text-muted-foreground">When</th>
                  </tr>
                </thead>
              </table>
            </div>
            {/* Scrollable body */}
            <ScrollArea className="min-h-0 flex-1">
              <div className="px-8 pb-8 pl-16">
                <table className="w-full">
                  <tbody>
                    {agentSessions.map((session) => (
                      <tr key={session.id} className="h-14 border-b border-border last:border-0">
                        <td className="w-[48px]">
                          <CopySessionButton sessionId={session.id} />
                        </td>
                        <td className="text-sm font-medium">{session.title}</td>
                        <td className="w-[120px] text-sm">{session.duration}</td>
                        <td className="w-[120px] text-sm">{formatCost(session.cost)}</td>
                        <td className="w-[120px] text-right text-sm text-muted-foreground">
                          {session.completedAt}
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </ScrollArea>
          </>
        ) : (
          <p className="px-8 pb-8 pl-16 pt-4 text-sm text-muted-foreground">
            No previous sessions
          </p>
        )}
      </div>
    </div>
  );
}

function CopySessionButton({ sessionId }: { sessionId: string }) {
  const command = `opencode --session ${sessionId}`;

  const handleCopy = async () => {
    await navigator.clipboard.writeText(command);
    toast(
      <span className="flex items-center gap-2 whitespace-nowrap">
        Copied session resume command
      </span>,
    );
  };

  return (
    <button
      onClick={handleCopy}
      className="cursor-pointer text-muted-foreground/50 hover:text-foreground"
    >
      <HugeiconsIcon icon={Copy01Icon} className="size-3.5" />
    </button>
  );
}
