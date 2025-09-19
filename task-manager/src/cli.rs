use anyhow::{Context, Result};
use std::process::Command;
use tokio::process::Command as TokioCommand;

pub struct Cli;

impl Cli {
    pub async fn run_task(task_name: &str, taskfile_path: &str) -> Result<()> {
        let output = TokioCommand::new("task")
            .arg("-t")
            .arg(taskfile_path)
            .arg(task_name)
            .output()
            .await
            .context("Failed to execute task command")?;
        
        if !output.status.success() {
            let stderr = String::from_utf8_lossy(&output.stderr);
            anyhow::bail!("Task execution failed: {task_name} {}", stderr);
        }
        
        Ok(())
    }
    
    pub async fn list_tasks(taskfile_path: &str) -> Result<Vec<String>> {
        let output = TokioCommand::new("task")
            .arg("-t")
            .arg(taskfile_path)
            .arg("--list")
            .output()
            .await
            .context("Failed to list tasks")?;
        
        if !output.status.success() {
            let stderr = String::from_utf8_lossy(&output.stderr);
            anyhow::bail!("Failed to list tasks: {}", stderr);
        }
        
        let stdout = String::from_utf8_lossy(&output.stdout);
        let tasks: Vec<String> = stdout
            .lines()
            .skip(1)
            .filter_map(|line| {
                let trimmed = line.trim();
                if trimmed.starts_with("*") {
                    let parts: Vec<&str> = trimmed.splitn(2, ' ').collect();
                    if parts.len() >= 2 {
                        Some(parts[1].split(':').next().unwrap_or("").trim().to_string())
                    } else {
                        None
                    }
                } else {
                    None
                }
            })
            .filter(|task| !task.is_empty())
            .collect();
        
        Ok(tasks)
    }
    
    pub fn check_task_available() -> bool {
        Command::new("task")
            .arg("--version")
            .output()
            .map(|output| output.status.success())
            .unwrap_or(false)
    }
    
    pub async fn validate_taskfile(taskfile_path: &str) -> Result<bool> {
        let output = TokioCommand::new("task")
            .arg("-t")
            .arg(taskfile_path)
            .arg("--dry")
            .arg("--list")
            .output()
            .await
            .context("Failed to validate taskfile")?;
        
        Ok(output.status.success())
    }
}