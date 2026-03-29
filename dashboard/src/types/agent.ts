export type AgentStatus = 'idle' | 'active' | 'busy' | 'offline';

export interface SessionTokens {
  input: number;
  output: number;
  reasoning: number;
}

export interface SessionModel {
  id: string;
  provider: string;
  messages: number;
}

export interface AgentSession {
  id?: string;
  title: string | null;
  duration: string | null;
  messageCount: number;
  tokens?: SessionTokens;
  cost?: number;
  models?: SessionModel[];
}

export interface AgentResources {
  cpu: number;
  memory: number;
}

export interface Agent {
  id: string;
  status: AgentStatus;
  repo: string | null;
  session: AgentSession;
  resources: AgentResources;
  uptime: string;
}

export interface PoolSummary {
  idle: number;
  active: number;
  busy: number;
  offline: number;
  total: number;
  available: string[];
}

export interface SessionHistoryItem {
  id: string;
  agentId: string;
  title: string;
  duration: string;
  status: 'completed' | 'aborted' | 'active';
  completedAt: string;
  tokens?: SessionTokens;
  cost?: number;
  models?: SessionModel[];
}

export interface DashboardConfig {
  bastionHost: string;
  refreshInterval: number;
}
