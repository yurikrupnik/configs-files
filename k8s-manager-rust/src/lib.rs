pub mod api;
pub mod config;
pub mod state;
pub mod tui;
pub mod watcher;
pub mod data;
pub mod events;
pub mod error;

pub use config::Config;
pub use error::{Result, K8sManagerError};
pub use state::{StateManager, ResourceState, ResourceEvent};

use std::sync::Arc;
use tokio::sync::RwLock;

#[derive(Clone, Debug)]
pub struct AppState {
    pub state_manager: Arc<RwLock<StateManager>>,
    pub config: Arc<Config>,
}

impl AppState {
    pub fn new(config: Config) -> Self {
        Self {
            state_manager: Arc::new(RwLock::new(StateManager::new())),
            config: Arc::new(config),
        }
    }
}