use anyhow::{Context, Result};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::fs;
use std::path::Path;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Taskfile {
    pub version: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub output: Option<Output>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub method: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub includes: Option<HashMap<String, Include>>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub vars: Option<HashMap<String, serde_yaml::Value>>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub env: Option<HashMap<String, serde_yaml::Value>>,
    pub tasks: HashMap<String, Task>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub silent: Option<bool>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub dotenv: Option<Vec<String>>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub run: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub interval: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(untagged)]
pub enum Output {
    String(String),
    Object(OutputObject),
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct OutputObject {
    #[serde(skip_serializing_if = "Option::is_none")]
    pub group: Option<GroupOutput>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct GroupOutput {
    #[serde(skip_serializing_if = "Option::is_none")]
    pub begin: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub end: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub error_only: Option<bool>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(untagged)]
pub enum Include {
    String(String),
    Object(IncludeObject),
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct IncludeObject {
    pub taskfile: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub dir: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub optional: Option<bool>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub flatten: Option<bool>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub internal: Option<bool>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub aliases: Option<Vec<String>>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub excludes: Option<Vec<String>>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub vars: Option<HashMap<String, serde_yaml::Value>>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub checksum: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(untagged)]
pub enum Task {
    String(String),
    Commands(Vec<TaskCommand>),
    Object(TaskObject),
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TaskObject {
    #[serde(skip_serializing_if = "Option::is_none")]
    pub cmds: Option<Vec<TaskCommand>>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub cmd: Option<Box<TaskCommand>>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub deps: Option<Vec<TaskDep>>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub label: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub desc: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub prompt: Option<TaskPrompt>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub summary: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub aliases: Option<Vec<String>>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub sources: Option<Vec<String>>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub generates: Option<Vec<String>>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub status: Option<Vec<String>>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub preconditions: Option<Vec<Precondition>>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub dir: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub vars: Option<HashMap<String, serde_yaml::Value>>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub env: Option<HashMap<String, serde_yaml::Value>>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub dotenv: Option<Vec<String>>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub silent: Option<bool>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub interactive: Option<bool>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub internal: Option<bool>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub method: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub prefix: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub ignore_error: Option<bool>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub run: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub platforms: Option<Vec<String>>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub requires: Option<RequiresObject>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub watch: Option<bool>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(untagged)]
pub enum TaskPrompt {
    String(String),
    Array(Vec<String>),
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(untagged)]
pub enum TaskCommand {
    String(String),
    CmdCall(CmdCall),
    TaskCall(TaskCall),
    DeferTaskCall(DeferTaskCall),
    DeferCmdCall(DeferCmdCall),
    ForCmdsCall(ForCmdsCall),
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CmdCall {
    pub cmd: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub silent: Option<bool>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub ignore_error: Option<bool>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub platforms: Option<Vec<String>>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct TaskCall {
    pub task: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub vars: Option<HashMap<String, serde_yaml::Value>>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub silent: Option<bool>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DeferTaskCall {
    pub defer: TaskCall,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DeferCmdCall {
    pub defer: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub silent: Option<bool>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ForCmdsCall {
    #[serde(rename = "for")]
    pub for_: serde_yaml::Value,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub cmd: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub task: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub vars: Option<HashMap<String, serde_yaml::Value>>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub silent: Option<bool>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub platforms: Option<Vec<String>>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(untagged)]
pub enum TaskDep {
    String(String),
    TaskCall(TaskCall),
    ForDepsCall(ForDepsCall),
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ForDepsCall {
    #[serde(rename = "for")]
    pub for_: serde_yaml::Value,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub task: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub vars: Option<HashMap<String, serde_yaml::Value>>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub silent: Option<bool>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(untagged)]
pub enum Precondition {
    String(String),
    Object(PreconditionObject),
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PreconditionObject {
    pub sh: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub msg: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RequiresObject {
    #[serde(skip_serializing_if = "Option::is_none")]
    pub vars: Option<Vec<RequiredVar>>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(untagged)]
pub enum RequiredVar {
    String(String),
    Object(RequiredVarObject),
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RequiredVarObject {
    pub name: String,
    #[serde(rename = "enum")]
    pub enum_: Vec<String>,
}

impl Taskfile {
    pub fn load<P: AsRef<Path>>(path: P) -> Result<Self> {
        let content = fs::read_to_string(&path)
            .with_context(|| format!("Failed to read taskfile: {}", path.as_ref().display()))?;
        
        let taskfile: Taskfile = serde_yaml::from_str(&content)
            .with_context(|| format!("Failed to parse taskfile: {}", path.as_ref().display()))?;
        
        Ok(taskfile)
    }
    
    pub fn save<P: AsRef<Path>>(&self, path: P) -> Result<()> {
        let content = serde_yaml::to_string(self)
            .context("Failed to serialize taskfile")?;
        
        fs::write(&path, content)
            .with_context(|| format!("Failed to write taskfile: {}", path.as_ref().display()))?;
        
        Ok(())
    }
    
    pub fn add_task(&mut self, name: String, task: Task) {
        self.tasks.insert(name, task);
    }
    
    pub fn remove_task(&mut self, name: &str) -> Option<Task> {
        self.tasks.remove(name)
    }
    
    pub fn get_task(&self, name: &str) -> Option<&Task> {
        self.tasks.get(name)
    }
    
    pub fn get_task_mut(&mut self, name: &str) -> Option<&mut Task> {
        self.tasks.get_mut(name)
    }
    
    pub fn task_names(&self) -> Vec<&String> {
        self.tasks.keys().collect()
    }
}

impl TaskObject {
    pub fn new() -> Self {
        Self {
            cmds: None,
            cmd: None,
            deps: None,
            label: None,
            desc: None,
            prompt: None,
            summary: None,
            aliases: None,
            sources: None,
            generates: None,
            status: None,
            preconditions: None,
            dir: None,
            vars: None,
            env: None,
            dotenv: None,
            silent: None,
            interactive: None,
            internal: None,
            method: None,
            prefix: None,
            ignore_error: None,
            run: None,
            platforms: None,
            requires: None,
            watch: None,
        }
    }
}