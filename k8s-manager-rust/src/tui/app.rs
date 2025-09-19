use crate::{AppState, ResourceState, Result};
use super::events::Event;
use crossterm::event::{KeyCode, KeyEvent};
use std::collections::HashMap;
use tokio::sync::mpsc::UnboundedSender;

#[derive(Debug, Clone, Copy, PartialEq)]
pub enum TabIndex {
    Overview,
    Resources,
    Events,
    Metrics,
    Settings,
}

#[derive(Debug, Clone, Copy, PartialEq)]
pub enum ResourceTab {
    All,
    Pods,
    Services,
    Deployments,
    ConfigMaps,
    Secrets,
}

#[derive(Debug)]
pub struct App {
    pub app_state: AppState,
    pub should_quit: bool,
    pub current_tab: TabIndex,
    pub resource_tab: ResourceTab,
    pub selected_resource: Option<String>,
    pub event_sender: UnboundedSender<Event>,
    pub scroll_offset: usize,
    pub filter_namespace: Option<String>,
    pub filter_state: Option<ResourceState>,
    pub show_help: bool,
    pub input_mode: InputMode,
    pub input_buffer: String,
    pub status_message: Option<String>,
}

#[derive(Debug, Clone, Copy, PartialEq)]
pub enum InputMode {
    Normal,
    Filtering,
    Command,
}

impl App {
    pub async fn new(app_state: AppState, event_sender: UnboundedSender<Event>) -> Self {
        Self {
            app_state,
            should_quit: false,
            current_tab: TabIndex::Overview,
            resource_tab: ResourceTab::All,
            selected_resource: None,
            event_sender,
            scroll_offset: 0,
            filter_namespace: None,
            filter_state: None,
            show_help: false,
            input_mode: InputMode::Normal,
            input_buffer: String::new(),
            status_message: None,
        }
    }

    pub fn should_quit(&self) -> bool {
        self.should_quit
    }

    pub async fn handle_event(&mut self, event: Event) -> Result<()> {
        match event {
            Event::Key(key) => self.handle_key_event(key).await?,
            Event::Tick => self.handle_tick().await?,
            Event::Resize(_, _) => {
                // Handle resize if needed
            }
        }
        Ok(())
    }

    async fn handle_key_event(&mut self, key: KeyEvent) -> Result<()> {
        match self.input_mode {
            InputMode::Normal => self.handle_normal_mode(key).await?,
            InputMode::Filtering => self.handle_filter_mode(key).await?,
            InputMode::Command => self.handle_command_mode(key).await?,
        }
        Ok(())
    }

    async fn handle_normal_mode(&mut self, key: KeyEvent) -> Result<()> {
        match key.code {
            KeyCode::Char('q') | KeyCode::Esc => {
                if self.show_help {
                    self.show_help = false;
                } else {
                    self.should_quit = true;
                }
            }
            KeyCode::Char('h') | KeyCode::F(1) => {
                self.show_help = !self.show_help;
            }
            KeyCode::Tab => {
                self.next_tab();
            }
            KeyCode::BackTab => {
                self.prev_tab();
            }
            KeyCode::Char('1') => self.current_tab = TabIndex::Overview,
            KeyCode::Char('2') => self.current_tab = TabIndex::Resources,
            KeyCode::Char('3') => self.current_tab = TabIndex::Events,
            KeyCode::Char('4') => self.current_tab = TabIndex::Metrics,
            KeyCode::Char('5') => self.current_tab = TabIndex::Settings,
            KeyCode::Up | KeyCode::Char('k') => {
                self.scroll_up();
            }
            KeyCode::Down | KeyCode::Char('j') => {
                self.scroll_down().await;
            }
            KeyCode::Left | KeyCode::Char('n') => {
                if self.current_tab == TabIndex::Resources {
                    self.prev_resource_tab();
                }
            }
            KeyCode::Right | KeyCode::Char('m') => {
                if self.current_tab == TabIndex::Resources {
                    self.next_resource_tab();
                }
            }
            KeyCode::Enter => {
                self.select_current_item().await?;
            }
            KeyCode::Char('f') => {
                self.input_mode = InputMode::Filtering;
                self.input_buffer.clear();
                self.status_message = Some("Filter: ".to_string());
            }
            KeyCode::Char(':') => {
                self.input_mode = InputMode::Command;
                self.input_buffer.clear();
                self.status_message = Some(":".to_string());
            }
            KeyCode::Char('r') => {
                self.refresh_data().await?;
            }
            KeyCode::Char('c') => {
                if self.current_tab == TabIndex::Events {
                    self.clear_events().await?;
                }
            }
            KeyCode::Char('d') => {
                if let Some(resource_key) = &self.selected_resource.clone() {
                    self.show_resource_details(resource_key).await?;
                }
            }
            _ => {}
        }
        Ok(())
    }

