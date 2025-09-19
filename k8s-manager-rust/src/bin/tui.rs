use clap::Parser;
use k8s_manager_rust::{Config, AppState};
use tracing_subscriber::{layer::SubscriberExt, util::SubscriberInitExt};

#[derive(Parser)]
#[command(author, version, about, long_about = None)]
struct Args {
    /// Configuration file path
    #[arg(short, long, default_value = "config.toml")]
    config: String,

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
    let config = if std::path::Path::new(&args.config).exists() {
        let content = std::fs::read_to_string(&args.config)?;
        toml::from_str(&content)?
    } else {
        tracing::info!("Config file not found, using defaults");
        Config::default()
    };

    // Create app state
    let app_state = AppState::new(config);

    // Run TUI
    tracing::info!("🎛️ Starting K8s Manager TUI...");
    k8s_manager_rust::tui::run_tui(app_state).await?;

    Ok(())
}