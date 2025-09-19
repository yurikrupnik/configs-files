import { K8sStateMachine, ResourceUpdate, ResourceState } from './state-machine';
import WebSocket from 'ws';
import { EventEmitter } from 'events';

export interface EventEmissionConfig {
  webhookUrls?: string[];
  websocketPort?: number;
  slackChannel?: string;
  enableMetrics?: boolean;
  filterCriteria?: {
    criticality?: 'low' | 'medium' | 'high';
    resourceTypes?: string[];
    namespaces?: string[];
    stateChanges?: ResourceState[];
  };
}

export interface EmittedEvent {
  id: string;
  timestamp: string;
  type: 'resource_update' | 'state_change' | 'alert' | 'metrics';
  severity: 'info' | 'warning' | 'error' | 'critical';
  resource?: {
    kind: string;
    name: string;
    namespace: string;
  };
  payload: any;
  metadata: {
    cluster?: string;
    source: string;
    correlationId?: string;
  };
}

export class K8sEventEmitter extends EventEmitter {
  private stateMachine: K8sStateMachine;
  private config: EventEmissionConfig;
  private wsServer?: WebSocket.Server;
  private connectedClients: Set<WebSocket> = new Set();
  private eventBuffer: EmittedEvent[] = [];
  private bufferSize = 1000;

  constructor(stateMachine: K8sStateMachine, config: EventEmissionConfig = {}) {
    super();
    this.stateMachine = stateMachine;
    this.config = {
      websocketPort: 8080,
      enableMetrics: true,
      filterCriteria: {
        criticality: 'medium'
      },
      ...config
    };

    this.setupSubscriptions();
    this.initializeWebSocketServer();
  }

  private setupSubscriptions() {
    // Subscribe to state machine events
    this.stateMachine.subscribe('stateChange', (update) => {
      this.handleResourceUpdate(update);
    });

    this.stateMachine.subscribe('metrics', (metricsUpdate) => {
      this.handleMetricsUpdate(metricsUpdate);
    });
  }

  private initializeWebSocketServer() {
    if (!this.config.websocketPort) return;

    this.wsServer = new WebSocket.Server({ 
      port: this.config.websocketPort,
      path: '/k8s-events'
    });

    this.wsServer.on('connection', (ws) => {
      console.log('📡 New WebSocket client connected');
      this.connectedClients.add(ws);

      // Send recent events to new client
      const recentEvents = this.eventBuffer.slice(-50);
      ws.send(JSON.stringify({
        type: 'initial_state',
        events: recentEvents,
        timestamp: new Date().toISOString()
      }));

      ws.on('close', () => {
        this.connectedClients.delete(ws);
        console.log('📡 WebSocket client disconnected');
      });

      ws.on('error', (error) => {
        console.error('WebSocket error:', error);
        this.connectedClients.delete(ws);
      });
    });

    console.log(`🌐 WebSocket server started on port ${this.config.websocketPort}`);
  }

  private handleResourceUpdate(update: ResourceUpdate) {
    const event = this.createEvent(update);
    
    if (this.shouldEmitEvent(event)) {
      this.emitEvent(event);
    }
  }

  private handleMetricsUpdate(metricsUpdate: ResourceUpdate) {
    const event: EmittedEvent = {
      id: this.generateEventId(),
      timestamp: new Date().toISOString(),
      type: 'metrics',
      severity: 'info',
      payload: metricsUpdate.resource,
      metadata: {
        source: 'k8s-state-machine',
        cluster: process.env.CLUSTER_NAME || 'local'
      }
    };

    this.emitEvent(event);
  }

  private createEvent(update: ResourceUpdate): EmittedEvent {
    const severity = this.determineSeverity(update);
    const resourceKey = `${update.resource.kind}/${update.resource.metadata.namespace || 'default'}/${update.resource.metadata.name}`;
    const [store] = this.stateMachine.getStore();
    const machine = store.resources[resourceKey];

    return {
      id: this.generateEventId(),
      timestamp: update.timestamp,
      type: update.type === 'DELETED' ? 'resource_update' : 
            (machine?.previousState !== machine?.currentState) ? 'state_change' : 'resource_update',
      severity,
      resource: {
        kind: update.resource.kind,
        name: update.resource.metadata.name,
        namespace: update.resource.metadata.namespace || 'default'
      },
      payload: {
        updateType: update.type,
        previousState: machine?.previousState,
        currentState: machine?.currentState,
        resource: update.resource,
        stateHistory: machine?.stateHistory.slice(-5) || []
      },
      metadata: {
        source: 'k8s-watcher',
        cluster: process.env.CLUSTER_NAME || 'local',
        correlationId: update.resource.metadata.uid
      }
    };
  }

  private determineSeverity(update: ResourceUpdate): EmittedEvent['severity'] {
    const { resource, type } = update;
    const resourceKey = `${resource.kind}/${resource.metadata.namespace || 'default'}/${resource.metadata.name}`;
    const [store] = this.stateMachine.getStore();
    const machine = store.resources[resourceKey];

    // Critical events
    if (type === 'DELETED' || machine?.currentState === 'Failed') {
      return 'critical';
    }

    // Error events
    if (machine?.currentState === 'Terminating' || 
        (machine?.previousState === 'Running' && machine?.currentState === 'Pending')) {
      return 'error';
    }

    // Warning events
    if (machine?.currentState === 'Pending' || machine?.currentState === 'Unknown') {
      return 'warning';
    }

    return 'info';
  }