    async fn handle_filter_mode(&mut self, key: KeyEvent) -> Result<()> {
        match key.code {
            KeyCode::Enter => {
                self.apply_filter().await?;
                self.input_mode = InputMode::Normal;
                self.status_message = None;
            }
            KeyCode::Esc => {
                self.input_mode = InputMode::Normal;
                self.input_buffer.clear();
                self.status_message = None;
            }
            KeyCode::Backspace => {
                self.input_buffer.pop();
                self.status_message = Some(format!("Filter: {}", self.input_buffer));
            }
            KeyCode::Char(c) => {
                self.input_buffer.push(c);
                self.status_message = Some(format!("Filter: {}", self.input_buffer));
            }
            _ => {}
        }
        Ok(())
    }

    async fn handle_command_mode(&mut self, key: KeyEvent) -> Result<()> {
        match key.code {
            KeyCode::Enter => {
                self.execute_command().await?;
                self.input_mode = InputMode::Normal;
                self.status_message = None;
            }
            KeyCode::Esc => {
                self.input_mode = InputMode::Normal;
                self.input_buffer.clear();
                self.status_message = None;
            }
            KeyCode::Backspace => {
                self.input_buffer.pop();
                self.status_message = Some(format!(":{}", self.input_buffer));
            }
            KeyCode::Char(c) => {
                self.input_buffer.push(c);
                self.status_message = Some(format!(":{}", self.input_buffer));
            }
            _ => {}
        }
        Ok(())
    }

    async fn handle_tick(&mut self) -> Result<()> {
        // Periodic updates can be handled here
        Ok(())
    }

    fn next_tab(&mut self) {
        self.current_tab = match self.current_tab {
            TabIndex::Overview => TabIndex::Resources,
            TabIndex::Resources => TabIndex::Events,
            TabIndex::Events => TabIndex::Metrics,
            TabIndex::Metrics => TabIndex::Settings,
            TabIndex::Settings => TabIndex::Overview,
        };
    }

    fn prev_tab(&mut self) {
        self.current_tab = match self.current_tab {
            TabIndex::Overview => TabIndex::Settings,
            TabIndex::Resources => TabIndex::Overview,
            TabIndex::Events => TabIndex::Resources,
            TabIndex::Metrics => TabIndex::Events,
            TabIndex::Settings => TabIndex::Metrics,
        };
    }

    fn next_resource_tab(&mut self) {
        self.resource_tab = match self.resource_tab {
            ResourceTab::All => ResourceTab::Pods,
            ResourceTab::Pods => ResourceTab::Services,
            ResourceTab::Services => ResourceTab::Deployments,
            ResourceTab::Deployments => ResourceTab::ConfigMaps,
            ResourceTab::ConfigMaps => ResourceTab::Secrets,
            ResourceTab::Secrets => ResourceTab::All,
        };
    }

    fn prev_resource_tab(&mut self) {
        self.resource_tab = match self.resource_tab {
            ResourceTab::All => ResourceTab::Secrets,
            ResourceTab::Pods => ResourceTab::All,
            ResourceTab::Services => ResourceTab::Pods,
            ResourceTab::Deployments => ResourceTab::Services,
            ResourceTab::ConfigMaps => ResourceTab::Deployments,
            ResourceTab::Secrets => ResourceTab::ConfigMaps,
        };
    }

    fn scroll_up(&mut self) {
        if self.scroll_offset > 0 {
            self.scroll_offset -= 1;
        }
    }

    async fn scroll_down(&mut self) {
        let max_items = self.get_current_items_count().await;
        if self.scroll_offset + 20 < max_items {
            self.scroll_offset += 1;
        }
    }

    async fn get_current_items_count(&self) -> usize {
        let state = self.app_state.state_manager.read().await;
        match self.current_tab {
            TabIndex::Resources => state.resources.len(),
            TabIndex::Events => state.events.len(),
            _ => 0,
        }
    }

