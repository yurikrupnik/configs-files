use anyhow::{Context, Result};
use crossterm::event::{self, Event, KeyCode, KeyEventKind};
use ratatui::{
    layout::{Constraint, Direction, Layout},
    style::{Color, Modifier, Style},
    text::{Line, Span, Text},
    widgets::{
        Block, Borders, List, ListItem, ListState, Paragraph, Wrap,
    },
    Frame,
};
use std::collections::HashMap;
use std::path::PathBuf;
use std::time::{Duration, Instant};

use crate::cli::Cli;
use crate::config::Config;
use crate::kcl::{KclValidator, ValidationResult};
use crate::taskfile::{Task, TaskObject, Taskfile};
use crate::tui::Tui;

#[derive(Debug, Clone, PartialEq)]
pub enum AppMode {
    TaskList,
    TaskEdit,
    TaskView,
    Help,
    Validation,
    Search,
}

#[derive(Debug, Clone)]
pub struct AppState {
    pub mode: AppMode,
    pub task_list_state: ListState,
    pub selected_task: Option<String>,
    pub editing_task: Option<TaskObject>,
    pub editing_task_name: String,
    pub search_query: String,
    pub filtered_tasks: Vec<String>,
    pub validation_result: Option<ValidationResult>,
    pub status_message: String,
    pub status_message_time: Option<Instant>,
    pub unsaved_changes: bool,
}

pub struct App {
    pub state: AppState,
    pub taskfile: Taskfile,
    pub taskfile_path: PathBuf,
    pub config: Config,
    pub validator: KclValidator,
}

impl App {
    pub async fn new(taskfile_path: &str, config_path: Option<&String>) -> Result<Self> {
        let config = if let Some(path) = config_path {
            Config::load(path)?
        } else {
            Config::load_or_default()?
        };

        let taskfile_path = PathBuf::from(taskfile_path);
        let taskfile = if taskfile_path.exists() {
            Taskfile::load(&taskfile_path)?
        } else {
            Taskfile {
                version: "3".to_string(),
                output: None,
                method: Some("checksum".to_string()),
                includes: None,
                vars: None,
                env: None,
                tasks: HashMap::new(),
                silent: None,
                dotenv: None,
                run: None,
                interval: None,
            }
        };

        let validator = KclValidator::new(config.kcl_schema_path.clone());
        
        let task_names: Vec<String> = taskfile.task_names().into_iter().cloned().collect();
        
        let mut task_list_state = ListState::default();
        if !task_names.is_empty() {
            task_list_state.select(Some(0));
        }

        let state = AppState {
            mode: AppMode::TaskList,
            task_list_state,
            selected_task: None,
            editing_task: None,
            editing_task_name: String::new(),
            search_query: String::new(),
            filtered_tasks: task_names,
            validation_result: None,
            status_message: "Ready".to_string(),
            status_message_time: None,
            unsaved_changes: false,
        };

        Ok(Self {
            state,
            taskfile,
            taskfile_path,
            config,
            validator,
        })
    }

    pub async fn run(&mut self, terminal: &mut Tui) -> Result<()> {
        self.validate_taskfile().await;
        
        loop {
            terminal.draw(|f| self.render(f))?;
            
            self.clear_old_status_message();
            
            if event::poll(Duration::from_millis(100))? {
                if let Event::Key(key) = event::read()? {
                    if key.kind == KeyEventKind::Press {
                        if self.handle_key_event(key.code).await? {
                            break;
                        }
                    }
                }
            }
        }
        
        Ok(())
    }

