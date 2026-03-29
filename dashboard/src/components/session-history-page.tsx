import { HugeiconsIcon } from '@hugeicons/react';
import { Copy01Icon } from '@hugeicons/core-free-icons';
import { toast } from 'sonner';
import { ScrollArea } from '@/components/ui/scroll-area';
import { PageHeader } from '@/components/page-header';
import { titleCase } from '@/lib/title-case';
import { formatCost } from '@/lib/format';
import type { SessionHistoryItem } from '@/types/agent';

interface SessionHistoryPageProps {
  sessions: SessionHistoryItem[] | undefined;
}

export function SessionHistoryPage({ sessions }: SessionHistoryPageProps) {
  return (
    <div className="flex h-full flex-col bg-card">
      <PageHeader
        title="Session History"
        description="All recorded sessions across the agent pool"
      />

      {!sessions || sessions.length === 0 ? (
        <p className="px-8 py-8 text-center text-sm text-muted-foreground">
          No sessions recorded yet.
        </p>
      ) : (
        <>
          {/* Fixed header */}
          <div className="shrink-0 border-b border-border px-8 pt-4">
            <table className="w-full">
              <thead>
                <tr>
                  <th className="w-[48px] pb-3" />
                  <th className="w-[140px] pb-3 text-left text-sm font-medium text-muted-foreground">Agent</th>
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
            <div className="px-8 pb-8">
              <table className="w-full">
                <tbody>
                  {sessions.map((session) => (
                    <tr key={session.id} className="h-14 border-b border-border last:border-0">
                      <td className="w-[48px]">
                        <CopySessionButton sessionId={session.id} />
                      </td>
                      <td className="w-[140px] text-sm font-medium">
                        {titleCase(session.agentId)}
                      </td>
                      <td className="text-sm">{session.title}</td>
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
      )}
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
