export interface TraceEvent {
  id: string;
  timestamp: string;
  command: string;
  status: 'started' | 'completed' | 'failed';
  pid: number;
  cwd: string;
  data?: any;
  duration?: string;
  received_at?: string;
}

export interface SystemInfo {
  timestamp: string;
  system: string;
  error?: string;
}

export interface ServerHealth {
  status: string;
  timestamp: string;
  connected_clients: number;
  total_traces: number;
}