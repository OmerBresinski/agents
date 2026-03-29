import { useEffect, useState } from 'react';
import { BrowserRouter, Routes, Route, Navigate, useNavigate, useParams, useLocation } from 'react-router-dom';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { TooltipProvider } from '@/components/ui/tooltip';
import { SidebarProvider, SidebarInset } from '@/components/ui/sidebar';
import { AppSidebar } from '@/components/app-sidebar';
import { AgentList } from '@/components/agent-list';
import { AgentDetail } from '@/components/agent-detail';
import { SessionHistoryPage } from '@/components/session-history-page';
import { QuickStartPage } from '@/components/quick-start-page';
import { PageHeader } from '@/components/page-header';
import DashboardPage from '@/components/dashboard-page';
import { Skeleton } from '@/components/ui/skeleton';
import { Toaster } from '@/components/ui/sonner';
import { useAgents, usePoolSummary, useSessionHistory } from '@/hooks/use-agents';

const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      retry: 2,
      refetchOnWindowFocus: true,
    },
  },
});

const BASTION_HOST = import.meta.env.VITE_BASTION_HOST || 'bastion.railway.app';

function useThemeToggle() {
  const [isDark, setIsDark] = useState(() => {
    if (typeof window !== 'undefined') {
      const stored = localStorage.getItem('theme');
      if (stored === 'dark') {
        document.documentElement.classList.add('dark');
        return true;
      }
      if (stored === 'light') {
        return false;
      }
      return document.documentElement.classList.contains('dark');
    }
    return false;
  });

  const toggleTheme = () => {
    setIsDark((prev) => {
      const next = !prev;
      document.documentElement.classList.toggle('dark', next);
      localStorage.setItem('theme', next ? 'dark' : 'light');
      return next;
    });
  };

  return { isDark, toggleTheme };
}

function Layout() {
  const { isDark, toggleTheme } = useThemeToggle();
  const location = useLocation();

  const currentPage = location.pathname.startsWith('/dashboard')
    ? 'dashboard'
    : location.pathname.startsWith('/history')
      ? 'history'
      : location.pathname.startsWith('/guide')
        ? 'guide'
        : 'agents';

  const isDashboard = currentPage === 'dashboard';

  return (
    <SidebarProvider defaultOpen={false}>
      <AppSidebar
        currentPage={currentPage}
        isDark={isDark}
        onToggleTheme={toggleTheme}
      />
      <SidebarInset className="flex h-screen min-h-0 flex-col">
        {/* Dashboard is always mounted, toggled via CSS to avoid expensive re-mount */}
        <div className={isDashboard ? 'flex min-h-0 flex-1 flex-col' : 'hidden'}>
          <DashboardPage />
        </div>

        {!isDashboard && (
          <Routes>
            <Route path="/" element={<Navigate to="/dashboard" replace />} />
            <Route path="/agents" element={<AgentsPage />} />
            <Route path="/agents/:agentId" element={<AgentsPage />} />
            <Route path="/history" element={<HistoryPage />} />
            <Route path="/guide" element={<GuidePage />} />
          </Routes>
        )}
      </SidebarInset>
    </SidebarProvider>
  );
}

function AgentsPage() {
  const { agentId } = useParams();
  const navigate = useNavigate();
  const { data: agents, isLoading: agentsLoading } = useAgents();
  const { data: sessions } = useSessionHistory();
  const poolSummary = usePoolSummary(agents);

  useEffect(() => {
    if (agents && agents.length > 0 && !agentId) {
      navigate(`/agents/${agents[0].id}`, { replace: true });
    }
  }, [agents, agentId, navigate]);

  const selectedAgent = agents?.find((a) => a.id === agentId) ?? null;

  return (
    <div className="flex min-h-0 flex-1 flex-col">
      <PageHeader
        key="agents"
        title="Agents"
        description={`${poolSummary.total} agents \u00b7 ${poolSummary.active + poolSummary.busy} active \u00b7 ${poolSummary.idle} idle`}
      />

      <div className="flex min-h-0 flex-1">
        <div className="w-64 shrink-0 lg:w-72">
          {agentsLoading ? (
            <div className="flex flex-col gap-3 p-4">
              {[...Array(5)].map((_, i) => (
                <Skeleton key={i} className="h-14 w-full" />
              ))}
            </div>
          ) : agents ? (
            <AgentList
              agents={agents}
              selectedAgentId={agentId ?? null}
            />
          ) : null}
        </div>

        <div className="min-h-0 flex-1">
          {selectedAgent ? (
            <AgentDetail
              agent={selectedAgent}
              bastionHost={BASTION_HOST}
              recentSessions={sessions ?? []}
            />
          ) : (
            <div className="flex h-full items-center justify-center">
              <p className="text-sm text-muted-foreground">Select an agent from the list</p>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}

function HistoryPage() {
  const { data: sessions } = useSessionHistory();
  return <SessionHistoryPage sessions={sessions} />;
}

function GuidePage() {
  return <QuickStartPage bastionHost={BASTION_HOST} />;
}

export function App() {
  return (
    <QueryClientProvider client={queryClient}>
      <TooltipProvider>
        <BrowserRouter>
          <Layout />
        </BrowserRouter>
        <Toaster position="top-center" />
      </TooltipProvider>
    </QueryClientProvider>
  );
}

export default App;