    async fn select_current_item(&mut self) -> Result<()> {
        match self.current_tab {
            TabIndex::Resources => {
                let state = self.app_state.state_manager.read().await;
                let resources: Vec<_> = state.resources.keys().collect();
                if let Some(key) = resources.get(self.scroll_offset) {
                    self.selected_resource = Some((*key).clone());
                    self.status_message = Some(format!("Selected: {}", key));
                }
            }
            _ => {}
        }
        Ok(())
    }

    async fn apply_filter(&mut self) -> Result<()> {
        if self.input_buffer.starts_with("ns:") {
            let namespace = self.input_buffer.strip_prefix("ns:").unwrap().to_string();
            self.filter_namespace = if namespace.is_empty() { None } else { Some(namespace) };
        } else if self.input_buffer.starts_with("state:") {
            let state_str = self.input_buffer.strip_prefix("state:").unwrap();
            self.filter_state = match state_str.to_lowercase().as_str() {
                "pending" => Some(ResourceState::Pending),
                "running" => Some(ResourceState::Running),
                "succeeded" => Some(ResourceState::Succeeded),
                "failed" => Some(ResourceState::Failed),
                "terminating" => Some(ResourceState::Terminating),
                "unknown" => Some(ResourceState::Unknown),
                _ => None,
            };
        }

        self.input_buffer.clear();
        self.scroll_offset = 0;
        self.status_message = Some("Filter applied".to_string());
        Ok(())
    }

    async fn execute_command(&mut self) -> Result<()> {
        let command = self.input_buffer.trim();
        match command {
            "quit" | "q" => self.should_quit = true,
            "clear" => self.clear_events().await?,
            "refresh" | "r" => self.refresh_data().await?,
            "reset-filter" => {
                self.filter_namespace = None;
                self.filter_state = None;
                self.status_message = Some("Filters reset".to_string());
            }
            "export" => {
                let state = self.app_state.state_manager.read().await;
                let export = state.export_state();
                let filename = format!("k8s-state-{}.json", chrono::Utc::now().format("%Y%m%d-%H%M%S"));
                tokio::fs::write(&filename, serde_json::to_string_pretty(&export)?).await?;
                self.status_message = Some(format!("Exported to {}", filename));
            }
            _ => {
                self.status_message = Some(format!("Unknown command: {}", command));
            }
        }

        self.input_buffer.clear();
        Ok(())
    }

    async fn refresh_data(&mut self) -> Result<()> {
        self.status_message = Some("Refreshing data...".to_string());
        Ok(())
    }

    async fn clear_events(&mut self) -> Result<()> {
        let mut state = self.app_state.state_manager.write().await;
        state.clear_history();
        self.status_message = Some("Events cleared".to_string());
        Ok(())
    }

    async fn show_resource_details(&mut self, resource_key: &str) -> Result<()> {
        self.status_message = Some(format!("Details for: {}", resource_key));
        Ok(())
    }

    pub async fn get_filtered_resources(&self) -> Vec<(String, crate::state::ResourceStateMachine)> {
        let state = self.app_state.state_manager.read().await;
        let mut resources: Vec<_> = state.resources.iter().map(|(k, v)| (k.clone(), v.clone())).collect();

        // Apply namespace filter
        if let Some(ref namespace) = self.filter_namespace {
            resources.retain(|(_, machine)| {
                machine.resource.namespace.as_deref().unwrap_or("default") == namespace
            });
        }

        // Apply state filter
        if let Some(ref state_filter) = self.filter_state {
            resources.retain(|(_, machine)| &machine.current_state == state_filter);
        }

        // Apply resource type filter
        match self.resource_tab {
            ResourceTab::All => {}
            ResourceTab::Pods => resources.retain(|(_, machine)| machine.resource.kind == "Pod"),
            ResourceTab::Services => resources.retain(|(_, machine)| machine.resource.kind == "Service"),
            ResourceTab::Deployments => resources.retain(|(_, machine)| machine.resource.kind == "Deployment"),
            ResourceTab::ConfigMaps => resources.retain(|(_, machine)| machine.resource.kind == "ConfigMap"),
            ResourceTab::Secrets => resources.retain(|(_, machine)| machine.resource.kind == "Secret"),
        }

        resources.sort_by(|a, b| b.1.last_updated.cmp(&a.1.last_updated));
        resources
    }
}