    async fn handle_key_event(&mut self, key: KeyCode) -> Result<bool> {
        match (&self.state.mode, key) {
            (_, KeyCode::Char('q')) if self.state.mode != AppMode::TaskEdit => {
                if self.state.unsaved_changes {
                    self.set_status_message("Warning: Unsaved changes! Press 'q' again to quit or 's' to save".to_string());
                    return Ok(false);
                }
                return Ok(true);
            }
            
            (AppMode::TaskList, KeyCode::Char('?')) => {
                self.state.mode = AppMode::Help;
            }
            
            (AppMode::Help, _) => {
                self.state.mode = AppMode::TaskList;
            }
            
            (AppMode::TaskList, KeyCode::Char('s')) => {
                self.save_taskfile().await?;
            }
            
            (AppMode::TaskList, KeyCode::Char('v')) => {
                self.validate_taskfile().await;
                self.state.mode = AppMode::Validation;
            }
            
            (AppMode::Validation, _) => {
                self.state.mode = AppMode::TaskList;
            }
            
            (AppMode::TaskList, KeyCode::Char('/')) => {
                self.state.mode = AppMode::Search;
                self.state.search_query.clear();
            }
            
            (AppMode::Search, KeyCode::Enter) => {
                self.apply_search_filter();
                self.state.mode = AppMode::TaskList;
            }
            
            (AppMode::Search, KeyCode::Esc) => {
                self.state.mode = AppMode::TaskList;
                self.state.search_query.clear();
                self.reset_task_filter();
            }
            
            (AppMode::Search, KeyCode::Char(c)) => {
                self.state.search_query.push(c);
            }
            
            (AppMode::Search, KeyCode::Backspace) => {
                self.state.search_query.pop();
            }
            
            (AppMode::TaskList, KeyCode::Char('n')) => {
                self.start_new_task();
            }
            
            (AppMode::TaskList, KeyCode::Char('e')) => {
                if let Some(selected) = self.get_selected_task_name() {
                    self.start_edit_task(selected);
                }
            }
            
            (AppMode::TaskList, KeyCode::Char('d')) => {
                if let Some(selected) = self.get_selected_task_name() {
                    self.delete_task(selected);
                }
            }
            
            (AppMode::TaskList, KeyCode::Char('r')) => {
                if let Some(selected) = self.get_selected_task_name() {
                    self.run_task(selected).await?;
                }
            }
            
            (AppMode::TaskList, KeyCode::Enter) => {
                if let Some(selected) = self.get_selected_task_name() {
                    self.state.selected_task = Some(selected);
                    self.state.mode = AppMode::TaskView;
                }
            }
            
            (AppMode::TaskView, _) => {
                self.state.mode = AppMode::TaskList;
            }
            
            (AppMode::TaskList, KeyCode::Down | KeyCode::Char('j')) => {
                self.next_task();
            }
            
            (AppMode::TaskList, KeyCode::Up | KeyCode::Char('k')) => {
                self.previous_task();
            }
            
            (AppMode::TaskEdit, KeyCode::Esc) => {
                self.cancel_edit_task();
            }
            
            (AppMode::TaskEdit, KeyCode::Enter) => {
                self.save_edited_task();
            }
            
            _ => {}
        }
        
        Ok(false)
    }

    fn render(&mut self, f: &mut Frame) {
        let chunks = Layout::default()
            .direction(Direction::Vertical)
            .constraints([
                Constraint::Length(1),
                Constraint::Min(0),
                Constraint::Length(3),
            ])
            .split(f.size());

        self.render_header(f, chunks[0]);
        
        match self.state.mode {
            AppMode::TaskList => self.render_task_list(f, chunks[1]),
            AppMode::TaskEdit => self.render_task_edit(f, chunks[1]),
            AppMode::TaskView => self.render_task_view(f, chunks[1]),
            AppMode::Help => self.render_help(f, chunks[1]),
            AppMode::Validation => self.render_validation(f, chunks[1]),
            AppMode::Search => self.render_search(f, chunks[1]),
        }
        
        self.render_status(f, chunks[2]);
    }

    fn render_header(&self, f: &mut Frame, area: ratatui::layout::Rect) {
        let title = format!(" Task Manager - {} ", self.taskfile_path.display());
        let header = Paragraph::new(title)
            .style(Style::default().fg(Color::Cyan).add_modifier(Modifier::BOLD));
        f.render_widget(header, area);
    }

    fn render_task_list(&mut self, f: &mut Frame, area: ratatui::layout::Rect) {
        let tasks: Vec<ListItem> = self.state.filtered_tasks
            .iter()
            .map(|task_name| {
                let task = self.taskfile.get_task(task_name);
                let desc = match task {
                    Some(Task::Object(obj)) => obj.desc.as_deref().unwrap_or(""),
                    _ => "",
                };
                
                let line = if desc.is_empty() {
                    Line::from(task_name.clone())
                } else {
                    Line::from(vec![
                        Span::styled(task_name.clone(), Style::default().fg(Color::Yellow)),
                        Span::raw(" - "),
                        Span::raw(desc),
                    ])
                };
                
                ListItem::new(line)
            })
            .collect();

        let tasks_list = List::new(tasks)
            .block(Block::default().title("Tasks").borders(Borders::ALL))
            .highlight_style(Style::default().bg(Color::Blue).fg(Color::White))
            .highlight_symbol("> ");

        f.render_stateful_widget(tasks_list, area, &mut self.state.task_list_state);
    }

    fn render_task_view(&self, f: &mut Frame, area: ratatui::layout::Rect) {
        if let Some(task_name) = &self.state.selected_task {
            if let Some(task) = self.taskfile.get_task(task_name) {
                let content = self.format_task_details(task_name, task);
                let paragraph = Paragraph::new(content)
                    .block(Block::default().title(format!("Task: {}", task_name)).borders(Borders::ALL))
                    .wrap(Wrap { trim: true });
                f.render_widget(paragraph, area);
            }
        }
    }

