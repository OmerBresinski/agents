import { Link } from 'react-router-dom';
import { ScrollArea } from '@/components/ui/scroll-area';
import { cn } from '@/lib/utils';
import { titleCase } from '@/lib/title-case';
import type { Agent, AgentStatus } from '@/types/agent';

interface AgentListProps {
  agents: Agent[];
  selectedAgentId: string | null;
}

const statusLabel: Record<AgentStatus, string> = {
  idle: 'Idle',
  active: 'Active',
  busy: 'Busy',
  offline: 'Offline',
};

const statusColor: Record<AgentStatus, string> = {
  idle: 'text-muted-foreground',
  active: 'text-status-active',
  busy: 'text-status-busy',
  offline: 'text-status-offline',
};

export function AgentList({ agents, selectedAgentId }: AgentListProps) {
  return (
    <div className="flex h-full flex-col border-r border-border bg-[#FAF8F7] dark:bg-[#1a1918]">
      <ScrollArea className="flex-1">
        <div className="flex flex-col">
          {agents.map((agent) => (
            <Link
              key={agent.id}
              to={`/agents/${agent.id}`}
              className={cn(
                'flex h-[101px] w-full cursor-pointer items-center gap-4 overflow-hidden px-5 text-left transition-colors',
                'hover:bg-[#F5F0EA] dark:hover:bg-[#252321]',
                selectedAgentId === agent.id && 'bg-[#F5F0EA] dark:bg-[#2a2826]',
              )}
            >
              <div className="flex w-0 min-w-0 flex-1 flex-col gap-1.5">
                <span className="truncate text-[15px] font-normal">{titleCase(agent.id)}</span>
                <span className="truncate text-[12px] text-muted-foreground">
                  {agent.session.title || 'No active session'}
                </span>
                {agent.session.duration && (
                  <div className="flex items-center gap-2 text-[11px] text-muted-foreground/70">
                    <span>{agent.session.duration}</span>
                    <span>&middot;</span>
                    <span>{agent.resources.cpu}% cpu</span>
                  </div>
                )}
              </div>
              <span className={cn('shrink-0 text-[10px] font-medium', statusColor[agent.status])}>
                {statusLabel[agent.status]}
              </span>
            </Link>
          ))}
        </div>
      </ScrollArea>
    </div>
  );
}
