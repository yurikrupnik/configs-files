import { createSignal, createEffect, createMemo } from 'solid-js';
import { createStore, produce } from 'solid-js/store';

export interface K8sResource {
  apiVersion: string;
  kind: string;
  metadata: {
    name: string;
    namespace?: string;
    uid: string;
    resourceVersion: string;
    creationTimestamp: string;
    labels?: Record<string, string>;
    annotations?: Record<string, string>;
  };
  status?: any;
  spec?: any;
}

export interface ResourceUpdate {
  type: 'ADDED' | 'MODIFIED' | 'DELETED';
  resource: K8sResource;
  timestamp: string;
}

export interface StateTransition {
  from: ResourceState;
  to: ResourceState;
  trigger: string;
  resource: K8sResource;
}

export type ResourceState = 
  | 'Pending'
  | 'Running' 
  | 'Succeeded'
  | 'Failed'
  | 'Unknown'
  | 'Terminating';

export interface ResourceStateMachine {
  resourceKey: string;
  currentState: ResourceState;
  previousState?: ResourceState;
  stateHistory: StateTransition[];
  lastUpdated: string;
  resource: K8sResource;
}

export interface K8sStateManagerState {
  resources: Record<string, ResourceStateMachine>;
  subscriptions: Set<string>;
  events: ResourceUpdate[];
  filters: {
    namespaces: string[];
    kinds: string[];
    labels: Record<string, string>;
  };
  connectionStatus: 'connected' | 'disconnected' | 'connecting';
}

export class K8sStateMachine {
  private [store, setStore] = createStore<K8sStateManagerState>({
    resources: {},
    subscriptions: new Set(),
    events: [],
    filters: {
      namespaces: [],
      kinds: [],
      labels: {}
    },
    connectionStatus: 'disconnected'
  });

  private eventListeners = new Map<string, Set<(event: ResourceUpdate) => void>>();

  constructor() {
    createEffect(() => {
      this.processEventQueue();
    });
  }

  getStore() {
    return [this.store, this.setStore] as const;
  }

  private generateResourceKey(resource: K8sResource): string {
    return `${resource.kind}/${resource.metadata.namespace || 'default'}/${resource.metadata.name}`;
  }

  private determineResourceState(resource: K8sResource): ResourceState {
    const { kind, status } = resource;
    
    switch (kind) {
      case 'Pod':
        return this.determinePodState(status);
      case 'Deployment':
        return this.determineDeploymentState(status);
      case 'Service':
        return status ? 'Running' : 'Pending';
      case 'ConfigMap':
      case 'Secret':
        return 'Running';
      default:
        return status ? 'Running' : 'Unknown';
    }
  }

  private determinePodState(status: any): ResourceState {
    if (!status) return 'Pending';
    
    switch (status.phase) {
      case 'Pending': return 'Pending';
      case 'Running': return 'Running';
      case 'Succeeded': return 'Succeeded';
      case 'Failed': return 'Failed';
      default: return 'Unknown';
    }
  }

  private determineDeploymentState(status: any): ResourceState {
    if (!status) return 'Pending';
    
    const { replicas = 0, readyReplicas = 0, updatedReplicas = 0 } = status;
    
    if (readyReplicas === replicas && updatedReplicas === replicas) {
      return 'Running';
    } else if (readyReplicas === 0) {
      return 'Pending';
    } else {
      return 'Running'; // Partial deployment
    }
  }

  processResourceUpdate(update: ResourceUpdate) {
    const resourceKey = this.generateResourceKey(update.resource);
    const currentState = this.determineResourceState(update.resource);
    
    this.setStore('events', events => [...events.slice(-99), update]); // Keep last 100 events
    
    if (update.type === 'DELETED') {
      this.setStore('resources', resourceKey, undefined!);
      this.emitEvent('stateChange', update);
      return;
    }

    this.setStore('resources', resourceKey, 
      produce((machine: ResourceStateMachine | undefined) => {
        if (!machine) {
          return {
            resourceKey,
            currentState,
            stateHistory: [],
            lastUpdated: update.timestamp,
            resource: update.resource
          };
        }

        const previousState = machine.currentState;
        if (previousState !== currentState) {
          machine.stateHistory.push({
            from: previousState,
            to: currentState,
            trigger: update.type,
            resource: update.resource
          });
        }

        machine.previousState = previousState;
        machine.currentState = currentState;
        machine.lastUpdated = update.timestamp;
        machine.resource = update.resource;
        
        return machine;
      })
    );

    this.emitEvent('stateChange', update);
  }

  subscribe(eventType: string, callback: (event: ResourceUpdate) => void) {
    if (!this.eventListeners.has(eventType)) {
      this.eventListeners.set(eventType, new Set());
    }
    
    this.eventListeners.get(eventType)!.add(callback);
    
    return () => {
      this.eventListeners.get(eventType)?.delete(callback);
    };
  }

  private emitEvent(eventType: string, event: ResourceUpdate) {
    const listeners = this.eventListeners.get(eventType);
    if (listeners) {
      listeners.forEach(callback => callback(event));
    }
  }

  setFilters(filters: Partial<K8sStateManagerState['filters']>) {
    this.setStore('filters', produce(current => ({ ...current, ...filters })));
  }

  getResourcesByState(state: ResourceState) {
    return createMemo(() => {
      return Object.values(this.store.resources)
        .filter(machine => machine.currentState === state);
    });
  }

  getResourcesByKind(kind: string) {
    return createMemo(() => {
      return Object.values(this.store.resources)
        .filter(machine => machine.resource.kind === kind);
    });
  }

  getResourcesByNamespace(namespace: string) {
    return createMemo(() => {
      return Object.values(this.store.resources)
        .filter(machine => 
          machine.resource.metadata.namespace === namespace
        );
    });
  }

  getResourceTransitions(resourceKey: string) {
    return createMemo(() => {
      const machine = this.store.resources[resourceKey];
      return machine?.stateHistory || [];
    });
  }

  getResourceHealth() {
    return createMemo(() => {
      const resources = Object.values(this.store.resources);
      const total = resources.length;
      
      if (total === 0) return { healthy: 0, unhealthy: 0, unknown: 0, total: 0 };
      
      const healthy = resources.filter(r => 
        ['Running', 'Succeeded'].includes(r.currentState)
      ).length;
      
      const unhealthy = resources.filter(r => 
        ['Failed', 'Terminating'].includes(r.currentState)
      ).length;
      
      const unknown = total - healthy - unhealthy;
      
      return { healthy, unhealthy, unknown, total };
    });
  }

  setConnectionStatus(status: K8sStateManagerState['connectionStatus']) {
    this.setStore('connectionStatus', status);
  }

  private processEventQueue() {
    // Process any queued events or batch updates
    const recentEvents = this.store.events.slice(-10);
    
    // Emit aggregated metrics for dashboard updates
    if (recentEvents.length > 0) {
      const summary = {
        totalEvents: this.store.events.length,
        recentUpdates: recentEvents.length,
        resourceCount: Object.keys(this.store.resources).length,
        health: this.getResourceHealth()()
      };
      
      this.emitEvent('metrics', { 
        type: 'METRICS' as any, 
        resource: summary as any, 
        timestamp: new Date().toISOString() 
      });
    }
  }

  clearHistory() {
    this.setStore('events', []);
    this.setStore('resources', produce(resources => {
      Object.values(resources).forEach(machine => {
        machine.stateHistory = [];
      });
      return resources;
    }));
  }

  exportState() {
    return {
      resources: this.store.resources,
      events: this.store.events,
      timestamp: new Date().toISOString(),
      health: this.getResourceHealth()()
    };
  }
}