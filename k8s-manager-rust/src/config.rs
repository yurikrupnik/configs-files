use serde::{Deserialize, Serialize};
use std::collections::HashMap;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Config {
    pub watcher: WatcherConfig,
    pub api: ApiConfig,
    pub tui: TuiConfig,
    pub data: DataConfig,
    pub events: EventConfig,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct WatcherConfig {
    pub namespaces: Vec<String>,
    pub resource_types: Vec<String>,
    pub reconnect_interval: u64,
    pub label_selectors: HashMap<String, String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ApiConfig {
    pub host: String,
    pub port: u16,
    pub cors_origins: Vec<String>,
    pub websocket_path: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TuiConfig {
    pub refresh_rate: u64,
    pub show_timestamps: bool,
    pub max_events: usize,
    pub theme: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DataConfig {
    pub storage_path: String,
    pub retention_days: u32,
    pub batch_size: usize,
    pub compression: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct EventConfig {
    pub webhook_urls: Vec<String>,
    pub slack_webhook: Option<String>,
    pub filter_severity: String,
    pub enable_metrics: bool,
}

impl Default for Config {
    fn default() -> Self {
        Self {
            watcher: WatcherConfig {
                namespaces: vec!["default".to_string()],
                resource_types: vec![
                    "pods".to_string(),
                    "services".to_string(),
                    "deployments".to_string(),
                    "configmaps".to_string(),
                    "secrets".to_string(),
                ],
                reconnect_interval: 5000,
                label_selectors: HashMap::new(),
            },
            api: ApiConfig {
                host: "0.0.0.0".to_string(),
                port: 8080,
                cors_origins: vec!["*".to_string()],
                websocket_path: "/ws".to_string(),
            },
            tui: TuiConfig {
                refresh_rate: 1000,
                show_timestamps: true,
                max_events: 1000,
                theme: "dark".to_string(),
            },
            data: DataConfig {
                storage_path: "./data".to_string(),
                retention_days: 7,
                batch_size: 100,
                compression: true,
            },
            events: EventConfig {
                webhook_urls: vec![],
                slack_webhook: None,
                filter_severity: "info".to_string(),
                enable_metrics: true,
            },
        }
    }
}

impl Config {
    pub fn load() -> crate::Result<Self> {
        let settings = config::Config::builder()
            .add_source(config::File::with_name("config").required(false))
            .add_source(config::Environment::with_prefix("K8S_MANAGER"))
            .build()?;

        let config = settings.try_deserialize().unwrap_or_default();
        Ok(config)
    }

    pub fn save(&self, path: &str) -> crate::Result<()> {
        let toml_string = toml::to_string_pretty(self)?;
        std::fs::write(path, toml_string)?;
        Ok(())
    }
}