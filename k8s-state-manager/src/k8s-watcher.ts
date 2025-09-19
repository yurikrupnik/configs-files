import * as k8s from '@kubernetes/client-node';
import { K8sStateMachine, ResourceUpdate, K8sResource } from './state-machine';
import pl from 'polars';

export interface WatcherOptions {
  namespaces?: string[];
  resourceTypes?: string[];
  labelSelectors?: Record<string, string>;
  reconnectInterval?: number;
}

export class K8sWatcher {
  private kc: k8s.KubeConfig;
  private watchers: Map<string, k8s.Watch> = new Map();
  private stateMachine: K8sStateMachine;
  private options: WatcherOptions;
  private reconnectTimers: Map<string, NodeJS.Timeout> = new Map();

  constructor(stateMachine: K8sStateMachine, options: WatcherOptions = {}) {
    this.kc = new k8s.KubeConfig();
    this.kc.loadFromDefault();
    this.stateMachine = stateMachine;
    this.options = {
      namespaces: ['default'],
      resourceTypes: ['pods', 'services', 'deployments', 'configmaps', 'secrets'],
      reconnectInterval: 5000,
      ...options
    };
  }

  async start() {
    console.log('🚀 Starting K8s watchers...');
    this.stateMachine.setConnectionStatus('connecting');

    try {
      await this.startResourceWatchers();
      this.stateMachine.setConnectionStatus('connected');
      console.log('✅ K8s watchers connected');
    } catch (error) {
      console.error('❌ Failed to start watchers:', error);
      this.stateMachine.setConnectionStatus('disconnected');
      this.scheduleReconnect();
    }
  }

  private async startResourceWatchers() {
    const { resourceTypes, namespaces } = this.options;
    
    for (const resourceType of resourceTypes!) {
      for (const namespace of namespaces!) {
        await this.watchResource(resourceType, namespace);
      }
    }
  }

  private async watchResource(resourceType: string, namespace: string) {
    const watch = new k8s.Watch(this.kc);
    const watchKey = `${resourceType}-${namespace}`;
    
    try {
      const path = this.getResourcePath(resourceType, namespace);
      
      const request = await watch.watch(
        path,
        {},
        (type, apiObj, watchObj) => {
          this.handleResourceEvent(type as any, apiObj as K8sResource, resourceType);
        },
        (err) => {
          console.error(`❌ Watch error for ${watchKey}:`, err);
          this.handleWatchError(watchKey, resourceType, namespace);
        }
      );

      this.watchers.set(watchKey, watch);
      console.log(`👀 Watching ${resourceType} in namespace ${namespace}`);
      
    } catch (error) {
      console.error(`❌ Failed to start watching ${watchKey}:`, error);
      this.scheduleResourceReconnect(watchKey, resourceType, namespace);
    }
  }

  private getResourcePath(resourceType: string, namespace: string): string {
    const basePaths: Record<string, string> = {
      'pods': `/api/v1/namespaces/${namespace}/pods`,
      'services': `/api/v1/namespaces/${namespace}/services`,
      'deployments': `/apis/apps/v1/namespaces/${namespace}/deployments`,
      'configmaps': `/api/v1/namespaces/${namespace}/configmaps`,
      'secrets': `/api/v1/namespaces/${namespace}/secrets`,
      'ingresses': `/apis/networking.k8s.io/v1/namespaces/${namespace}/ingresses`
    };
    
    return basePaths[resourceType] || `/api/v1/namespaces/${namespace}/${resourceType}`;
  }

  private handleResourceEvent(
    type: 'ADDED' | 'MODIFIED' | 'DELETED',
    resource: K8sResource,
    resourceType: string
  ) {
    const update: ResourceUpdate = {
      type,
      resource,
      timestamp: new Date().toISOString()
    };

    this.stateMachine.processResourceUpdate(update);
    this.processDataWithPolars(update, resourceType);
  }

