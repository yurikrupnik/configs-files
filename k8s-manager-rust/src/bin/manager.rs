use clap::Parser;
use k8s_manager_rust::{Config, AppState, watcher::K8sWatcher, data::DataProcessor, events::EventEmitter};
use tracing_subscriber::{layer::SubscriberExt, util::SubscriberInitExt};
use std::sync::Arc;
use tokio::signal;

#[derive(Parser)]
#[command(author, version, about, long_about = None)]
struct Args {
    /// Configuration file path
    #[arg(short, long, default_value = "config.toml")]
    config: String,

    /// Enable TUI mode
    #[arg(long)]
    tui: bool,

    /// Enable API server
    #[arg(long)]
    api: bool,

    /// Log level
    #[arg(short, long, default_value = "info")]
    log_level: String,

    /// Data directory for storage
    #[arg(short, long)]
    data_dir: Option<String>,
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let args = Args::parse();

    // Initialize logging
    tracing_subscriber::registry()
        .with(
            tracing_subscriber::EnvFilter::try_from_default_env()
                .unwrap_or_else(|_| format!("k8s_manager_rust={}", args.log_level).into()),
        )
        .with(tracing_subscriber::fmt::layer())
        .init();

    // Load configuration
    let mut config = if std::path::Path::new(&args.config).exists() {
        let content = std::fs::read_to_string(&args.config)?;
        toml::from_str(&content)?
    } else {
        tracing::info!("Config file not found, using defaults");
        let config = Config::default();
        // Save default config
        config.save(&args.config)?;
        tracing::info!("Default configuration saved to {}", args.config);
        config
    };

    // Override data directory if provided
    if let Some(data_dir) = args.data_dir {
        config.data.storage_path = data_dir;
    }

    // Create app state
    let app_state = AppState::new(config.clone());

    // Initialize components
    let watcher = Arc::new(K8sWatcher::new(config.clone()).await?);
    let mut data_processor = DataProcessor::new(
        config.data.storage_path.clone(),
        config.data.batch_size,
    );
    let mut event_emitter = EventEmitter::new(
        config.events.webhook_urls.clone(),
        config.events.slack_webhook.clone(),
        config.events.filter_severity.clone(),
    );

    tracing::info!("🎛️ Starting K8s Manager...");
    tracing::info!("📁 Data storage: {}", config.data.storage_path);
    tracing::info!("👀 Watching namespaces: {:?}", config.watcher.namespaces);
    tracing::info!("🔧 Resource types: {:?}", config.watcher.resource_types);

    // Start components based on flags
    let mut tasks = Vec::new();

    // Always start the watcher and data processing
    let watcher_clone = watcher.clone();
    let app_state_clone = app_state.clone();
    tasks.push(tokio::spawn(async move {
        if let Err(e) = watcher_clone.start(app_state_clone).await {
            tracing::error!("Watcher failed: {}", e);
        }
    }));

    // Event processing task
    let app_state_clone = app_state.clone();
    let mut event_receiver = watcher.subscribe();
    let mut data_processor_task = data_processor.clone();
    let mut event_emitter_task = event_emitter.clone();
    tasks.push(tokio::spawn(async move {
        while let Ok(event) = event_receiver.recv().await {
            // Process event with data processor
            data_processor_task.add_event(event.clone());

            // Get current resource state
            let machine = {
                let state = app_state_clone.state_manager.read().await;
                let key = format!(
                    "{}/{}/{}",
                    event.resource.kind,
                    event.resource.namespace.as_deref().unwrap_or("default"),
                    event.resource.name
                );
                state.get_resource(&key).cloned()
            };

            // Emit event
            let metrics = {
                let state = app_state_clone.state_manager.read().await;
                state.get_metrics().clone()
            };

            if let Err(e) = event_emitter_task.emit_resource_event(event, machine.as_ref(), &metrics).await {
                tracing::error!("Failed to emit event: {}", e);
            }
        }
    }));

    // Periodic tasks
    let app_state_clone = app_state.clone();
    let mut event_emitter_clone = event_emitter.clone();
    tasks.push(tokio::spawn(async move {
        let mut interval = tokio::time::interval(tokio::time::Duration::from_secs(60));
        loop {
            interval.tick().await;
            
            // Emit metrics update
            let metrics = {
                let state = app_state_clone.state_manager.read().await;
                state.get_metrics().clone()
            };
            
            if let Err(e) = event_emitter_clone.emit_metrics_update(&metrics).await {
                tracing::error!("Failed to emit metrics: {}", e);
            }
        }
    }));

    // Data cleanup task
    let data_processor_clone = data_processor.clone();
    let retention_days = config.data.retention_days;
    tasks.push(tokio::spawn(async move {
        let mut interval = tokio::time::interval(tokio::time::Duration::from_secs(24 * 60 * 60)); // Daily
        loop {
            interval.tick().await;
            
            match data_processor_clone.cleanup_old_data(retention_days) {
                Ok(deleted) => {
                    if deleted > 0 {
                        tracing::info!("Cleaned up {} old data files", deleted);
                    }
                }
                Err(e) => {
                    tracing::error!("Failed to cleanup old data: {}", e);
                }
            }
        }
    }));

    // Start API server if requested
    if args.api {
        let app_state_clone = app_state.clone();
        let config_clone = config.clone();
        tasks.push(tokio::spawn(async move {
            let app = k8s_manager_rust::api::create_app(app_state_clone);
            let addr = std::net::SocketAddr::from(([0, 0, 0, 0], config_clone.api.port));
            
            tracing::info!("🌐 Starting API server on {}", addr);
            
            let listener = tokio::net::TcpListener::bind(addr).await.unwrap();
            if let Err(e) = axum::serve(listener, app).await {
                tracing::error!("API server failed: {}", e);
            }
        }));
    }

    // Start TUI if requested
    if args.tui {
        let app_state_clone = app_state.clone();
        tasks.push(tokio::spawn(async move {
            if let Err(e) = k8s_manager_rust::tui::run_tui(app_state_clone).await {
                tracing::error!("TUI failed: {}", e);
            }
        }));
    }

    // Wait for shutdown signal
    let shutdown_task = tokio::spawn(async {
        signal::ctrl_c().await.expect("Failed to listen for ctrl+c");
        tracing::info!("Received shutdown signal");
    });

    // Wait for either shutdown signal or any task to complete
    tokio::select! {
        _ = shutdown_task => {
            tracing::info!("🛑 Shutting down K8s Manager...");
        }
        result = futures::future::select_all(tasks) => {
            match result.0 {
                Ok(_) => tracing::info!("A task completed"),
                Err(e) => tracing::error!("A task failed: {}", e),
            }
        }
    }

    // Flush any remaining data
    if let Err(e) = data_processor.flush_events() {
        tracing::error!("Failed to flush final events: {}", e);
    }

    tracing::info!("✅ K8s Manager shutdown complete");
    Ok(())
}

