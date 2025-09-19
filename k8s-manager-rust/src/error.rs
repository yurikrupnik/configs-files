use thiserror::Error;

pub type Result<T> = std::result::Result<T, K8sManagerError>;

#[derive(Error, Debug)]
pub enum K8sManagerError {
    #[error("Kubernetes API error: {0}")]
    Kube(#[from] kube::Error),
    
    #[error("Serialization error: {0}")]
    Serde(#[from] serde_json::Error),
    
    #[error("IO error: {0}")]
    Io(#[from] std::io::Error),
    
    #[error("Configuration error: {0}")]
    Config(#[from] config::ConfigError),
    
    #[error("Polars error: {0}")]
    Polars(#[from] polars::error::PolarsError),
    
    #[error("WebSocket error: {0}")]
    WebSocket(#[from] tungstenite::Error),
    
    #[error("TOML serialization error: {0}")]
    TomlSer(#[from] toml::ser::Error),
    
    #[error("Kubernetes watcher error: {0}")]
    KubeWatcher(#[from] kube::runtime::watcher::Error),
    
    #[error("TUI error: {0}")]
    Tui(String),
    
    #[error("Resource not found: {0}")]
    ResourceNotFound(String),
    
    #[error("Invalid state transition: {from} -> {to}")]
    InvalidStateTransition { from: String, to: String },
    
    #[error("Connection error: {0}")]
    Connection(String),
}