use axum::{
    extract::{Path, Query, State},
    http::StatusCode,
    Json,
};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;

use crate::{AppState, ResourceState};

#[derive(Serialize)]
pub struct HealthResponse {
    status: String,
    timestamp: chrono::DateTime<chrono::Utc>,
    version: String,
}

#[derive(Serialize)]
pub struct StatusResponse {
    connected: bool,
    resources_count: usize,
    events_count: usize,
    last_update: Option<chrono::DateTime<chrono::Utc>>,
    watchers: HashMap<String, String>,
}

#[derive(Deserialize)]
pub struct ResourceQuery {
    namespace: Option<String>,
    state: Option<String>,
    kind: Option<String>,
    limit: Option<usize>,
    offset: Option<usize>,
}

#[derive(Deserialize)]
pub struct EventQuery {
    limit: Option<usize>,
    since: Option<chrono::DateTime<chrono::Utc>>,
    severity: Option<String>,
}

#[derive(Serialize)]
pub struct ResourceResponse {
    resources: Vec<crate::state::ResourceStateMachine>,
    total: usize,
    filtered: usize,
}

#[derive(Serialize)]
pub struct EventResponse {
    events: Vec<crate::state::ResourceEvent>,
    total: usize,
    filtered: usize,
}

#[derive(Serialize)]
pub struct MetricsResponse {
    total_resources: u64,
    healthy_resources: u64,
    unhealthy_resources: u64,
    unknown_resources: u64,
    total_events: u64,
    events_last_hour: u64,
    uptime: u64,
    last_updated: Option<chrono::DateTime<chrono::Utc>>,
}

#[derive(Deserialize)]
pub struct DataQuery {
    query: String,
    parameters: Option<serde_json::Value>,
}

#[derive(Serialize)]
pub struct AnalysisResponse {
    timestamp: chrono::DateTime<chrono::Utc>,
    insights: Vec<Insight>,
    metrics: serde_json::Value,
}

#[derive(Serialize)]
pub struct Insight {
    #[serde(rename = "type")]
    insight_type: String,
    severity: String,
    message: String,
    recommendation: Option<String>,
}

pub async fn health() -> Json<HealthResponse> {
    Json(HealthResponse {
        status: "healthy".to_string(),
        timestamp: chrono::Utc::now(),
        version: env!("CARGO_PKG_VERSION").to_string(),
    })
}

pub async fn status(State(app_state): State<AppState>) -> std::result::Result<Json<StatusResponse>, StatusCode> {
    let state = app_state.state_manager.read().await;
    
    Ok(Json(StatusResponse {
        connected: true, // This would check actual connection status
        resources_count: state.resources.len(),
        events_count: state.events.len(),
        last_update: state.metrics.last_updated,
        watchers: HashMap::new(), // This would show active watchers
    }))
}

pub async fn metrics(State(app_state): State<AppState>) -> std::result::Result<Json<MetricsResponse>, StatusCode> {
    let state = app_state.state_manager.read().await;
    let metrics = state.get_metrics();
    
    Ok(Json(MetricsResponse {
        total_resources: metrics.total_resources,
        healthy_resources: metrics.healthy_resources,
        unhealthy_resources: metrics.unhealthy_resources,
        unknown_resources: metrics.unknown_resources,
        total_events: metrics.total_events,
        events_last_hour: metrics.events_last_hour,
        uptime: 0, // This would calculate actual uptime
        last_updated: metrics.last_updated,
    }))
}

pub async fn list_resources(
    State(app_state): State<AppState>,
    Query(params): Query<ResourceQuery>,
) -> std::result::Result<Json<ResourceResponse>, StatusCode> {
    let state = app_state.state_manager.read().await;
    let mut resources: Vec<_> = state.resources.values().cloned().collect();
    let total = resources.len();

    // Apply filters
    if let Some(ref namespace) = params.namespace {
        resources.retain(|r| r.resource.namespace.as_deref().unwrap_or("default") == namespace);
    }

    if let Some(ref state_filter) = params.state {
        if let Ok(parsed_state) = parse_resource_state(state_filter) {
            resources.retain(|r| r.current_state == parsed_state);
        }
    }

    if let Some(ref kind) = params.kind {
        resources.retain(|r| r.resource.kind == *kind);
    }

    let filtered = resources.len();

    // Apply pagination
    let offset = params.offset.unwrap_or(0);
    let limit = params.limit.unwrap_or(50).min(1000);
    
    resources.sort_by(|a, b| b.last_updated.cmp(&a.last_updated));
    
    let paginated: Vec<_> = resources
        .into_iter()
        .skip(offset)
        .take(limit)
        .collect();

    Ok(Json(ResourceResponse {
        resources: paginated,
        total,
        filtered,
    }))
}

