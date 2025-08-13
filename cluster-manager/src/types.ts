export interface Cluster {
  id: string;
  name: string;
  environment: 'local' | 'staging' | 'production';
  type: 'local' | 'aks' | 'eks' | 'gke';
  status: 'running' | 'stopped' | 'error';
  uptime: number; // in hours
  nodeCount: number;
  cost: {
    current: number;
    budget: number;
    currency: string;
  };
  region?: string;
  zone?: string;
}

export interface Application {
  name: string;
  namespace: string;
  status: 'running' | 'stopped' | 'error';
  version: string;
  enabled: boolean;
}

export interface CostMetrics {
  daily: number;
  weekly: number;
  monthly: number;
  projected: number;
}

export interface UptimeMetrics {
  uptime: number;
  lastDowntime?: Date;
  availability: number; // percentage
}