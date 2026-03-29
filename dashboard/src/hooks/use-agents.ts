import { useQuery } from '@tanstack/react-query';
import type { Agent, PoolSummary, SessionHistoryItem } from '@/types/agent';
import { MOCK_AGENTS, MOCK_SESSIONS } from '@/lib/mock-data';

const API_BASE = import.meta.env.VITE_API_URL || '';
const USE_MOCK = import.meta.env.VITE_MOCK === 'true';

async function fetchAgents(): Promise<Agent[]> {
  if (USE_MOCK) return MOCK_AGENTS;
  const response = await fetch(`${API_BASE}/api/agents`);
  if (!response.ok) {
    throw new Error('Failed to fetch agents');
  }
  return response.json();
}

async function fetchSessionHistory(): Promise<SessionHistoryItem[]> {
  if (USE_MOCK) return MOCK_SESSIONS;
  const response = await fetch(`${API_BASE}/api/sessions`);
  if (!response.ok) {
    throw new Error('Failed to fetch session history');
  }
  return response.json();
}

export function useAgents(refetchInterval = 5000) {
  return useQuery({
    queryKey: ['agents'],
    queryFn: fetchAgents,
    refetchInterval: USE_MOCK ? false : refetchInterval,
    staleTime: 5000,
  });
}

export function usePoolSummary(agents: Agent[] | undefined): PoolSummary {
  if (!agents) {
    return {
      idle: 0,
      active: 0,
      busy: 0,
      offline: 0,
      total: 0,
      available: [],
    };
  }

  const summary: PoolSummary = {
    idle: 0,
    active: 0,
    busy: 0,
    offline: 0,
    total: agents.length,
    available: [],
  };

  for (const agent of agents) {
    switch (agent.status) {
      case 'idle':
        summary.idle++;
        summary.available.push(agent.id);
        break;
      case 'active':
        summary.active++;
        break;
      case 'busy':
        summary.busy++;
        break;
      case 'offline':
        summary.offline++;
        break;
    }
  }

  return summary;
}

export function useSessionHistory(refetchInterval = 5000) {
  return useQuery({
    queryKey: ['sessions'],
    queryFn: fetchSessionHistory,
    refetchInterval: USE_MOCK ? false : refetchInterval,
    staleTime: 3000,
  });
}
