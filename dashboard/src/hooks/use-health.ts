import { useQuery } from '@tanstack/react-query';

const API_BASE = import.meta.env.VITE_API_URL || '';
const USE_MOCK = import.meta.env.VITE_MOCK === 'true';

export interface BastionConfig {
  host: string;
  port: number;
  user: string;
}

export interface HealthData {
  status: string;
  timestamp: string;
  bucketEnabled: boolean;
  bastion?: BastionConfig;
}

const MOCK_HEALTH: HealthData = {
  status: 'ok',
  timestamp: new Date().toISOString(),
  bucketEnabled: false,
  bastion: {
    host: 'shinkansen.proxy.rlwy.net',
    port: 57775,
    user: 'opencode',
  },
};

async function fetchHealth(): Promise<HealthData> {
  if (USE_MOCK) return MOCK_HEALTH;
  const response = await fetch(`${API_BASE}/api/health`);
  if (!response.ok) {
    throw new Error('Failed to fetch health');
  }
  return response.json();
}

export function useHealth() {
  return useQuery({
    queryKey: ['health'],
    queryFn: fetchHealth,
    staleTime: 60000,
    refetchInterval: USE_MOCK ? false : 60000,
  });
}

/** Helper to get bastion config with fallback defaults */
export function useBastionConfig(): BastionConfig {
  const { data } = useHealth();
  return data?.bastion ?? {
    host: 'not-configured',
    port: 0,
    user: 'opencode',
  };
}
