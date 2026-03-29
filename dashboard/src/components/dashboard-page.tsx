import { lazy, Suspense } from 'react';
import { AnimateNumber } from 'motion-number';
import { Skeleton } from '@/components/ui/skeleton';
import { PageHeader } from '@/components/page-header';
import { useAgents, useSessionHistory } from '@/hooks/use-agents';
import { useDashboardStats } from '@/hooks/use-dashboard-stats';

// Lazy load chart components (recharts stays out of main bundle)
const LazyInternalCostChart = lazy(() =>
  import('@/components/dashboard-charts').then(m => ({ default: m.CostChart }))
);
const LazyInternalTokenChart = lazy(() =>
  import('@/components/dashboard-charts').then(m => ({ default: m.TokenChart }))
);
const LazyInternalModelChart = lazy(() =>
  import('@/components/dashboard-charts').then(m => ({ default: m.ModelChart }))
);
const LazyInternalStatusChart = lazy(() =>
  import('@/components/dashboard-charts').then(m => ({ default: m.StatusChart }))
);

function ChartSkeleton() {
  return <Skeleton className="h-full w-full rounded-sm" />;
}

const springTransition = {
  duration: 0.8,
  type: 'spring' as const,
  bounce: 0.15,
};

export default function DashboardPage() {
  const { data: agents } = useAgents();
  const { data: sessions } = useSessionHistory();
  const stats = useDashboardStats(agents, sessions);

  return (
    <div className="flex min-h-0 flex-1 flex-col bg-card">
      <PageHeader
        key="dashboard"
        title="Dashboard"
        description="Overview of your agent pool"
      />

      {/* Info cards */}
      <div className="grid grid-cols-4 border-b border-border">
        {[
          { label: 'Total Spend', value: stats.totalSpend, isCurrency: true },
          { label: 'Total Tokens', value: stats.totalTokens, isTokens: true },
          { label: 'Active Sessions', value: stats.activeSessions },
          { label: 'Total Sessions', value: stats.totalSessions },
        ].map((card, i) => (
          <div
            key={card.label}
            className={`flex flex-col justify-center gap-1 px-6 py-4 ${i > 0 ? 'border-l border-border' : ''}`}
          >
            <span className="text-[11px] text-muted-foreground">{card.label}</span>
            <div className="font-heading text-[28px] font-normal leading-tight">
              {card.isCurrency ? (
                <AnimateNumber
                  prefix="$"
                  format={{ minimumFractionDigits: 2, maximumFractionDigits: 2 }}
                  transition={springTransition}
                >
                  {card.value}
                </AnimateNumber>
              ) : card.isTokens ? (
                <AnimateNumber
                  suffix={card.value >= 1000000 ? 'M' : card.value >= 1000 ? 'K' : ''}
                  format={card.value >= 1000000
                    ? { minimumFractionDigits: 1, maximumFractionDigits: 1 }
                    : card.value >= 1000
                      ? { minimumFractionDigits: card.value < 10000 ? 1 : 0, maximumFractionDigits: card.value < 10000 ? 1 : 0 }
                      : undefined
                  }
                  transition={springTransition}
                >
                  {card.value >= 1000000
                    ? card.value / 1000000
                    : card.value >= 1000
                      ? card.value / 1000
                      : card.value
                  }
                </AnimateNumber>
              ) : (
                <AnimateNumber transition={springTransition}>
                  {card.value}
                </AnimateNumber>
              )}
            </div>
          </div>
        ))}
      </div>

      {/* Charts — lazy loaded */}
      <div className="flex min-h-0 flex-1 flex-col">
        <div className="grid min-h-0 flex-1 grid-cols-2 border-b border-border">
          <div className="flex min-h-0 flex-col px-6 py-4">
            <span className="shrink-0 text-[0.6875rem] font-medium uppercase tracking-widest text-muted-foreground">
              Cost Per Agent
            </span>
            <div className="mt-2 min-h-0 flex-1">
              <Suspense fallback={<ChartSkeleton />}>
                <LazyInternalCostChart data={stats.costPerAgent} />
              </Suspense>
            </div>
          </div>
          <div className="flex min-h-0 flex-col border-l border-border px-6 py-4">
            <span className="shrink-0 text-[0.6875rem] font-medium uppercase tracking-widest text-muted-foreground">
              Token Usage by Type
            </span>
            <div className="mt-2 min-h-0 flex-1">
              <Suspense fallback={<ChartSkeleton />}>
                <LazyInternalTokenChart data={stats.tokensPerAgent} />
              </Suspense>
            </div>
          </div>
        </div>

        <div className="grid min-h-0 flex-1 grid-cols-2">
          <div className="flex min-h-0 flex-col px-6 py-4">
            <span className="shrink-0 text-[0.6875rem] font-medium uppercase tracking-widest text-muted-foreground">
              Model Usage
            </span>
            <div className="mt-2 min-h-0 flex-1">
              <Suspense fallback={<ChartSkeleton />}>
                <LazyInternalModelChart data={stats.modelUsage} />
              </Suspense>
            </div>
          </div>
          <div className="flex min-h-0 flex-col border-l border-border px-6 py-4">
            <span className="shrink-0 text-[0.6875rem] font-medium uppercase tracking-widest text-muted-foreground">
              Agent Status
            </span>
            <div className="mt-2 min-h-0 flex-1">
              <Suspense fallback={<ChartSkeleton />}>
                <LazyInternalStatusChart data={stats.statusBreakdown} total={agents?.length ?? 0} />
              </Suspense>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
