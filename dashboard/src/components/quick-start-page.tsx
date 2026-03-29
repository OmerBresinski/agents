import { ScrollArea } from '@/components/ui/scroll-area';
import { PageHeader } from '@/components/page-header';

interface QuickStartPageProps {
  bastionHost: string;
}

export function QuickStartPage({ bastionHost }: QuickStartPageProps) {
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
              Select an idle agent from the list on the Agents page. Agents with a gray dot are available.
            </p>
          </div>
          <div className="border-l border-border px-6 py-5">
            <span className="text-[0.6875rem] font-medium uppercase tracking-widest text-muted-foreground">
              Step 2
            </span>
            <h2 className="mt-2 font-heading text-sm font-normal">Connect via SSH</h2>
            <p className="mt-1 text-xs text-muted-foreground">
              Copy the SSH command from the agent detail panel and run it in your terminal.
            </p>
            <code className="mt-3 block rounded-md bg-muted px-3 py-2 font-mono text-xs">
              ssh -J {bastionHost} agent-1
            </code>
          </div>
        </div>

        {/* Steps row 2 */}
        <div className="grid grid-cols-2 border-b border-border">
          <div className="px-6 py-5">
            <span className="text-[0.6875rem] font-medium uppercase tracking-widest text-muted-foreground">
              Step 3
            </span>
            <h2 className="mt-2 font-heading text-sm font-normal">Clone and Code</h2>
            <p className="mt-1 text-xs text-muted-foreground">
              Clone your repository and start OpenCode.
            </p>
            <pre className="mt-3 rounded-md bg-muted px-3 py-2 font-mono text-xs leading-relaxed">
{`cd /workspace
git clone git@github.com:your-org/repo.git
cd repo
opencode`}
            </pre>
          </div>
          <div className="border-l border-border px-6 py-5">
            <span className="text-[0.6875rem] font-medium uppercase tracking-widest text-muted-foreground">
              Step 4
            </span>
            <h2 className="mt-2 font-heading text-sm font-normal">Disconnect</h2>
            <p className="mt-1 text-xs text-muted-foreground">
              When done, exit the SSH session. The agent returns to idle automatically.
            </p>
          </div>
        </div>

        {/* SSH Config */}
        <div className="px-6 py-5">
          <span className="text-[0.6875rem] font-medium uppercase tracking-widest text-muted-foreground">
            SSH Config (Optional)
          </span>
          <p className="mt-2 text-xs text-muted-foreground">
            Add this to ~/.ssh/config for easier access. Then connect with just{' '}
            <code className="rounded bg-muted px-1 font-mono text-xs">ssh agent-1</code>.
          </p>
          <pre className="mt-3 rounded-md bg-muted px-4 py-3 font-mono text-xs leading-relaxed">
{`Host bastion
    HostName ${bastionHost}
    User opencode

Host agent-*
    ProxyJump bastion
    User opencode`}
          </pre>
        </div>
      </div>
    </ScrollArea>
  );
}
