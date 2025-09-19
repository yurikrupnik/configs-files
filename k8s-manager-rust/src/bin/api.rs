use clap::Parser;
use k8s_manager_rust::{Config, AppState, api::create_app};
use tracing_subscriber::{layer::SubscriberExt, util::SubscriberInitExt};
use std::net::SocketAddr;

#[derive(Parser)]
#[command(author, version, about, long_about = None)]
struct Args {
    /// Configuration file path
    #[arg(short, long, default_value = "config.toml")]
    config: String,

    /// API server host
    #[arg(long, default_value = "0.0.0.0")]
    host: String,

    /// API server port
    #[arg(short, long, default_value = "8080")]
    port: u16,

    /// Log level
    #[arg(short, long, default_value = "info")]
    log_level: String,
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
        Config::default()
    };

    // Override with command line arguments
    config.api.host = args.host.clone();
    config.api.port = args.port;

    // Create app state
    let app_state = AppState::new(config.clone());

    // Create the Axum app
    let app = create_app(app_state);

    // Start the server
    let addr = SocketAddr::from(([0, 0, 0, 0], config.api.port));
    tracing::info!("🚀 Starting K8s Manager API server on {}", addr);
    tracing::info!("📊 Health endpoint: http://{}:{}/health", args.host, args.port);
    tracing::info!("🌐 WebSocket endpoint: ws://{}:{}/ws", args.host, args.port);

    let listener = tokio::net::TcpListener::bind(addr).await?;
    axum::serve(listener, app).await?;

    Ok(())
}