  private shouldEmitEvent(event: EmittedEvent): boolean {
    const { filterCriteria } = this.config;
    
    if (!filterCriteria) return true;

    // Filter by criticality
    if (filterCriteria.criticality) {
      const severityLevels = ['info', 'warning', 'error', 'critical'];
      const minLevel = severityLevels.indexOf(filterCriteria.criticality);
      const eventLevel = severityLevels.indexOf(event.severity);
      
      if (eventLevel < minLevel) return false;
    }

    // Filter by resource types
    if (filterCriteria.resourceTypes && event.resource) {
      if (!filterCriteria.resourceTypes.includes(event.resource.kind)) {
        return false;
      }
    }

    // Filter by namespaces
    if (filterCriteria.namespaces && event.resource) {
      if (!filterCriteria.namespaces.includes(event.resource.namespace)) {
        return false;
      }
    }

    // Filter by state changes
    if (filterCriteria.stateChanges && event.type === 'state_change') {
      const currentState = event.payload.currentState;
      if (!filterCriteria.stateChanges.includes(currentState)) {
        return false;
      }
    }

    return true;
  }

  private emitEvent(event: EmittedEvent) {
    // Add to buffer
    this.eventBuffer.push(event);
    if (this.eventBuffer.length > this.bufferSize) {
      this.eventBuffer.shift();
    }

    // Emit to internal listeners
    this.emit('event', event);

    // Send to WebSocket clients
    this.broadcastToWebSockets(event);

    // Send to webhooks
    this.sendToWebhooks(event);

    // Send to Slack if configured
    this.sendToSlack(event);

    console.log(`📤 Event emitted: ${event.type} | ${event.severity} | ${event.resource?.kind}/${event.resource?.name}`);
  }

  private broadcastToWebSockets(event: EmittedEvent) {
    const message = JSON.stringify({
      type: 'event',
      data: event
    });

    this.connectedClients.forEach((client) => {
      if (client.readyState === WebSocket.OPEN) {
        try {
          client.send(message);
        } catch (error) {
          console.error('Error sending to WebSocket client:', error);
          this.connectedClients.delete(client);
        }
      }
    });
  }

  private async sendToWebhooks(event: EmittedEvent) {
    if (!this.config.webhookUrls) return;

    const promises = this.config.webhookUrls.map(async (url) => {
      try {
        const response = await fetch(url, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'User-Agent': 'k8s-state-manager/1.0'
          },
          body: JSON.stringify(event)
        });

        if (!response.ok) {
          throw new Error(`HTTP ${response.status}: ${response.statusText}`);
        }

        console.log(`✅ Webhook sent to ${url}`);
      } catch (error) {
        console.error(`❌ Webhook failed for ${url}:`, error);
      }
    });

    await Promise.allSettled(promises);
  }

  private async sendToSlack(event: EmittedEvent) {
    if (!this.config.slackChannel || event.severity === 'info') return;

    const slackWebhookUrl = process.env.SLACK_WEBHOOK_URL;
    if (!slackWebhookUrl) return;

    const color = {
      'warning': 'warning',
      'error': 'danger',
      'critical': 'danger'
    }[event.severity] || 'good';

    const slackPayload = {
      channel: this.config.slackChannel,
      username: 'K8s State Manager',
      icon_emoji: ':kubernetes:',
      attachments: [{
        color,
        title: `${event.type.replace('_', ' ').toUpperCase()}: ${event.resource?.kind}/${event.resource?.name}`,
        fields: [
          {
            title: 'Namespace',
            value: event.resource?.namespace,
            short: true
          },
          {
            title: 'Severity',
            value: event.severity.toUpperCase(),
            short: true
          },
          {
            title: 'State Transition',
            value: event.payload.previousState ? 
              `${event.payload.previousState} → ${event.payload.currentState}` : 
              event.payload.currentState,
            short: false
          }
        ],
        timestamp: Math.floor(new Date(event.timestamp).getTime() / 1000)
      }]
    };

    try {
      const response = await fetch(slackWebhookUrl, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(slackPayload)
      });

      if (response.ok) {
        console.log('✅ Slack notification sent');
      }
    } catch (error) {
      console.error('❌ Slack notification failed:', error);
    }
  }

  private generateEventId(): string {
    return `evt_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
  }

  // Public methods
  updateConfig(newConfig: Partial<EventEmissionConfig>) {
    this.config = { ...this.config, ...newConfig };
  }

  getConnectedClients(): number {
    return this.connectedClients.size;
  }

  getEventHistory(limit: number = 100): EmittedEvent[] {
    return this.eventBuffer.slice(-limit);
  }

  getEventStats() {
    const events = this.eventBuffer;
    const now = Date.now();
    const oneHourAgo = now - (60 * 60 * 1000);
    
    const recentEvents = events.filter(e => 
      new Date(e.timestamp).getTime() > oneHourAgo
    );

    const severityCounts = recentEvents.reduce((acc, event) => {
      acc[event.severity] = (acc[event.severity] || 0) + 1;
      return acc;
    }, {} as Record<string, number>);

    return {
      total: events.length,
      recentHour: recentEvents.length,
      severityCounts,
      connectedClients: this.connectedClients.size
    };
  }

  async shutdown() {
    console.log('🛑 Shutting down event emitter...');
    
    if (this.wsServer) {
      this.wsServer.close();
    }
    
    this.connectedClients.clear();
    this.removeAllListeners();
    
    console.log('✅ Event emitter shut down');
  }
}