#!/usr/bin/env bun

import { K8sStateMachine } from './state-machine';
import { K8sWatcher } from './k8s-watcher';
import { K8sEventEmitter } from './event-emitter';
import * as fs from 'fs/promises';
import * as path from 'path';

interface Config {
  watcher: {
    namespaces: string[];
    resourceTypes: string[];
    reconnectInterval: number;
  };
  emitter: {
    webhookUrls?: string[];
    websocketPort: number;
    slackChannel?: string;
    enableMetrics: boolean;
    filterCriteria: {
      criticality: 'low' | 'medium' | 'high';
      resourceTypes?: string[];
      namespaces?: string[];
    };
  };
  polars: {
    dataDir: string;
    retentionDays: number;
    analysisInterval: number;
  };
}

class K8sStateManager {
  private stateMachine: K8sStateMachine;
  private watcher: K8sWatcher;
  private eventEmitter: K8sEventEmitter;
  private config: Config;
  private dataDir: string;

  constructor(config: Config) {
    this.config = config;
    this.dataDir = config.polars.dataDir;
    
    this.stateMachine = new K8sStateMachine();
    
    this.watcher = new K8sWatcher(this.stateMachine, {
      namespaces: config.watcher.namespaces,
      resourceTypes: config.watcher.resourceTypes,
      reconnectInterval: config.watcher.reconnectInterval
    });

    this.eventEmitter = new K8sEventEmitter(this.stateMachine, config.emitter);

    this.setupEventHandlers();
    this.ensureDataDirectory();
  }

  private setupEventHandlers() {
    // Handle process signals
    process.on('SIGTERM', () => this.shutdown());
    process.on('SIGINT', () => this.shutdown());

    // Custom event handlers
    this.eventEmitter.on('event', (event) => {
      this.handleCustomEvent(event);
    });

    // Setup periodic tasks
    setInterval(() => {
      this.performPeriodicAnalysis();
    }, this.config.polars.analysisInterval * 1000);

    setInterval(() => {
      this.cleanupOldData();
    }, 24 * 60 * 60 * 1000); // Daily cleanup
  }

  private async ensureDataDirectory() {
    try {
      await fs.mkdir(this.dataDir, { recursive: true });
      console.log(`📁 Data directory ensured: ${this.dataDir}`);
    } catch (error) {
      console.error('Failed to create data directory:', error);
      process.exit(1);
    }
  }

  private handleCustomEvent(event: any) {
    // Log critical events
    if (event.severity === 'critical') {
      console.log(`🚨 CRITICAL EVENT: ${event.type} - ${event.resource?.kind}/${event.resource?.name}`);
    }

    // Store event data for analysis
    this.storeEventForAnalysis(event);
  }

  private async storeEventForAnalysis(event: any) {
    const timestamp = new Date().toISOString().split('T')[0];
    const filename = path.join(this.dataDir, `events-${timestamp}.jsonl`);
    
    try {
      const eventLine = JSON.stringify(event) + '\n';
      await fs.appendFile(filename, eventLine);
    } catch (error) {
      console.error('Failed to store event:', error);
    }
  }

  private async performPeriodicAnalysis() {
    console.log('📊 Performing periodic analysis...');
    
    try {
      const [store] = this.stateMachine.getStore();
      const health = this.stateMachine.getResourceHealth()();
      
      // Generate summary
      const summary = {
        timestamp: new Date().toISOString(),
        resources: {
          total: Object.keys(store.resources).length,
          byState: this.groupResourcesByState(store.resources),
          byKind: this.groupResourcesByKind(store.resources)
        },
        health,
        events: {
          total: store.events.length,
          recent: store.events.filter(e => 
            Date.now() - new Date(e.timestamp).getTime() < 60 * 60 * 1000
          ).length
        },
        connectivity: {
          status: store.connectionStatus,
          watchers: this.watcher.getStatus(),
          clients: this.eventEmitter.getConnectedClients()
        }
      };

      // Store analysis results
      const summaryFile = path.join(this.dataDir, `summary-${Date.now()}.json`);
      await fs.writeFile(summaryFile, JSON.stringify(summary, null, 2));
      
      console.log('✅ Analysis complete, results stored');
      
    } catch (error) {
      console.error('❌ Analysis failed:', error);
    }
  }

  private groupResourcesByState(resources: Record<string, any>) {
    return Object.values(resources).reduce((acc: any, machine: any) => {
      acc[machine.currentState] = (acc[machine.currentState] || 0) + 1;
      return acc;
    }, {});
  }

