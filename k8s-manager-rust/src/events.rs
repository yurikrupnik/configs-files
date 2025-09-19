use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use tokio::sync::broadcast;
use uuid::Uuid;

use crate::state::{ResourceEvent, ResourceStateMachine, StateMetrics};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct EventEmitter {
    webhook_urls: Vec<String>,
    slack_webhook: Option<String>,
    filter_severity: String,
    event_buffer: Vec<EmittedEvent>,
    buffer_size: usize,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct EmittedEvent {
    pub id: String,
    pub timestamp: chrono::DateTime<chrono::Utc>,
    pub event_type: String,
    pub severity: String,
    pub resource: Option<ResourceInfo>,
    pub payload: serde_json::Value,
    pub metadata: EventMetadata,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ResourceInfo {
    pub kind: String,
    pub name: String,
    pub namespace: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct EventMetadata {
    pub source: String,
    pub cluster: String,
    pub correlation_id: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SlackNotification {
    pub channel: String,
    pub username: String,
    pub icon_emoji: String,
    pub attachments: Vec<SlackAttachment>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SlackAttachment {
    pub color: String,
    pub title: String,
    pub fields: Vec<SlackField>,
    pub timestamp: i64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SlackField {
    pub title: String,
    pub value: String,
    pub short: bool,
}

impl EventEmitter {
    pub fn new(
        webhook_urls: Vec<String>,
        slack_webhook: Option<String>,
        filter_severity: String,
    ) -> Self {
        Self {
            webhook_urls,
            slack_webhook,
            filter_severity,
            event_buffer: Vec::new(),
            buffer_size: 1000,
        }
    }

    pub async fn emit_resource_event(
        &mut self,
        event: ResourceEvent,
        machine: Option<&ResourceStateMachine>,
        metrics: &StateMetrics,
    ) -> crate::Result<()> {
        let emitted_event = self.create_emitted_event(event, machine)?;
        
        if self.should_emit_event(&emitted_event) {
            self.add_to_buffer(emitted_event.clone());
            self.send_to_webhooks(&emitted_event).await?;
            self.send_to_slack(&emitted_event).await?;
        }

        Ok(())
    }

    pub async fn emit_metrics_update(&mut self, metrics: &StateMetrics) -> crate::Result<()> {
        let event = EmittedEvent {
            id: self.generate_event_id(),
            timestamp: chrono::Utc::now(),
            event_type: "metrics_update".to_string(),
            severity: "info".to_string(),
            resource: None,
            payload: serde_json::to_value(metrics)?,
            metadata: EventMetadata {
                source: "k8s-manager".to_string(),
                cluster: std::env::var("CLUSTER_NAME").unwrap_or_else(|_| "local".to_string()),
                correlation_id: None,
            },
        };

        if self.should_emit_event(&event) {
            self.add_to_buffer(event.clone());
            self.send_to_webhooks(&event).await?;
        }

        Ok(())
    }

    pub async fn emit_alert(
        &mut self,
        alert_type: &str,
        severity: &str,
        message: &str,
        resource: Option<ResourceInfo>,
        data: Option<serde_json::Value>,
    ) -> crate::Result<()> {
        let event = EmittedEvent {
            id: self.generate_event_id(),
            timestamp: chrono::Utc::now(),
            event_type: alert_type.to_string(),
            severity: severity.to_string(),
            resource,
            payload: serde_json::json!({
                "message": message,
                "data": data.unwrap_or_default(),
            }),
            metadata: EventMetadata {
                source: "k8s-manager".to_string(),
                cluster: std::env::var("CLUSTER_NAME").unwrap_or_else(|_| "local".to_string()),
                correlation_id: Some(Uuid::new_v4().to_string()),
            },
        };

        if self.should_emit_event(&event) {
            self.add_to_buffer(event.clone());
            self.send_to_webhooks(&event).await?;
            self.send_to_slack(&event).await?;
        }

        Ok(())
    }

    fn create_emitted_event(
        &self,
        resource_event: ResourceEvent,
        machine: Option<&ResourceStateMachine>,
    ) -> crate::Result<EmittedEvent> {
        let severity = self.determine_severity(&resource_event, machine);
        
        let resource_info = ResourceInfo {
            kind: resource_event.resource.kind.clone(),
            name: resource_event.resource.name.clone(),
            namespace: resource_event.resource.namespace.clone().unwrap_or_else(|| "default".to_string()),
        };

        let payload = serde_json::json!({
            "event_type": resource_event.event_type,
            "previous_state": resource_event.previous_state,
            "current_state": resource_event.current_state,
            "resource": resource_event.resource,
            "message": resource_event.message,
            "state_history": machine.map(|m| m.state_history.iter().rev().take(5).collect::<Vec<_>>()),
        });

        Ok(EmittedEvent {
            id: resource_event.id.to_string(),
            timestamp: resource_event.timestamp,
            event_type: "resource_update".to_string(),
            severity,
            resource: Some(resource_info),
            payload,
            metadata: EventMetadata {
                source: "k8s-watcher".to_string(),
                cluster: std::env::var("CLUSTER_NAME").unwrap_or_else(|_| "local".to_string()),
                correlation_id: Some(resource_event.resource.uid.clone()),
            },
        })
    }

    fn determine_severity(&self, event: &ResourceEvent, machine: Option<&ResourceStateMachine>) -> String {
        // Critical events
        if matches!(event.event_type, crate::state::EventType::Deleted) 
            || matches!(event.current_state, crate::state::ResourceState::Failed) {
            return "critical".to_string();
        }

        // Error events
        if matches!(event.current_state, crate::state::ResourceState::Terminating) {
            return "error".to_string();
        }

        // Warning events
        if matches!(event.current_state, crate::state::ResourceState::Pending | crate::state::ResourceState::Unknown) {
            return "warning".to_string();
        }

        // Check for rapid state changes
        if let Some(machine) = machine {
            let recent_transitions = machine.state_history.len();
            if recent_transitions > 10 {
                return "warning".to_string();
            }
        }

        "info".to_string()
    }

    fn should_emit_event(&self, event: &EmittedEvent) -> bool {
        let severity_levels = ["info", "warning", "error", "critical"];
        let min_level = severity_levels
            .iter()
            .position(|&s| s == self.filter_severity)
            .unwrap_or(0);
        let event_level = severity_levels
            .iter()
            .position(|&s| s == event.severity)
            .unwrap_or(0);

        event_level >= min_level
    }

    fn add_to_buffer(&mut self, event: EmittedEvent) {
        self.event_buffer.push(event);
        if self.event_buffer.len() > self.buffer_size {
            self.event_buffer.drain(0..self.buffer_size / 2);
        }
    }

    async fn send_to_webhooks(&self, event: &EmittedEvent) -> crate::Result<()> {
        for url in &self.webhook_urls {
            let client = reqwest::Client::new();
            
            match client
                .post(url)
                .header("Content-Type", "application/json")
                .header("User-Agent", "k8s-manager/1.0")
                .json(event)
                .send()
                .await
            {
                Ok(response) => {
                    if response.status().is_success() {
                        tracing::debug!("Webhook sent successfully to {}", url);
                    } else {
                        tracing::warn!("Webhook failed for {}: {}", url, response.status());
                    }
                }
                Err(e) => {
                    tracing::error!("Failed to send webhook to {}: {}", url, e);
                }
            }
        }
        
        Ok(())
    }

    async fn send_to_slack(&self, event: &EmittedEvent) -> crate::Result<()> {
        if let Some(ref webhook_url) = self.slack_webhook {
            // Only send warnings and above to Slack
            if !matches!(event.severity.as_str(), "warning" | "error" | "critical") {
                return Ok(());
            }

            let color = match event.severity.as_str() {
                "warning" => "warning",
                "error" | "critical" => "danger",
                _ => "good",
            };

            let title = if let Some(ref resource) = event.resource {
                format!(
                    "{}: {}/{}",
                    event.event_type.replace('_', " ").to_uppercase(),
                    resource.kind,
                    resource.name
                )
            } else {
                event.event_type.replace('_', " ").to_uppercase()
            };

            let mut fields = vec![
                SlackField {
                    title: "Severity".to_string(),
                    value: event.severity.to_uppercase(),
                    short: true,
                },
                SlackField {
                    title: "Cluster".to_string(),
                    value: event.metadata.cluster.clone(),
                    short: true,
                },
            ];

            if let Some(ref resource) = event.resource {
                fields.push(SlackField {
                    title: "Namespace".to_string(),
                    value: resource.namespace.clone(),
                    short: true,
                });
            }

            if let Some(payload_data) = event.payload.get("message") {
                if let Some(message) = payload_data.as_str() {
                    fields.push(SlackField {
                        title: "Details".to_string(),
                        value: message.to_string(),
                        short: false,
                    });
                }
            }

            let notification = SlackNotification {
                channel: "#k8s-alerts".to_string(),
                username: "K8s Manager".to_string(),
                icon_emoji: ":kubernetes:".to_string(),
                attachments: vec![SlackAttachment {
                    color: color.to_string(),
                    title,
                    fields,
                    timestamp: event.timestamp.timestamp(),
                }],
            };

            let client = reqwest::Client::new();
            match client
                .post(webhook_url)
                .header("Content-Type", "application/json")
                .json(&notification)
                .send()
                .await
            {
                Ok(response) => {
                    if response.status().is_success() {
                        tracing::debug!("Slack notification sent successfully");
                    } else {
                        tracing::warn!("Slack notification failed: {}", response.status());
                    }
                }
                Err(e) => {
                    tracing::error!("Failed to send Slack notification: {}", e);
                }
            }
        }

        Ok(())
    }

    fn generate_event_id(&self) -> String {
        format!("evt_{}_{}", 
                chrono::Utc::now().timestamp(), 
                Uuid::new_v4().to_string()[0..8].to_string())
    }

    pub fn get_event_buffer(&self) -> &[EmittedEvent] {
        &self.event_buffer
    }

    pub fn get_event_stats(&self) -> HashMap<String, u64> {
        let mut stats = HashMap::new();
        
        for event in &self.event_buffer {
            *stats.entry(event.severity.clone()).or_insert(0) += 1;
            *stats.entry(event.event_type.clone()).or_insert(0) += 1;
        }

        stats.insert("total_events".to_string(), self.event_buffer.len() as u64);
        stats
    }

    pub fn clear_buffer(&mut self) {
        self.event_buffer.clear();
    }
}