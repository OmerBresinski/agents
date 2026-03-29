import { HugeiconsIcon } from '@hugeicons/react';
import { Copy01Icon } from '@hugeicons/core-free-icons';
import { toast } from 'sonner';
import { Button } from '@/components/ui/button';
import { ScrollArea } from '@/components/ui/scroll-area';
import { PageHeader } from '@/components/page-header';
import { useBastionConfig } from '@/hooks/use-health';

export function QuickStartPage() {
  const bastion = useBastionConfig();
  const sshBastion = `ssh -p ${bastion.port} ${bastion.user}@${bastion.host}`;
  const sshConfig = `Host bastion\n    HostName ${bastion.host}\n    Port ${bastion.port}\n    User ${bastion.user}\n\nHost agent-*\n    ProxyJump bastion\n    User ${bastion.user}`;

  const handleCopy = async (text: string) => {
    await navigator.clipboard.writeText(text);
    toast(
      <span className="flex items-center gap-2 whitespace-nowrap">
        Copied{' '}
        <code className="rounded bg-muted px-1.5 py-0.5 font-mono text-xs font-normal">
          {text}
        </code>
      </span>,
    );
  };

  return (
    <ScrollArea className="h-full bg-card">
      <div className="flex flex-col">
        <PageHeader
          title="Quick Start Guide"
          description="Get started with the OpenCode Agent Pool"
        />

        {/* Steps row 1 */}
        <div className="grid grid-cols-2 border-b border-border">
          <div className="px-6 py-5">
            <span className="text-[0.6875rem] font-medium uppercase tracking-widest text-muted-foreground">
              Step 1
            </span>
            <h2 className="mt-2 font-heading text-sm font-normal">Pick an Agent</h2>
            <p className="mt-1 text-xs text-muted-foreground">
              Select an idle agent from the list on the Agents page.
            </p>
          </div>
          <div className="border-l border-border px-6 py-5">
            <span className="text-[0.6875rem] font-medium uppercase tracking-widest text-muted-foreground">
              Step 2
            </span>
            <h2 className="mt-2 font-heading text-sm font-normal">Connect to Bastion</h2>
            <p className="mt-1 text-xs text-muted-foreground">
              SSH into the bastion host.
            </p>
            <CommandBlock command={sshBastion} onCopy={handleCopy} />
          </div>
        </div>

        {/* Steps row 2 */}
        <div className="grid grid-cols-2 border-b border-border">
          <div className="px-6 py-5">
            <span className="text-[0.6875rem] font-medium uppercase tracking-widest text-muted-foreground">
              Step 3
            </span>
            <h2 className="mt-2 font-heading text-sm font-normal">SSH into Agent</h2>
            <p className="mt-1 text-xs text-muted-foreground">
              From the bastion, connect to your chosen agent.
            </p>
            <CommandBlock command="ssh agent-1" onCopy={handleCopy} />
          </div>
          <div className="border-l border-border px-6 py-5">
            <span className="text-[0.6875rem] font-medium uppercase tracking-widest text-muted-foreground">
              Step 4
            </span>
            <h2 className="mt-2 font-heading text-sm font-normal">Start OpenCode</h2>
            <p className="mt-1 text-xs text-muted-foreground">
              Once connected, start OpenCode to begin working.
            </p>
            <CommandBlock command="opencode" onCopy={handleCopy} />
          </div>
        </div>

        {/* SSH Config */}
        <div className="px-6 py-5">
          <span className="text-[0.6875rem] font-medium uppercase tracking-widest text-muted-foreground">
            SSH Config (Optional)
          </span>
          <p className="mt-2 text-xs text-muted-foreground">
            Add this to <code className="rounded bg-muted px-1 font-mono">~/.ssh/config</code> for easier access.
            Then connect with just <code className="rounded bg-muted px-1 font-mono">ssh agent-1</code>.
          </p>
          <div className="mt-3 flex items-start gap-2">
            <pre className="min-w-0 flex-1 rounded-md bg-muted px-4 py-3 font-mono text-xs leading-relaxed">
              {sshConfig}
            </pre>
            <Button
              variant="outline"
              size="sm"
              className="shrink-0"
              onClick={() => handleCopy(sshConfig)}
            >
              <HugeiconsIcon icon={Copy01Icon} data-icon="inline-start" />
              Copy
            </Button>
          </div>
        </div>
      </div>
    </ScrollArea>
  );
}

function CommandBlock({ command, onCopy }: { command: string; onCopy: (text: string) => void }) {
  return (
    <div className="mt-3 flex items-center gap-2">
      <code className="min-w-0 flex-1 truncate rounded-md bg-muted px-3 py-2 font-mono text-xs">
        {command}
      </code>
      <Button
        variant="outline"
        size="sm"
        className="shrink-0"
        onClick={() => onCopy(command)}
      >
        <HugeiconsIcon icon={Copy01Icon} data-icon="inline-start" />
        Copy
      </Button>
    </div>
  );
}
