use axum::{
    routing::{get, post, delete},
    Router,
};
use tower::ServiceBuilder;
use tower_http::{cors::CorsLayer, trace::TraceLayer};
use std::sync::Arc;

use crate::AppState;
use super::{handlers, websocket, middleware};

pub fn create_app(app_state: AppState) -> Router {
    Router::new()
        // Health and status endpoints
        .route("/health", get(handlers::health))
        .route("/status", get(handlers::status))
        .route("/metrics", get(handlers::metrics))
        
        // Resource endpoints
        .route("/resources", get(handlers::list_resources))
        .route("/resources/:kind", get(handlers::list_resources_by_kind))
        .route("/resources/:kind/:namespace/:name", get(handlers::get_resource))
        .route("/resources/:kind/:namespace/:name/history", get(handlers::get_resource_history))
        
        // Events endpoints
        .route("/events", get(handlers::list_events))
        .route("/events/recent", get(handlers::recent_events))
        .route("/events", delete(handlers::clear_events))
        
        // State management endpoints
        .route("/state/export", get(handlers::export_state))
        .route("/state/import", post(handlers::import_state))
        .route("/state/reset", post(handlers::reset_state))
        
        // Analysis endpoints
        .route("/analysis/health", get(handlers::analyze_health))
        .route("/analysis/trends", get(handlers::analyze_trends))
        .route("/analysis/compliance", get(handlers::compliance_report))
        
        // WebSocket endpoint
        .route("/ws", get(websocket::websocket_handler))
        
        // Configuration endpoints
        .route("/config", get(handlers::get_config))
        .route("/config", post(handlers::update_config))
        
        // Data processing endpoints
        .route("/data/query", post(handlers::query_data))
        .route("/data/aggregate", post(handlers::aggregate_data))
        
        .layer(
            ServiceBuilder::new()
                .layer(TraceLayer::new_for_http())
                .layer(CorsLayer::permissive())
                .layer(middleware::RequestLoggingLayer)
        )
        .with_state(app_state)
}