  private async processDataWithPolars(update: ResourceUpdate, resourceType: string) {
    try {
      // Convert resource update to DataFrame for analysis
      const data = [{
        timestamp: update.timestamp,
        type: update.type,
        kind: update.resource.kind,
        name: update.resource.metadata.name,
        namespace: update.resource.metadata.namespace || 'default',
        labels: JSON.stringify(update.resource.metadata.labels || {}),
        resource_version: update.resource.metadata.resourceVersion
      }];

      const df = pl.DataFrame(data);
      
      // Store recent events for trend analysis
      await this.storeEventData(df, resourceType);
      
      // Trigger analysis if we have enough data points
      const eventCount = await this.getEventCount(resourceType);
      if (eventCount > 0 && eventCount % 10 === 0) {
        await this.triggerTrendAnalysis(resourceType);
      }
      
    } catch (error) {
      console.error('Error processing data with Polars:', error);
    }
  }

  private async storeEventData(df: pl.DataFrame, resourceType: string) {
    const filename = `./data/events-${resourceType}-${Date.now()}.parquet`;
    await df.write_parquet(filename);
  }

  private async getEventCount(resourceType: string): Promise<number> {
    // This would typically query a time-series database or file system
    // For now, return a mock count
    return Math.floor(Math.random() * 100);
  }

  private async triggerTrendAnalysis(resourceType: string) {
    console.log(`📊 Triggering trend analysis for ${resourceType}`);
    
    // This would typically:
    // 1. Load recent parquet files
    // 2. Perform time-series analysis with Polars
    // 3. Emit insights back to the state machine
    
    const insights = {
      resourceType,
      trendDirection: 'stable', // 'increasing' | 'decreasing' | 'stable'
      eventRate: 0.5, // events per minute
      anomaliesDetected: false,
      timestamp: new Date().toISOString()
    };

    // Emit insights as a special event
    this.stateMachine.processResourceUpdate({
      type: 'MODIFIED',
      resource: {
        apiVersion: 'insights/v1',
        kind: 'TrendAnalysis',
        metadata: {
          name: `${resourceType}-trends`,
          namespace: 'system',
          uid: `trend-${Date.now()}`,
          resourceVersion: '1',
          creationTimestamp: new Date().toISOString()
        },
        spec: insights
      },
      timestamp: new Date().toISOString()
    });
  }

  private handleWatchError(watchKey: string, resourceType: string, namespace: string) {
    console.log(`🔄 Reconnecting watcher for ${watchKey}`);
    this.scheduleResourceReconnect(watchKey, resourceType, namespace);
  }

  private scheduleResourceReconnect(watchKey: string, resourceType: string, namespace: string) {
    if (this.reconnectTimers.has(watchKey)) {
      clearTimeout(this.reconnectTimers.get(watchKey)!);
    }

    const timer = setTimeout(async () => {
      try {
        await this.watchResource(resourceType, namespace);
      } catch (error) {
        console.error(`❌ Reconnect failed for ${watchKey}:`, error);
        this.scheduleResourceReconnect(watchKey, resourceType, namespace);
      }
    }, this.options.reconnectInterval);

    this.reconnectTimers.set(watchKey, timer);
  }

  private scheduleReconnect() {
    setTimeout(() => {
      this.start();
    }, this.options.reconnectInterval);
  }

  async stop() {
    console.log('🛑 Stopping K8s watchers...');
    
    for (const [key, watcher] of this.watchers) {
      try {
        watcher.abort();
      } catch (error) {
        console.error(`Error stopping watcher ${key}:`, error);
      }
    }

    for (const timer of this.reconnectTimers.values()) {
      clearTimeout(timer);
    }

    this.watchers.clear();
    this.reconnectTimers.clear();
    this.stateMachine.setConnectionStatus('disconnected');
    
    console.log('✅ All watchers stopped');
  }

  updateOptions(newOptions: Partial<WatcherOptions>) {
    this.options = { ...this.options, ...newOptions };
    this.stateMachine.setFilters({
      namespaces: this.options.namespaces || [],
      kinds: this.options.resourceTypes || [],
      labels: this.options.labelSelectors || {}
    });
  }

  getStatus() {
    return {
      connected: this.watchers.size,
      totalWatchers: (this.options.namespaces?.length || 1) * (this.options.resourceTypes?.length || 1),
      options: this.options,
      connectionStatus: this.stateMachine.getStore()[0].connectionStatus
    };
  }
}