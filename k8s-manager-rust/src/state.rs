use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use uuid::Uuid;

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq)]
pub enum ResourceState {
    Pending,
    Running,
    Succeeded,
    Failed,
    Unknown,
    Terminating,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ResourceEvent {
    pub id: Uuid,
    pub timestamp: DateTime<Utc>,
    pub event_type: EventType,
    pub resource: K8sResource,
    pub previous_state: Option<ResourceState>,
    pub current_state: ResourceState,
    pub message: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum EventType {
    Added,
    Modified,
    Deleted,
    Error,
    Warning,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct K8sResource {
    pub api_version: String,
    pub kind: String,
    pub namespace: Option<String>,
    pub name: String,
    pub uid: String,
    pub resource_version: String,
    pub labels: HashMap<String, String>,
    pub annotations: HashMap<String, String>,
    pub spec: Option<serde_json::Value>,
    pub status: Option<serde_json::Value>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ResourceStateMachine {
    pub resource_key: String,
    pub current_state: ResourceState,
    pub previous_state: Option<ResourceState>,
    pub state_history: Vec<StateTransition>,
    pub last_updated: DateTime<Utc>,
    pub resource: K8sResource,
    pub event_count: u64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct StateTransition {
    pub from: ResourceState,
    pub to: ResourceState,
    pub timestamp: DateTime<Utc>,
    pub trigger: String,
}

#[derive(Debug, Clone, Default)]
pub struct StateManager {
    pub resources: HashMap<String, ResourceStateMachine>,
    pub events: Vec<ResourceEvent>,
    pub metrics: StateMetrics,
}

#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct StateMetrics {
    pub total_resources: u64,
    pub healthy_resources: u64,
    pub unhealthy_resources: u64,
    pub unknown_resources: u64,
    pub total_events: u64,
    pub events_last_hour: u64,
    pub last_updated: Option<DateTime<Utc>>,
}

impl StateManager {
    pub fn new() -> Self {
        Self::default()
    }

    pub fn process_event(&mut self, event: ResourceEvent) -> crate::Result<()> {
        let resource_key = self.generate_resource_key(&event.resource);
        
        // Add to events history
        self.events.push(event.clone());
        if self.events.len() > 1000 {
            self.events.drain(0..500); // Keep latest 500 when exceeding 1000
        }

        // Update or create resource state machine
        if let Some(machine) = self.resources.get_mut(&resource_key) {
            let previous_state = machine.current_state.clone();
            machine.previous_state = Some(previous_state.clone());
            machine.current_state = event.current_state.clone();
            machine.last_updated = event.timestamp;
            machine.resource = event.resource.clone();
            machine.event_count += 1;

            // Add state transition if state changed
            if previous_state != event.current_state {
                machine.state_history.push(StateTransition {
                    from: previous_state,
                    to: event.current_state.clone(),
                    timestamp: event.timestamp,
                    trigger: format!("{:?}", event.event_type),
                });

                // Keep only last 50 transitions
                if machine.state_history.len() > 50 {
                    machine.state_history.drain(0..25);
                }
            }
        } else {
            self.create_new_resource(resource_key, event)?;
        }

        self.update_metrics();
        Ok(())
    }


    fn create_new_resource(
        &mut self,
        resource_key: String,
        event: ResourceEvent,
    ) -> crate::Result<()> {
        let machine = ResourceStateMachine {
            resource_key: resource_key.clone(),
            current_state: event.current_state.clone(),
            previous_state: event.previous_state.clone(),
            state_history: vec![],
            last_updated: event.timestamp,
            resource: event.resource.clone(),
            event_count: 1,
        };

        self.resources.insert(resource_key, machine);
        Ok(())
    }

    fn generate_resource_key(&self, resource: &K8sResource) -> String {
        format!(
            "{}/{}/{}",
            resource.kind,
            resource.namespace.as_deref().unwrap_or("default"),
            resource.name
        )
    }

    fn update_metrics(&mut self) {
        let now = Utc::now();
        let one_hour_ago = now - chrono::Duration::hours(1);

        self.metrics.total_resources = self.resources.len() as u64;
        self.metrics.total_events = self.events.len() as u64;
        
        self.metrics.events_last_hour = self
            .events
            .iter()
            .filter(|e| e.timestamp > one_hour_ago)
            .count() as u64;

        let (healthy, unhealthy, unknown) = self.resources.values().fold(
            (0, 0, 0),
            |(healthy, unhealthy, unknown), machine| {
                match machine.current_state {
                    ResourceState::Running | ResourceState::Succeeded => (healthy + 1, unhealthy, unknown),
                    ResourceState::Failed | ResourceState::Terminating => (healthy, unhealthy + 1, unknown),
                    _ => (healthy, unhealthy, unknown + 1),
                }
            },
        );

        self.metrics.healthy_resources = healthy;
        self.metrics.unhealthy_resources = unhealthy;
        self.metrics.unknown_resources = unknown;
        self.metrics.last_updated = Some(now);
    }

    pub fn get_resources_by_state(&self, state: &ResourceState) -> Vec<&ResourceStateMachine> {
        self.resources
            .values()
            .filter(|machine| &machine.current_state == state)
            .collect()
    }

    pub fn get_resources_by_kind(&self, kind: &str) -> Vec<&ResourceStateMachine> {
        self.resources
            .values()
            .filter(|machine| machine.resource.kind == kind)
            .collect()
    }

    pub fn get_resources_by_namespace(&self, namespace: &str) -> Vec<&ResourceStateMachine> {
        self.resources
            .values()
            .filter(|machine| {
                machine.resource.namespace.as_deref().unwrap_or("default") == namespace
            })
            .collect()
    }

    pub fn get_recent_events(&self, limit: usize) -> Vec<&ResourceEvent> {
        self.events
            .iter()
            .rev()
            .take(limit)
            .collect()
    }

    pub fn get_resource(&self, resource_key: &str) -> Option<&ResourceStateMachine> {
        self.resources.get(resource_key)
    }

    pub fn get_metrics(&self) -> &StateMetrics {
        &self.metrics
    }

    pub fn clear_history(&mut self) {
        self.events.clear();
        for machine in self.resources.values_mut() {
            machine.state_history.clear();
        }
    }

    pub fn export_state(&self) -> serde_json::Value {
        serde_json::json!({
            "resources": self.resources,
            "events": self.events.iter().rev().take(100).collect::<Vec<_>>(),
            "metrics": self.metrics,
            "timestamp": Utc::now(),
        })
    }
}

impl ResourceState {
    pub fn is_healthy(&self) -> bool {
        matches!(self, ResourceState::Running | ResourceState::Succeeded)
    }

    pub fn is_unhealthy(&self) -> bool {
        matches!(self, ResourceState::Failed | ResourceState::Terminating)
    }
}

impl std::fmt::Display for ResourceState {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            ResourceState::Pending => write!(f, "Pending"),
            ResourceState::Running => write!(f, "Running"),
            ResourceState::Succeeded => write!(f, "Succeeded"),
            ResourceState::Failed => write!(f, "Failed"),
            ResourceState::Unknown => write!(f, "Unknown"),
            ResourceState::Terminating => write!(f, "Terminating"),
        }
    }
}

impl EventType {
    pub fn severity(&self) -> &str {
        match self {
            EventType::Added => "info",
            EventType::Modified => "info",
            EventType::Deleted => "warning",
            EventType::Error => "error",
            EventType::Warning => "warning",
        }
    }
}