    fn render_task_edit(&self, f: &mut Frame, area: ratatui::layout::Rect) {
        let content = "Task editing interface (placeholder)";
        let paragraph = Paragraph::new(content)
            .block(Block::default().title("Edit Task").borders(Borders::ALL))
            .wrap(Wrap { trim: true });
        f.render_widget(paragraph, area);
    }

    fn render_help(&self, f: &mut Frame, area: ratatui::layout::Rect) {
        let help_text = vec![
            Line::from("Keybindings:"),
            Line::from(""),
            Line::from("q - Quit"),
            Line::from("? - Toggle help"),
            Line::from("s - Save taskfile"),
            Line::from("v - Validate with KCL"),
            Line::from("/ - Search tasks"),
            Line::from("n - New task"),
            Line::from("e - Edit selected task"),
            Line::from("d - Delete selected task"),
            Line::from("r - Run selected task"),
            Line::from("Enter - View task details"),
            Line::from("j/k or ↑/↓ - Navigate"),
            Line::from(""),
            Line::from("Press any key to return"),
        ];

        let paragraph = Paragraph::new(help_text)
            .block(Block::default().title("Help").borders(Borders::ALL))
            .wrap(Wrap { trim: true });
        f.render_widget(paragraph, area);
    }

    fn render_validation(&self, f: &mut Frame, area: ratatui::layout::Rect) {
        if let Some(result) = &self.state.validation_result {
            let mut lines = vec![];
            
            if result.is_valid {
                lines.push(Line::from(Span::styled("✓ Validation passed", Style::default().fg(Color::Green))));
            } else {
                lines.push(Line::from(Span::styled("✗ Validation failed", Style::default().fg(Color::Red))));
                lines.push(Line::from(""));
                
                for error in &result.errors {
                    lines.push(Line::from(Span::styled(format!("Error: {}", error.message), Style::default().fg(Color::Red))));
                }
                
                for warning in &result.warnings {
                    lines.push(Line::from(Span::styled(format!("Warning: {}", warning.message), Style::default().fg(Color::Yellow))));
                }
            }
            
            lines.push(Line::from(""));
            lines.push(Line::from("Press any key to return"));

            let paragraph = Paragraph::new(lines)
                .block(Block::default().title("KCL Validation").borders(Borders::ALL))
                .wrap(Wrap { trim: true });
            f.render_widget(paragraph, area);
        }
    }

    fn render_search(&self, f: &mut Frame, area: ratatui::layout::Rect) {
        let input = Paragraph::new(self.state.search_query.as_str())
            .block(Block::default().title("Search Tasks").borders(Borders::ALL));
        f.render_widget(input, area);
    }

    fn render_status(&self, f: &mut Frame, area: ratatui::layout::Rect) {
        let mut spans = vec![Span::raw(&self.state.status_message)];
        
        if self.state.unsaved_changes {
            spans.push(Span::raw(" "));
            spans.push(Span::styled("[Modified]", Style::default().fg(Color::Yellow)));
        }
        
        let status = Paragraph::new(Line::from(spans))
            .block(Block::default().borders(Borders::ALL));
        f.render_widget(status, area);
    }

    async fn validate_taskfile(&mut self) {
        let result = self.validator.validate_file(&self.taskfile_path).await
            .unwrap_or_else(|e| ValidationResult::error(e.to_string()));
        
        let message = if result.is_valid {
            "Validation passed".to_string()
        } else {
            format!("Validation failed: {} errors", result.errors.len())
        };
        
        self.state.validation_result = Some(result);
        self.set_status_message(message);
    }

    async fn save_taskfile(&mut self) -> Result<()> {
        self.taskfile.save(&self.taskfile_path)
            .context("Failed to save taskfile")?;
        
        self.state.unsaved_changes = false;
        self.set_status_message("Saved successfully".to_string());
        Ok(())
    }

    async fn run_task(&mut self, task_name: String) -> Result<()> {
        self.set_status_message(format!("Running task: {}", task_name));
        
        match Cli::run_task(&task_name, &self.taskfile_path.to_string_lossy()).await {
            Ok(_) => {
                self.set_status_message(format!("Task '{}' completed successfully", task_name));
            }
            Err(e) => {
                self.set_status_message(format!("Task '{}' failed: {}", task_name, e));
            }
        }
        
        Ok(())
    }

    fn start_new_task(&mut self) {
        self.state.editing_task = Some(TaskObject::new());
        self.state.editing_task_name = String::new();
        self.state.mode = AppMode::TaskEdit;
    }

    fn start_edit_task(&mut self, task_name: String) {
        if let Some(Task::Object(task)) = self.taskfile.get_task(&task_name).cloned() {
            self.state.editing_task = Some(task);
            self.state.editing_task_name = task_name;
            self.state.mode = AppMode::TaskEdit;
        }
    }

