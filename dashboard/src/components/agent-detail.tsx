import { AnimateNumber } from 'motion-number';
import { HugeiconsIcon } from '@hugeicons/react';
import { Copy01Icon } from '@hugeicons/core-free-icons';
import { toast } from 'sonner';
import { Progress } from '@/components/ui/progress';
import { ScrollArea } from '@/components/ui/scroll-area';
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from '@/components/ui/table';
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
    <ScrollArea className="h-full bg-card">
      <div className="flex flex-col">
        {/* ── Metrics (4 cells) ────────────────────────────────── */}
        <div className="grid grid-cols-4 border-b border-border">
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
        <div className="flex-1 pb-8 pl-16 pr-8 pt-8">
          <span className="text-[0.6875rem] font-medium uppercase tracking-widest text-muted-foreground">
            Recent Sessions
          </span>
          {agentSessions.length > 0 ? (
            <div className="mt-3">
              <Table>
                <TableHeader>
                  <TableRow>
                    <TableHead className="w-[40px]" />
                    <TableHead>Session</TableHead>
                    <TableHead className="w-[100px]">Duration</TableHead>
                    <TableHead className="w-[100px]">Cost</TableHead>
                    <TableHead className="w-[100px] text-right">When</TableHead>
                  </TableRow>
                </TableHeader>
                <TableBody>
                  {agentSessions.map((session) => (
                    <TableRow key={session.id}>
                      <TableCell>
                        <CopySessionButton sessionId={session.id} />
                      </TableCell>
                      <TableCell className="font-medium">{session.title}</TableCell>
                      <TableCell>{session.duration}</TableCell>
                      <TableCell>{formatCost(session.cost)}</TableCell>
                      <TableCell className="text-right text-muted-foreground">
                        {session.completedAt}
                      </TableCell>
                    </TableRow>
                  ))}
                </TableBody>
              </Table>
            </div>
          ) : (
            <p className="mt-3 text-sm text-muted-foreground">No previous sessions</p>
          )}
        </div>
      </div>
    </ScrollArea>
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