pub async fn list_resources_by_kind(
    State(app_state): State<AppState>,
    Path(kind): Path<String>,
    Query(params): Query<ResourceQuery>,
) -> std::result::Result<Json<ResourceResponse>, StatusCode> {
    let mut modified_params = params;
    modified_params.kind = Some(kind);
    list_resources(State(app_state), Query(modified_params)).await
}

pub async fn get_resource(
    State(app_state): State<AppState>,
    Path((kind, namespace, name)): Path<(String, String, String)>,
) -> std::result::Result<Json<crate::state::ResourceStateMachine>, StatusCode> {
    let state = app_state.state_manager.read().await;
    let resource_key = format!("{}/{}/{}", kind, namespace, name);
    
    match state.get_resource(&resource_key) {
        Some(resource) => Ok(Json(resource.clone())),
        None => Err(StatusCode::NOT_FOUND),
    }
}

pub async fn get_resource_history(
    State(app_state): State<AppState>,
    Path((kind, namespace, name)): Path<(String, String, String)>,
) -> std::result::Result<Json<Vec<crate::state::StateTransition>>, StatusCode> {
    let state = app_state.state_manager.read().await;
    let resource_key = format!("{}/{}/{}", kind, namespace, name);
    
    match state.get_resource(&resource_key) {
        Some(resource) => Ok(Json(resource.state_history.clone())),
        None => Err(StatusCode::NOT_FOUND),
    }
}

pub async fn list_events(
    State(app_state): State<AppState>,
    Query(params): Query<EventQuery>,
) -> std::result::Result<Json<EventResponse>, StatusCode> {
    let state = app_state.state_manager.read().await;
    let mut events = state.events.clone();
    let total = events.len();

    // Apply filters
    if let Some(since) = params.since {
        events.retain(|e| e.timestamp > since);
    }

    if let Some(ref severity) = params.severity {
        events.retain(|e| e.event_type.severity() == severity);
    }

    let filtered = events.len();
    let limit = params.limit.unwrap_or(100).min(1000);
    
    events.sort_by(|a, b| b.timestamp.cmp(&a.timestamp));
    events.truncate(limit);

    Ok(Json(EventResponse {
        events,
        total,
        filtered,
    }))
}

pub async fn recent_events(
    State(app_state): State<AppState>,
) -> std::result::Result<Json<Vec<crate::state::ResourceEvent>>, StatusCode> {
    let state = app_state.state_manager.read().await;
    let recent = state.get_recent_events(50);
    Ok(Json(recent.into_iter().cloned().collect()))
}

pub async fn clear_events(
    State(app_state): State<AppState>,
) -> std::result::Result<StatusCode, StatusCode> {
    let mut state = app_state.state_manager.write().await;
    state.clear_history();
    Ok(StatusCode::NO_CONTENT)
}

pub async fn export_state(
    State(app_state): State<AppState>,
) -> std::result::Result<Json<serde_json::Value>, StatusCode> {
    let state = app_state.state_manager.read().await;
    let exported = state.export_state();
    Ok(Json(exported))
}

pub async fn import_state(
    State(app_state): State<AppState>,
    Json(data): Json<serde_json::Value>,
) -> std::result::Result<StatusCode, StatusCode> {
    // Implementation would restore state from data
    // This is a placeholder
    Ok(StatusCode::OK)
}

pub async fn reset_state(
    State(app_state): State<AppState>,
) -> std::result::Result<StatusCode, StatusCode> {
    let mut state = app_state.state_manager.write().await;
    *state = crate::state::StateManager::new();
    Ok(StatusCode::OK)
}