    fn save_edited_task(&mut self) {
        if let Some(task) = self.state.editing_task.take() {
            let task_name = if self.state.editing_task_name.is_empty() {
                format!("task-{}", uuid::Uuid::new_v4())
            } else {
                self.state.editing_task_name.clone()
            };
            
            self.taskfile.add_task(task_name.clone(), Task::Object(task));
            self.refresh_task_list();
            self.state.unsaved_changes = true;
            self.state.mode = AppMode::TaskList;
            self.set_status_message(format!("Task '{}' saved", task_name));
        }
    }

    fn cancel_edit_task(&mut self) {
        self.state.editing_task = None;
        self.state.editing_task_name.clear();
        self.state.mode = AppMode::TaskList;
    }

    fn delete_task(&mut self, task_name: String) {
        if self.taskfile.remove_task(&task_name).is_some() {
            self.refresh_task_list();
            self.state.unsaved_changes = true;
            self.set_status_message(format!("Task '{}' deleted", task_name));
        }
    }

    fn next_task(&mut self) {
        let i = match self.state.task_list_state.selected() {
            Some(i) => (i + 1) % self.state.filtered_tasks.len(),
            None => 0,
        };
        if !self.state.filtered_tasks.is_empty() {
            self.state.task_list_state.select(Some(i));
        }
    }

    fn previous_task(&mut self) {
        let i = match self.state.task_list_state.selected() {
            Some(i) => {
                if i == 0 {
                    self.state.filtered_tasks.len().saturating_sub(1)
                } else {
                    i - 1
                }
            }
            None => 0,
        };
        if !self.state.filtered_tasks.is_empty() {
            self.state.task_list_state.select(Some(i));
        }
    }

    fn get_selected_task_name(&self) -> Option<String> {
        self.state.task_list_state.selected()
            .and_then(|i| self.state.filtered_tasks.get(i))
            .cloned()
    }

    fn apply_search_filter(&mut self) {
        if self.state.search_query.is_empty() {
            self.reset_task_filter();
        } else {
            let query = self.state.search_query.to_lowercase();
            self.state.filtered_tasks = self.taskfile.task_names()
                .into_iter()
                .filter(|name| name.to_lowercase().contains(&query))
                .cloned()
                .collect();
            
            if !self.state.filtered_tasks.is_empty() {
                self.state.task_list_state.select(Some(0));
            } else {
                self.state.task_list_state.select(None);
            }
        }
    }

    fn reset_task_filter(&mut self) {
        self.state.filtered_tasks = self.taskfile.task_names().into_iter().cloned().collect();
        if !self.state.filtered_tasks.is_empty() {
            self.state.task_list_state.select(Some(0));
        }
    }

    fn refresh_task_list(&mut self) {
        self.reset_task_filter();
    }

    fn format_task_details(&self, _task_name: &str, task: &Task) -> Text {
        match task {
            Task::String(cmd) => Text::from(vec![
                Line::from(vec![Span::styled("Command:", Style::default().fg(Color::Yellow))]),
                Line::from(cmd.clone()),
            ]),
            Task::Commands(cmds) => {
                let mut lines = vec![
                    Line::from(vec![Span::styled("Commands:", Style::default().fg(Color::Yellow))]),
                ];
                for (i, cmd) in cmds.iter().enumerate() {
                    lines.push(Line::from(format!("{}. {:?}", i + 1, cmd)));
                }
                Text::from(lines)
            },
            Task::Object(obj) => {
                let mut lines = vec![];
                
                if let Some(desc) = &obj.desc {
                    lines.push(Line::from(vec![Span::styled("Description:", Style::default().fg(Color::Yellow))]));
                    lines.push(Line::from(desc.clone()));
                    lines.push(Line::from(""));
                }
                
                if let Some(summary) = &obj.summary {
                    lines.push(Line::from(vec![Span::styled("Summary:", Style::default().fg(Color::Yellow))]));
                    lines.push(Line::from(summary.clone()));
                    lines.push(Line::from(""));
                }
                
                if let Some(cmds) = &obj.cmds {
                    lines.push(Line::from(vec![Span::styled("Commands:", Style::default().fg(Color::Yellow))]));
                    for (i, cmd) in cmds.iter().enumerate() {
                        lines.push(Line::from(format!("{}. {:?}", i + 1, cmd)));
                    }
                }
                
                Text::from(lines)
            },
        }
    }

    fn set_status_message(&mut self, message: String) {
        self.state.status_message = message;
        self.state.status_message_time = Some(Instant::now());
    }

    fn clear_old_status_message(&mut self) {
        if let Some(time) = self.state.status_message_time {
            if time.elapsed() > Duration::from_secs(5) {
                self.state.status_message = "Ready".to_string();
                self.state.status_message_time = None;
            }
        }
    }
}