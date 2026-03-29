import { HugeiconsIcon } from "@hugeicons/react"
import { Copy01Icon } from "@hugeicons/core-free-icons"
import { toast } from "sonner"
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "@/components/ui/table"
import { ScrollArea } from "@/components/ui/scroll-area"
import { PageHeader } from "@/components/page-header"
import { titleCase } from "@/lib/title-case"
import { formatCost } from "@/lib/format"
import type { SessionHistoryItem } from "@/types/agent"

interface SessionHistoryPageProps {
  sessions: SessionHistoryItem[] | undefined
}

export function SessionHistoryPage({ sessions }: SessionHistoryPageProps) {
  return (
    <ScrollArea className="h-full bg-card">
      <div className="flex flex-col">
        <PageHeader
          title="Session History"
          description="All recorded sessions across the agent pool"
        />

        {/* Table */}
        <div className="px-6 py-5">
          {!sessions || sessions.length === 0 ? (
            <p className="py-8 text-center text-sm text-muted-foreground">
              No sessions recorded yet.
            </p>
          ) : (
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead className="w-[40px]" />
                  <TableHead className="w-[120px]">Agent</TableHead>
                  <TableHead>Session</TableHead>
                  <TableHead className="w-[100px]">Duration</TableHead>
                  <TableHead className="w-[100px]">Cost</TableHead>
                  <TableHead className="w-[100px] text-right">When</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {sessions.map((session) => (
                  <TableRow key={session.id}>
                    <TableCell>
                      <CopySessionButton sessionId={session.id} />
                    </TableCell>
                    <TableCell className="font-medium">
                      {titleCase(session.agentId)}
                    </TableCell>
                    <TableCell>{session.title}</TableCell>
                    <TableCell>{session.duration}</TableCell>
                    <TableCell>{formatCost(session.cost)}</TableCell>
                    <TableCell className="text-right text-muted-foreground">
                      {session.completedAt}
                    </TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          )}
        </div>
      </div>
    </ScrollArea>
  )
}

function CopySessionButton({ sessionId }: { sessionId: string }) {
  const command = `opencode --session ${sessionId}`

  const handleCopy = async () => {
    await navigator.clipboard.writeText(command)
    toast(
      <span className="flex items-center gap-2 whitespace-nowrap">
        Copied session resume command
      </span>
    )
  }

  return (
    <button
      onClick={handleCopy}
      className="cursor-pointer text-muted-foreground/50 hover:text-foreground"
    >
      <HugeiconsIcon icon={Copy01Icon} className="size-3.5" />
    </button>
  )
}
