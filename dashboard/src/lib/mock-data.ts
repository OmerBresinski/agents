import type { Agent, SessionHistoryItem } from '@/types/agent';

export const MOCK_AGENTS: Agent[] = [
  {
    id: 'agent-1',
    status: 'idle',
    repo: null,
    session: {
      title: null,
      duration: null,
      messageCount: 0,
      tokens: { input: 0, output: 0, reasoning: 0 },
      cost: 0,
      models: [],
    },
    resources: { cpu: 1, memory: 128 },
    uptime: '2d 4h',
  },
  {
    id: 'agent-2',
    status: 'active',
    repo: 'myorg/backend-api',
    session: {
      id: 'agent-2-1774730473490',
      title: 'Fix authentication bug in the OAuth2 callback handler',
      duration: '45m',
      messageCount: 23,
      tokens: { input: 185000, output: 24000, reasoning: 6000 },
      cost: 0.87,
      models: [
        {
          id: 'us.anthropic.claude-sonnet-4-6',
          provider: 'amazon-bedrock',
          messages: 20,
        },
        {
          id: 'us.anthropic.claude-haiku-4-5',
          provider: 'amazon-bedrock',
          messages: 3,
        },
      ],
    },
    resources: { cpu: 23, memory: 512 },
    uptime: '2d 4h',
  },
  {
    id: 'agent-3',
    status: 'busy',
    repo: 'myorg/frontend',
    session: {
      id: 'agent-3-1774729812100',
      title: 'Add dark mode toggle with system preference detection and persistence',
      duration: '12m',
      messageCount: 8,
      tokens: { input: 62000, output: 9500, reasoning: 2100 },
      cost: 0.31,
      models: [
        {
          id: 'us.anthropic.claude-sonnet-4-6',
          provider: 'amazon-bedrock',
          messages: 8,
        },
      ],
    },
    resources: { cpu: 67, memory: 890 },
    uptime: '1d 18h',
  },
  {
    id: 'agent-4',
    status: 'idle',
    repo: null,
    session: {
      title: null,
      duration: null,
      messageCount: 0,
      tokens: { input: 0, output: 0, reasoning: 0 },
      cost: 0,
      models: [],
    },
    resources: { cpu: 2, memory: 130 },
    uptime: '3d 1h',
  },
  {
    id: 'agent-5',
    status: 'active',
    repo: 'myorg/ml-pipeline',
    session: {
      id: 'agent-5-1774728500000',
      title: 'Add unit tests for the data loader service and retry logic',
      duration: '1h 10m',
      messageCount: 41,
      tokens: { input: 420000, output: 58000, reasoning: 14000 },
      cost: 2.14,
      models: [
        {
          id: 'us.anthropic.claude-sonnet-4-6',
          provider: 'amazon-bedrock',
          messages: 35,
        },
        {
          id: 'us.anthropic.claude-haiku-4-5',
          provider: 'amazon-bedrock',
          messages: 6,
        },
      ],
    },
    resources: { cpu: 15, memory: 450 },
    uptime: '1d 6h',
  },
];

export const MOCK_SESSIONS: SessionHistoryItem[] = [
  {
    id: 'agent-2-1774725000000',
    agentId: 'agent-2',
    title: 'Refactor database connection pooling and query optimization layer',
    duration: '1h 23m',
    status: 'completed',
    completedAt: '2h ago',
    tokens: { input: 310000, output: 42000, reasoning: 9500 },
    cost: 1.52,
    models: [
      {
        id: 'us.anthropic.claude-sonnet-4-6',
        provider: 'amazon-bedrock',
        messages: 28,
      },
    ],
  },
  {
    id: 'agent-1-1774720000000',
    agentId: 'agent-1',
    title: 'Update README with new deployment instructions and architecture diagram',
    duration: '15m',
    status: 'completed',
    completedAt: '5h ago',
    tokens: { input: 18000, output: 3200, reasoning: 800 },
    cost: 0.09,
    models: [
      {
        id: 'us.anthropic.claude-sonnet-4-6',
        provider: 'amazon-bedrock',
        messages: 4,
      },
    ],
  },
  {
    id: 'agent-3-1774650000000',
    agentId: 'agent-3',
    title: 'Fix CI pipeline',
    duration: '45m',
    status: 'completed',
    completedAt: '1d ago',
    tokens: { input: 145000, output: 19000, reasoning: 4200 },
    cost: 0.71,
    models: [
      {
        id: 'us.anthropic.claude-sonnet-4-6',
        provider: 'amazon-bedrock',
        messages: 15,
      },
      {
        id: 'us.anthropic.claude-haiku-4-5',
        provider: 'amazon-bedrock',
        messages: 2,
      },
    ],
  },
  {
    id: 'agent-5-1774640000000',
    agentId: 'agent-5',
    title: 'Migrate to TypeScript strict mode',
    duration: '2h 10m',
    status: 'completed',
    completedAt: '1d ago',
    tokens: { input: 580000, output: 76000, reasoning: 18000 },
    cost: 2.89,
    models: [
      {
        id: 'us.anthropic.claude-sonnet-4-6',
        provider: 'amazon-bedrock',
        messages: 52,
      },
    ],
  },
  {
    id: 'agent-4-1774560000000',
    agentId: 'agent-4',
    title: 'Add OpenTelemetry tracing',
    duration: '55m',
    status: 'completed',
    completedAt: '2d ago',
    tokens: { input: 195000, output: 27000, reasoning: 6800 },
    cost: 0.97,
    models: [
      {
        id: 'us.anthropic.claude-sonnet-4-6',
        provider: 'amazon-bedrock',
        messages: 19,
      },
      {
        id: 'us.anthropic.claude-haiku-4-5',
        provider: 'amazon-bedrock',
        messages: 5,
      },
    ],
  },
];
