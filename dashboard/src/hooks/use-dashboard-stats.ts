import { useMemo } from 'react';
import type { Agent, SessionHistoryItem } from '@/types/agent';
import { titleCase } from '@/lib/title-case';

export interface CostPerAgent {
  agent: string;
  cost: number;
}

export interface TokensPerAgent {
  agent: string;
  input: number;
  output: number;
  reasoning: number;
}

export interface ModelUsage {
  model: string;
  messages: number;
}

export interface StatusBreakdown {
  status: string;
  count: number;
  fill: string;
}

export interface DashboardStats {
  totalSpend: number;
  activeSessions: number;
  totalTokens: number;
  totalSessions: number;
  costPerAgent: CostPerAgent[];
  tokensPerAgent: TokensPerAgent[];
  modelUsage: ModelUsage[];
  statusBreakdown: StatusBreakdown[];
}

const STATUS_FILLS: Record<string, string> = {
  idle: 'var(--color-chart-1)',
  active: 'var(--color-chart-3)',
  busy: 'var(--color-chart-2)',
  offline: 'var(--color-chart-5)',
};

/** Shorten model IDs for display across multiple providers */
function formatModelName(id: string): string {
  // Strip known provider prefixes
  let name = id
    .replace(/^us\.anthropic\./, '')
    .replace(/^anthropic\./, '')
    .replace(/^moonshotai\./, '')
    .replace(/^google\./, '')
    .replace(/^mistral\./, '')
    .replace(/^meta\./, '')
    .replace(/^amazon\./, '')
    .replace(/^cohere\./, '');

  // Strip common suffixes
  name = name
    .replace(/-free$/, '')
    .replace(/-latest$/, '')
    .replace(/-v\d+:\d+$/, '')
    .replace(/-\d{8}$/, '');

  // Claude models: "claude-sonnet-4-6" → "Claude Sonnet 4"
  const claudeMatch = name.match(/^claude-(\w+)-(\d+)(?:-\d+)?$/);
  if (claudeMatch) return `Claude ${titleCase(claudeMatch[1])} ${claudeMatch[2]}`;

  // Generic: split on hyphens/dots, title-case, drop trailing version numbers that look like "k2.5"
  return name
    .split(/[-.]/)
    .filter(Boolean)
    .map((s) => titleCase(s))
    .join(' ');
}

/**
 * Single-pass aggregation of agent + session data into chart-ready format.
 * Per js-combine-iterations: one loop per data source, collecting all stats at once.
 */
export function useDashboardStats(
  agents: Agent[] | undefined,
  sessions: SessionHistoryItem[] | undefined,
): DashboardStats {
  return useMemo(() => {
    if (!agents) {
      return {
        totalSpend: 0,
        activeSessions: 0,
        totalTokens: 0,
        totalSessions: 0,
        costPerAgent: [],
        tokensPerAgent: [],
        modelUsage: [],
        statusBreakdown: [],
      };
    }

    // Accumulators
    const costMap = new Map<string, number>();
    const tokenMap = new Map<string, { input: number; output: number; reasoning: number }>();
    const modelMap = new Map<string, number>();
    const statusMap = new Map<string, number>();
    let totalSpend = 0;
    let totalTokens = 0;
    let activeSessions = 0;
    let totalSessions = 0;

    // Single pass through agents
    for (const agent of agents) {
      const name = titleCase(agent.id);

      // Status
      statusMap.set(agent.status, (statusMap.get(agent.status) ?? 0) + 1);

      // Init cost/token maps
      if (!costMap.has(name)) costMap.set(name, 0);
      if (!tokenMap.has(name)) tokenMap.set(name, { input: 0, output: 0, reasoning: 0 });

      // Active session data
      if (agent.session.title) {
        activeSessions++;
        totalSessions++;

        const cost = agent.session.cost ?? 0;
        costMap.set(name, costMap.get(name)! + cost);
        totalSpend += cost;

        if (agent.session.tokens) {
          const t = agent.session.tokens;
          const existing = tokenMap.get(name)!;
          existing.input += t.input;
          existing.output += t.output;
          existing.reasoning += t.reasoning;
          totalTokens += t.input + t.output + t.reasoning;
        }

        if (agent.session.models) {
          for (const m of agent.session.models) {
            const modelName = formatModelName(m.id);
            modelMap.set(modelName, (modelMap.get(modelName) ?? 0) + m.messages);
          }
        }
      }
    }

    // Single pass through sessions
    if (sessions) {
      for (const session of sessions) {
        totalSessions++;
        const name = titleCase(session.agentId);

        const cost = session.cost ?? 0;
        costMap.set(name, (costMap.get(name) ?? 0) + cost);
        totalSpend += cost;

        if (session.tokens) {
          const t = session.tokens;
          const existing = tokenMap.get(name) ?? { input: 0, output: 0, reasoning: 0 };
          existing.input += t.input;
          existing.output += t.output;
          existing.reasoning += t.reasoning;
          tokenMap.set(name, existing);
          totalTokens += t.input + t.output + t.reasoning;
        }

        if (session.models) {
          for (const m of session.models) {
            const modelName = formatModelName(m.id);
            modelMap.set(modelName, (modelMap.get(modelName) ?? 0) + m.messages);
          }
        }
      }
    }

    // Convert maps to arrays
    const costPerAgent: CostPerAgent[] = Array.from(costMap, ([agent, cost]) => ({ agent, cost }));
    const tokensPerAgent: TokensPerAgent[] = Array.from(tokenMap, ([agent, t]) => ({
      agent,
      ...t,
    }));
    const modelUsage: ModelUsage[] = Array.from(modelMap, ([model, messages]) => ({
      model,
      messages,
    })).sort((a, b) => b.messages - a.messages);
    const statusBreakdown: StatusBreakdown[] = Array.from(statusMap, ([status, count]) => ({
      status: titleCase(status),
      count,
      fill: STATUS_FILLS[status] ?? 'var(--color-muted)',
    }));

    return {
      totalSpend,
      activeSessions,
      totalTokens,
      totalSessions,
      costPerAgent,
      tokensPerAgent,
      modelUsage,
      statusBreakdown,
    };
  }, [agents, sessions]);
}
