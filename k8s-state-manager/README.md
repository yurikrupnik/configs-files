# K8s State Manager

A SolidJS-based state machine for managing Kubernetes resource status with Polars data processing and real-time event emission.

## Features

- 🎛️ **Reactive State Management**: SolidJS-powered state machine tracking K8s resource lifecycle
- 🐻‍❄️ **Data Processing**: Polars integration for efficient data analysis and trend detection
- 📡 **Real-time Events**: WebSocket-based event emission with filtering and routing
- 🔍 **Advanced Querying**: Complex resource queries with state transition history
- 📊 **Analytics**: Health monitoring, compliance reporting, and trend analysis
- 🚨 **Alerting**: Configurable alerts via webhooks, Slack, and custom endpoints

## Quick Start

```bash
# Install dependencies
bun install

# Start the state manager
bun run start

# Or use Nu script integration
nu ../scripts/state-machine-integration.nu state start-manager
```

## Configuration

Create `config.json`:

```json
{
  "watcher": {
    "namespaces": ["default", "kube-system"],
    "resourceTypes": ["pods", "services", "deployments", "configmaps", "secrets"],
    "reconnectInterval": 5000
  },
  "emitter": {
    "webhookUrls": ["https://your-webhook.com/k8s-events"],
    "websocketPort": 8080,
    "slackChannel": "#k8s-alerts",
    "enableMetrics": true,
    "filterCriteria": {
      "criticality": "medium",
      "resourceTypes": ["pods", "deployments"],
      "namespaces": ["production"]
    }
  },
  "polars": {
    "dataDir": "./data",
    "retentionDays": 7,
    "analysisInterval": 300
  }
}
```

## Environment Variables

```bash
# Kubernetes
K8S_NAMESPACES=default,kube-system
K8S_RESOURCE_TYPES=pods,services,deployments,configmaps,secrets
CLUSTER_NAME=my-cluster

# WebSocket & Events
WS_PORT=8080
ENABLE_METRICS=true
EVENT_CRITICALITY=medium

# Webhooks & Notifications
WEBHOOK_URLS=https://webhook1.com,https://webhook2.com
SLACK_WEBHOOK_URL=https://hooks.slack.com/...
SLACK_CHANNEL=#k8s-alerts

# Data Management  
DATA_DIR=./data
RETENTION_DAYS=7
ANALYSIS_INTERVAL=300

# Filtering
FILTER_RESOURCE_TYPES=pods,deployments
FILTER_NAMESPACES=production,staging
```

## API Examples

### WebSocket Connection

```javascript
const ws = new WebSocket('ws://localhost:8080/k8s-events');

ws.onmessage = (event) => {
  const data = JSON.parse(event.data);
  
  if (data.type === 'event') {
    console.log('Resource update:', data.data);
  }
};
```

### Nu Script Integration

```bash
# Query resources
nu ../scripts/state-machine-integration.nu state query-resources \
  --namespace production \
  --kind Pod \
  --state Running

# Watch events  
nu ../scripts/state-machine-integration.nu state watch-events \
  --filter-severity warning \
  --resource-type Deployment

# Analyze trends
nu ../scripts/state-machine-integration.nu state analyze-trends \
  --window 1h \
  --namespace production \
  --save-report

# Create dashboard
nu ../scripts/state-machine-integration.nu state create-dashboard ./dashboard
```

### Polars Data Processing

```bash
# Resource health analysis
nu ../scripts/polars-data-manager.nu polars analyze-resource-health \
  --window 24h \
  --namespace production

# Usage trends
nu ../scripts/polars-data-manager.nu polars resource-usage-trends \
  --namespace production \
  --duration 1h

# Compliance report
nu ../scripts/polars-data-manager.nu polars generate-compliance-report \
  --namespace production \
  --output-file compliance-$(date now | format date '%Y%m%d').json
```

## Event Types

### Resource Updates
```json
{
  "id": "evt_1234567890_abc123",
  "timestamp": "2024-01-15T10:30:00Z",
  "type": "state_change",
  "severity": "warning",
  "resource": {
    "kind": "Pod",
    "name": "my-app-pod",
    "namespace": "production"
  },
  "payload": {
    "updateType": "MODIFIED",
    "previousState": "Running",
    "currentState": "Pending",
    "stateHistory": [...]
  }
}
```

### Metrics Events
```json
{
  "type": "metrics",
  "payload": {
    "totalEvents": 1542,
    "recentUpdates": 12,
    "resourceCount": 45,
    "health": {
      "healthy": 38,
      "unhealthy": 5,
      "unknown": 2
    }
  }
}
```

## Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   K8s Cluster   │───▶│   K8s Watcher    │───▶│  State Machine  │
└─────────────────┘    └──────────────────┘    └─────────────────┘
                                                         │
                       ┌──────────────────┐              │
                       │ Polars Processor │◀─────────────┘
                       └──────────────────┘              │
                                │                        │
                                ▼                        ▼
                       ┌──────────────────┐    ┌─────────────────┐
                       │   Data Storage   │    │  Event Emitter  │
                       │   (Parquet)      │    └─────────────────┘
                       └──────────────────┘              │
                                                         ▼
                                                ┌─────────────────┐
                                                │   WebSocket     │
                                                │   Webhooks      │
                                                │   Slack         │
                                                └─────────────────┘
```

## Data Flow

1. **Resource Watching**: K8s API events are captured via watchers
2. **State Processing**: SolidJS state machine processes resource lifecycle
3. **Data Analysis**: Polars performs real-time analysis and trend detection  
4. **Event Emission**: Filtered events are emitted via WebSocket/webhooks
5. **Storage**: Event history and analysis results stored in Parquet format
6. **Visualization**: Nu scripts provide querying and dashboard generation

## Integration with Nu Scripts

The state manager integrates seamlessly with your existing Nu scripts:

- **Polars Integration**: All data processing uses Polars for performance
- **Event-driven Updates**: CRD, ConfigMap, and Secret changes trigger events
- **State Tracking**: Complete resource lifecycle with transition history
- **Custom Events**: Emit custom events from Nu scripts
- **Real-time Dashboard**: Generate HTML dashboards with live updates

## Development

```bash
# Development mode
bun run dev

# Build for production  
bun run build

# Run tests
bun test

# Type checking
bun run tsc --noEmit
```

## Deployment

The state manager can run as:
- Standalone process on your machine
- Kubernetes deployment in cluster
- Docker container with volume mounts
- Background service via Nu scripts