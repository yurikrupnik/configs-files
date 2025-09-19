use std::path::PathBuf;
use task_manager::{
    app::App,
    config::Config,
    taskfile::Taskfile,
};

#[tokio::test]
async fn test_app_creation() {
    let result = App::new("Taskfile.yml", None).await;
    assert!(result.is_ok());
    
    let app = result.unwrap();
    assert_eq!(app.taskfile_path, PathBuf::from("Taskfile.yml"));
    assert!(!app.taskfile.tasks.is_empty());
}

#[tokio::test]
async fn test_taskfile_loading() {
    let result = Taskfile::load("Taskfile.yml");
    assert!(result.is_ok());
    
    let taskfile = result.unwrap();
    assert_eq!(taskfile.version, "3");
    assert!(taskfile.tasks.contains_key("default"));
    assert!(taskfile.tasks.contains_key("build"));
}

#[tokio::test]
async fn test_config_creation() {
    let config = Config::default();
    assert_eq!(config.default_taskfile, "Taskfile.yml");
    assert_eq!(config.editor, "nvim");
    assert!(config.auto_save);
}

fn main() {
    println!("Task Manager functionality tests would run here.");
    println!("In a real test environment, run with: cargo test");
}