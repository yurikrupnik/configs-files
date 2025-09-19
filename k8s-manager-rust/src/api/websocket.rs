use axum::{
    extract::{
        ws::{Message, WebSocket, WebSocketUpgrade},
        State,
    },
    response::Response,
};
use futures::{SinkExt, StreamExt};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use tokio::sync::broadcast;
use uuid::Uuid;

use crate::{AppState, state::ResourceEvent};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct WebSocketMessage {
    #[serde(rename = "type")]
    pub message_type: String,
    pub data: serde_json::Value,
    pub timestamp: chrono::DateTime<chrono::Utc>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ClientMessage {
    #[serde(rename = "type")]
    pub message_type: String,
    pub data: Option<serde_json::Value>,
}

#[derive(Debug, Clone, Serialize)]
pub struct EventMessage {
    pub event: ResourceEvent,
    pub metrics: crate::state::StateMetrics,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SubscriptionFilter {
    pub namespaces: Option<Vec<String>>,
    pub resource_types: Option<Vec<String>>,
    pub event_types: Option<Vec<String>>,
    pub severity_levels: Option<Vec<String>>,
}

pub async fn websocket_handler(
    ws: WebSocketUpgrade,
    State(app_state): State<AppState>,
) -> Response {
    ws.on_upgrade(|socket| websocket_connection(socket, app_state))
}

async fn websocket_connection(socket: WebSocket, app_state: AppState) {
    let client_id = Uuid::new_v4();
    tracing::info!("WebSocket client {} connected", client_id);

    let (mut sender, mut receiver) = socket.split();
    let (tx, mut rx) = broadcast::channel::<WebSocketMessage>(100);
    
    // Clone the sender for sending messages to this client
    let client_tx = tx.clone();
    
    // Send initial state to the client
    let initial_state = {
        let state = app_state.state_manager.read().await;
        WebSocketMessage {
            message_type: "initial_state".to_string(),
            data: serde_json::json!({
                "resources": state.resources,
                "metrics": state.metrics,
                "client_id": client_id
            }),
            timestamp: chrono::Utc::now(),
        }
    };

    if let Ok(msg) = serde_json::to_string(&initial_state) {
        let _ = sender.send(Message::Text(msg.into())).await;
    }

    // Task to handle incoming messages from client
    let app_state_clone = app_state.clone();
    let handle_incoming = tokio::spawn(async move {
        let mut subscription_filter = SubscriptionFilter {
            namespaces: None,
            resource_types: None,
            event_types: None,
            severity_levels: None,
        };

        while let Some(msg) = receiver.next().await {
            match msg {
                Ok(Message::Text(text)) => {
                    if let Ok(client_msg) = serde_json::from_str::<ClientMessage>(&text) {
                        match handle_client_message(client_msg, &mut subscription_filter, &app_state_clone, &client_tx).await {
                            Ok(_) => {}
                            Err(e) => {
                                tracing::error!("Error handling client message: {}", e);
                                break;
                            }
                        }
                    }
                }
                Ok(Message::Close(_)) => {
                    tracing::info!("WebSocket client {} closed connection", client_id);
                    break;
                }
                Err(e) => {
                    tracing::error!("WebSocket error for client {}: {}", client_id, e);
                    break;
                }
                _ => {}
            }
        }
    });

    // Task to send messages to client
    let handle_outgoing = tokio::spawn(async move {
        while let Ok(message) = rx.recv().await {
            let serialized = match serde_json::to_string(&message) {
                Ok(s) => s,
                Err(e) => {
                    tracing::error!("Failed to serialize message: {}", e);
                    continue;
                }
            };

            if let Err(e) = sender.send(Message::Text(serialized.into())).await {
                tracing::error!("Failed to send message to client {}: {}", client_id, e);
                break;
            }
        }
    });

    // Wait for either task to complete
    tokio::select! {
        _ = handle_incoming => {
            tracing::info!("Incoming message handler completed for client {}", client_id);
        }
        _ = handle_outgoing => {
            tracing::info!("Outgoing message handler completed for client {}", client_id);
        }
    }

    tracing::info!("WebSocket client {} disconnected", client_id);
}

async fn handle_client_message(
    message: ClientMessage,
    filter: &mut SubscriptionFilter,
    app_state: &AppState,
    tx: &broadcast::Sender<WebSocketMessage>,
) -> crate::Result<()> {
    match message.message_type.as_str() {
        "ping" => {
            let response = WebSocketMessage {
                message_type: "pong".to_string(),
                data: serde_json::json!({"timestamp": chrono::Utc::now()}),
                timestamp: chrono::Utc::now(),
            };
            let _ = tx.send(response);
        }
        "subscribe" => {
            if let Some(data) = message.data {
                if let Ok(new_filter) = serde_json::from_value::<SubscriptionFilter>(data) {
                    *filter = new_filter;
                    let response = WebSocketMessage {
                        message_type: "subscription_updated".to_string(),
                        data: serde_json::to_value(filter)?,
                        timestamp: chrono::Utc::now(),
                    };
                    let _ = tx.send(response);
                }
            }
        }
        "get_resources" => {
            let state = app_state.state_manager.read().await;
            let filtered_resources = apply_resource_filter(&state.resources, filter);
            
            let response = WebSocketMessage {
                message_type: "resources".to_string(),
                data: serde_json::json!({
                    "resources": filtered_resources,
                    "total": filtered_resources.len(),
                    "timestamp": chrono::Utc::now()
                }),
                timestamp: chrono::Utc::now(),
            };
            let _ = tx.send(response);
        }
        "get_events" => {
            let state = app_state.state_manager.read().await;
            let recent_events = state.get_recent_events(100);
            
            let response = WebSocketMessage {
                message_type: "events".to_string(),
                data: serde_json::json!({
                    "events": recent_events,
                    "total": recent_events.len(),
                    "timestamp": chrono::Utc::now()
                }),
                timestamp: chrono::Utc::now(),
            };
            let _ = tx.send(response);
        }
        "get_metrics" => {
            let state = app_state.state_manager.read().await;
            let metrics = state.get_metrics();
            
            let response = WebSocketMessage {
                message_type: "metrics".to_string(),
                data: serde_json::to_value(metrics)?,
                timestamp: chrono::Utc::now(),
            };
            let _ = tx.send(response);
        }
        "clear_events" => {
            let mut state = app_state.state_manager.write().await;
            state.clear_history();
            
            let response = WebSocketMessage {
                message_type: "events_cleared".to_string(),
                data: serde_json::json!({"status": "success"}),
                timestamp: chrono::Utc::now(),
            };
            let _ = tx.send(response);
        }
        "export_state" => {
            let state = app_state.state_manager.read().await;
            let exported = state.export_state();
            
            let response = WebSocketMessage {
                message_type: "state_export".to_string(),
                data: exported,
                timestamp: chrono::Utc::now(),
            };
            let _ = tx.send(response);
        }
        _ => {
            let response = WebSocketMessage {
                message_type: "error".to_string(),
                data: serde_json::json!({
                    "message": format!("Unknown message type: {}", message.message_type)
                }),
                timestamp: chrono::Utc::now(),
            };
            let _ = tx.send(response);
        }
    }
    
    Ok(())
}

fn apply_resource_filter(
    resources: &HashMap<String, crate::state::ResourceStateMachine>,
    filter: &SubscriptionFilter,
) -> HashMap<String, crate::state::ResourceStateMachine> {
    let mut filtered = HashMap::new();
    
    for (key, resource) in resources {
        let mut include = true;
        
        // Filter by namespace
        if let Some(ref namespaces) = filter.namespaces {
            let resource_namespace = resource.resource.namespace.as_deref().unwrap_or("default");
            if !namespaces.contains(&resource_namespace.to_string()) {
                include = false;
            }
        }
        
        // Filter by resource type
        if let Some(ref types) = filter.resource_types {
            if !types.contains(&resource.resource.kind) {
                include = false;
            }
        }
        
        if include {
            filtered.insert(key.clone(), resource.clone());
        }
    }
    
    filtered
}

pub async fn broadcast_resource_event(
    event: ResourceEvent,
    state_manager: &tokio::sync::RwLock<crate::state::StateManager>,
    broadcasters: &[broadcast::Sender<WebSocketMessage>],
) -> crate::Result<()> {
    let metrics = {
        let state = state_manager.read().await;
        state.get_metrics().clone()
    };
    
    let message = WebSocketMessage {
        message_type: "resource_event".to_string(),
        data: serde_json::json!(EventMessage { event, metrics }),
        timestamp: chrono::Utc::now(),
    };
    
    for broadcaster in broadcasters {
        let _ = broadcaster.send(message.clone());
    }
    
    Ok(())
}