  private groupResourcesByKind(resources: Record<string, any>) {
    return Object.values(resources).reduce((acc: any, machine: any) => {
      acc[machine.resource.kind] = (acc[machine.resource.kind] || 0) + 1;
      return acc;
    }, {});
  }

  private async cleanupOldData() {
    console.log('🧹 Cleaning up old data...');
    
    try {
      const files = await fs.readdir(this.dataDir);
      const cutoffDate = new Date();
      cutoffDate.setDate(cutoffDate.getDate() - this.config.polars.retentionDays);
      
      for (const file of files) {
        const filePath = path.join(this.dataDir, file);
        const stats = await fs.stat(filePath);
        
        if (stats.mtime < cutoffDate) {
          await fs.unlink(filePath);
          console.log(`🗑️  Deleted old file: ${file}`);
        }
      }
      
      console.log('✅ Cleanup complete');
      
    } catch (error) {
      console.error('❌ Cleanup failed:', error);
    }
  }

  async start() {
    console.log('🚀 Starting K8s State Manager...');
    
    try {
      await this.watcher.start();
      console.log('✅ K8s State Manager started successfully');
      
      // Print status
      this.printStatus();
      
    } catch (error) {
      console.error('❌ Failed to start K8s State Manager:', error);
      process.exit(1);
    }
  }

  private printStatus() {
    const [store] = this.stateMachine.getStore();
    const health = this.stateMachine.getResourceHealth()();
    
    console.log('\n📊 Current Status:');
    console.log(`  Resources: ${Object.keys(store.resources).length}`);
    console.log(`  Health: ${health.healthy}✅ ${health.unhealthy}❌ ${health.unknown}❓`);
    console.log(`  Connection: ${store.connectionStatus}`);
    console.log(`  WebSocket clients: ${this.eventEmitter.getConnectedClients()}`);
    console.log(`  Data directory: ${this.dataDir}`);
    console.log('\n🌐 WebSocket endpoint: ws://localhost:' + this.config.emitter.websocketPort + '/k8s-events');
    console.log('📡 Ready to emit events...\n');
  }

  async shutdown() {
    console.log('\n🛑 Shutting down K8s State Manager...');
    
    try {
      await this.watcher.stop();
      await this.eventEmitter.shutdown();
      
      // Export final state
      const finalState = this.stateMachine.exportState();
      const exportFile = path.join(this.dataDir, `final-state-${Date.now()}.json`);
      await fs.writeFile(exportFile, JSON.stringify(finalState, null, 2));
      
      console.log('✅ Shutdown complete');
      process.exit(0);
      
    } catch (error) {
      console.error('❌ Shutdown failed:', error);
      process.exit(1);
    }
  }

  // API methods for external access
  getState() {
    return this.stateMachine.getStore()[0];
  }

  getHealth() {
    return this.stateMachine.getResourceHealth()();
  }

  getEventStats() {
    return this.eventEmitter.getEventStats();
  }

  updateWatcherConfig(config: any) {
    this.watcher.updateOptions(config);
  }

  updateEmitterConfig(config: any) {
    this.eventEmitter.updateConfig(config);
  }
}

// Default configuration
const defaultConfig: Config = {
  watcher: {
    namespaces: process.env.K8S_NAMESPACES?.split(',') || ['default'],
    resourceTypes: process.env.K8S_RESOURCE_TYPES?.split(',') || [
      'pods', 'services', 'deployments', 'configmaps', 'secrets'
    ],
    reconnectInterval: 5000
  },
  emitter: {
    webhookUrls: process.env.WEBHOOK_URLS?.split(','),
    websocketPort: parseInt(process.env.WS_PORT || '8080'),
    slackChannel: process.env.SLACK_CHANNEL,
    enableMetrics: process.env.ENABLE_METRICS !== 'false',
    filterCriteria: {
      criticality: (process.env.EVENT_CRITICALITY as any) || 'medium',
      resourceTypes: process.env.FILTER_RESOURCE_TYPES?.split(','),
      namespaces: process.env.FILTER_NAMESPACES?.split(',')
    }
  },
  polars: {
    dataDir: process.env.DATA_DIR || './data',
    retentionDays: parseInt(process.env.RETENTION_DAYS || '7'),
    analysisInterval: parseInt(process.env.ANALYSIS_INTERVAL || '300') // 5 minutes
  }
};

// Start the application
const manager = new K8sStateManager(defaultConfig);

if (import.meta.main) {
  manager.start();
}

export { K8sStateManager, Config };