pub async fn analyze_health(
    State(app_state): State<AppState>,
) -> std::result::Result<Json<AnalysisResponse>, StatusCode> {
    let state = app_state.state_manager.read().await;
    let metrics = state.get_metrics();
    
    let mut insights = Vec::new();
    
    // Generate health insights
    let total = metrics.total_resources.max(1);
    let unhealthy_percentage = (metrics.unhealthy_resources * 100) / total;
    
    if unhealthy_percentage > 20 {
        insights.push(Insight {
            insight_type: "health".to_string(),
            severity: "critical".to_string(),
            message: format!("{}% of resources are unhealthy", unhealthy_percentage),
            recommendation: Some("Investigate failed resources and review logs".to_string()),
        });
    } else if unhealthy_percentage > 10 {
        insights.push(Insight {
            insight_type: "health".to_string(),
            severity: "warning".to_string(),
            message: format!("{}% of resources are unhealthy", unhealthy_percentage),
            recommendation: Some("Monitor resource health trends".to_string()),
        });
    }

    // Check for high event rates
    if metrics.events_last_hour > 100 {
        insights.push(Insight {
            insight_type: "activity".to_string(),
            severity: "warning".to_string(),
            message: format!("High event activity: {} events in the last hour", metrics.events_last_hour),
            recommendation: Some("Review recent events for any concerning patterns".to_string()),
        });
    }

    Ok(Json(AnalysisResponse {
        timestamp: chrono::Utc::now(),
        insights,
        metrics: serde_json::to_value(metrics).unwrap_or_default(),
    }))
}

pub async fn analyze_trends(
    State(app_state): State<AppState>,
) -> std::result::Result<Json<AnalysisResponse>, StatusCode> {
    let state = app_state.state_manager.read().await;
    
    // This would implement trend analysis using Polars
    let insights = vec![
        Insight {
            insight_type: "trend".to_string(),
            severity: "info".to_string(),
            message: "Resource trends analysis completed".to_string(),
            recommendation: None,
        }
    ];
    
    Ok(Json(AnalysisResponse {
        timestamp: chrono::Utc::now(),
        insights,
        metrics: serde_json::json!({}),
    }))
}

pub async fn compliance_report(
    State(app_state): State<AppState>,
) -> std::result::Result<Json<AnalysisResponse>, StatusCode> {
    let state = app_state.state_manager.read().await;
    
    // This would implement compliance checking
    let insights = vec![
        Insight {
            insight_type: "compliance".to_string(),
            severity: "info".to_string(),
            message: "Compliance report generated".to_string(),
            recommendation: None,
        }
    ];
    
    Ok(Json(AnalysisResponse {
        timestamp: chrono::Utc::now(),
        insights,
        metrics: serde_json::json!({}),
    }))
}

pub async fn get_config(
    State(app_state): State<AppState>,
) -> std::result::Result<Json<crate::Config>, StatusCode> {
    Ok(Json((*app_state.config).clone()))
}

pub async fn update_config(
    State(app_state): State<AppState>,
    Json(new_config): Json<crate::Config>,
) -> std::result::Result<StatusCode, StatusCode> {
    // This would update the configuration
    // Implementation depends on how config updates should be handled
    Ok(StatusCode::OK)
}

pub async fn query_data(
    State(app_state): State<AppState>,
    Json(query): Json<DataQuery>,
) -> std::result::Result<Json<serde_json::Value>, StatusCode> {
    // This would implement data querying with Polars
    // For now, return placeholder response
    Ok(Json(serde_json::json!({
        "query": query.query,
        "results": [],
        "timestamp": chrono::Utc::now()
    })))
}

pub async fn aggregate_data(
    State(app_state): State<AppState>,
    Json(query): Json<DataQuery>,
) -> std::result::Result<Json<serde_json::Value>, StatusCode> {
    // This would implement data aggregation with Polars
    // For now, return placeholder response
    Ok(Json(serde_json::json!({
        "aggregation": query.query,
        "results": {},
        "timestamp": chrono::Utc::now()
    })))
}

fn parse_resource_state(state_str: &str) -> Result<ResourceState, ()> {
    match state_str.to_lowercase().as_str() {
        "pending" => Ok(ResourceState::Pending),
        "running" => Ok(ResourceState::Running),
        "succeeded" => Ok(ResourceState::Succeeded),
        "failed" => Ok(ResourceState::Failed),
        "terminating" => Ok(ResourceState::Terminating),
        "unknown" => Ok(ResourceState::Unknown),
        _ => Err(()),
    }
}