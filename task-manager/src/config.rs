use anyhow::{Context, Result};
use serde::{Deserialize, Serialize};
use std::fs;
use std::path::{Path, PathBuf};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Config {
    pub default_taskfile: String,
    pub editor: String,
    pub theme: Theme,
    pub keybindings: Keybindings,
    pub auto_save: bool,
    pub backup_enabled: bool,
    pub backup_dir: String,
    pub kcl_schema_path: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Theme {
    pub primary_color: String,
    pub secondary_color: String,
    pub error_color: String,
    pub success_color: String,
    pub warning_color: String,
    pub background: String,
    pub foreground: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Keybindings {
    pub quit: String,
    pub save: String,
    pub new_task: String,
    pub edit_task: String,
    pub delete_task: String,
    pub run_task: String,
    pub toggle_help: String,
    pub navigate_up: String,
    pub navigate_down: String,
    pub navigate_left: String,
    pub navigate_right: String,
    pub validate: String,
    pub search: String,
    pub reload: String,
}

impl Default for Config {
    fn default() -> Self {
        Self {
            default_taskfile: "Taskfile.yml".to_string(),
            editor: "nvim".to_string(),
            theme: Theme::default(),
            keybindings: Keybindings::default(),
            auto_save: true,
            backup_enabled: true,
            backup_dir: ".task-backups".to_string(),
            kcl_schema_path: "schemas/taskfile.k".to_string(),
        }
    }
}

impl Default for Theme {
    fn default() -> Self {
        Self {
            primary_color: "blue".to_string(),
            secondary_color: "cyan".to_string(),
            error_color: "red".to_string(),
            success_color: "green".to_string(),
            warning_color: "yellow".to_string(),
            background: "black".to_string(),
            foreground: "white".to_string(),
        }
    }
}

impl Default for Keybindings {
    fn default() -> Self {
        Self {
            quit: "q".to_string(),
            save: "s".to_string(),
            new_task: "n".to_string(),
            edit_task: "e".to_string(),
            delete_task: "d".to_string(),
            run_task: "r".to_string(),
            toggle_help: "?".to_string(),
            navigate_up: "k".to_string(),
            navigate_down: "j".to_string(),
            navigate_left: "h".to_string(),
            navigate_right: "l".to_string(),
            validate: "v".to_string(),
            search: "/".to_string(),
            reload: "R".to_string(),
        }
    }
}

impl Config {
    pub fn load<P: AsRef<Path>>(path: P) -> Result<Self> {
        let content = fs::read_to_string(&path)
            .with_context(|| format!("Failed to read config file: {}", path.as_ref().display()))?;
        
        let config: Config = serde_yaml::from_str(&content)
            .with_context(|| format!("Failed to parse config file: {}", path.as_ref().display()))?;
        
        Ok(config)
    }
    
    pub fn save<P: AsRef<Path>>(&self, path: P) -> Result<()> {
        if let Some(parent) = path.as_ref().parent() {
            fs::create_dir_all(parent)
                .with_context(|| format!("Failed to create config directory: {}", parent.display()))?;
        }
        
        let content = serde_yaml::to_string(self)
            .context("Failed to serialize config")?;
        
        fs::write(&path, content)
            .with_context(|| format!("Failed to write config file: {}", path.as_ref().display()))?;
        
        Ok(())
    }
    
    pub fn default_path() -> Result<PathBuf> {
        let config_dir = dirs::config_dir()
            .context("Failed to get config directory")?
            .join("task-manager");
        
        Ok(config_dir.join("config.yml"))
    }
    
    pub fn load_or_default() -> Result<Self> {
        let config_path = Self::default_path()?;
        
        if config_path.exists() {
            Self::load(&config_path)
        } else {
            let config = Self::default();
            config.save(&config_path)?;
            Ok(config)
        }
    }
}