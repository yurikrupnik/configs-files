use anyhow::{Context, Result};
use std::path::Path;
use std::process::Command;
use tokio::process::Command as TokioCommand;

#[derive(Debug, Clone)]
pub struct ValidationResult {
    pub is_valid: bool,
    pub errors: Vec<ValidationError>,
    pub warnings: Vec<ValidationWarning>,
}

#[derive(Debug, Clone)]
pub struct ValidationError {
    pub message: String,
    pub line: Option<usize>,
    pub column: Option<usize>,
    pub path: Option<String>,
}

#[derive(Debug, Clone)]
pub struct ValidationWarning {
    pub message: String,
    pub line: Option<usize>,
    pub column: Option<usize>,
    pub path: Option<String>,
}

pub struct KclValidator {
    schema_path: String,
}

impl KclValidator {
    pub fn new(schema_path: String) -> Self {
        Self { schema_path }
    }
    
    pub async fn validate_file<P: AsRef<Path>>(&self, taskfile_path: P) -> Result<ValidationResult> {
        let taskfile_path = taskfile_path.as_ref();
        
        if !Path::new(&self.schema_path).exists() {
            return Ok(ValidationResult {
                is_valid: false,
                errors: vec![ValidationError {
                    message: format!("KCL schema file not found: {}", self.schema_path),
                    line: None,
                    column: None,
                    path: None,
                }],
                warnings: vec![],
            });
        }
        
        let temp_file = format!("/tmp/validate-{}.k", uuid::Uuid::new_v4());
        let validate_content = format!(
            r#"import file
import yaml
import {} as taskfile

taskfile_data = yaml.decode(file.read("{}"))
validated_taskfile: taskfile.Taskfile = taskfile_data"#,
            self.schema_path.replace(".k", "").replace("/", "."),
            taskfile_path.to_string_lossy()
        );
        
        tokio::fs::write(&temp_file, validate_content)
            .await
            .context("Failed to write temp validation file")?;
        
        let output = TokioCommand::new("kcl")
            .arg("run")
            .arg(&temp_file)
            .output()
            .await
            .context("Failed to execute kcl command")?;
        
        let _ = tokio::fs::remove_file(&temp_file).await;
        
        if output.status.success() {
            Ok(ValidationResult {
                is_valid: true,
                errors: vec![],
                warnings: vec![],
            })
        } else {
            let stderr = String::from_utf8_lossy(&output.stderr);
            let errors = self.parse_kcl_errors(&stderr);
            
            Ok(ValidationResult {
                is_valid: false,
                errors,
                warnings: vec![],
            })
        }
    }
    
    pub async fn validate_content(&self, content: &str) -> Result<ValidationResult> {
        use tokio::fs;
        
        let temp_file = format!("/tmp/taskfile-{}.yml", uuid::Uuid::new_v4());
        
        fs::write(&temp_file, content)
            .await
            .context("Failed to write temporary taskfile")?;
        
        let result = self.validate_file(&temp_file).await;
        
        let _ = fs::remove_file(&temp_file).await;
        
        result
    }
    
    pub fn check_kcl_available() -> bool {
        Command::new("kcl")
            .arg("--version")
            .output()
            .map(|output| output.status.success())
            .unwrap_or(false)
    }
    
    fn parse_kcl_errors(&self, stderr: &str) -> Vec<ValidationError> {
        let mut errors = vec![];
        
        for line in stderr.lines() {
            if line.trim().is_empty() {
                continue;
            }
            
            let parts: Vec<&str> = line.split(':').collect();
            if parts.len() >= 2 {
                let message = parts[1..].join(":").trim().to_string();
                
                let (line_num, column_num) = if parts.len() >= 3 {
                    let location = parts[0];
                    let coords: Vec<&str> = location.split(',').collect();
                    if coords.len() == 2 {
                        let line = coords[0].parse().ok();
                        let column = coords[1].parse().ok();
                        (line, column)
                    } else {
                        (None, None)
                    }
                } else {
                    (None, None)
                };
                
                errors.push(ValidationError {
                    message,
                    line: line_num,
                    column: column_num,
                    path: None,
                });
            } else {
                errors.push(ValidationError {
                    message: line.to_string(),
                    line: None,
                    column: None,
                    path: None,
                });
            }
        }
        
        if errors.is_empty() && !stderr.trim().is_empty() {
            errors.push(ValidationError {
                message: stderr.to_string(),
                line: None,
                column: None,
                path: None,
            });
        }
        
        errors
    }
}

impl ValidationResult {
    pub fn success() -> Self {
        Self {
            is_valid: true,
            errors: vec![],
            warnings: vec![],
        }
    }
    
    pub fn error(message: String) -> Self {
        Self {
            is_valid: false,
            errors: vec![ValidationError {
                message,
                line: None,
                column: None,
                path: None,
            }],
            warnings: vec![],
        }
    }
}