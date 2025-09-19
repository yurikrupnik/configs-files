use ratatui::{
    layout::{Constraint, Direction, Layout, Rect},
    style::{Color, Modifier, Style},
    text::{Line, Span},
    widgets::{Block, Borders, Gauge, List, ListItem, Paragraph, Table, Row, Cell},
    Frame, backend::Backend,
};
use crate::state::{ResourceState, ResourceStateMachine, ResourceEvent};

pub struct ResourceTable {
    pub resources: Vec<(String, ResourceStateMachine)>,
    pub selected: Option<usize>,
    pub scroll_offset: usize,
}

impl ResourceTable {
    pub fn new(resources: Vec<(String, ResourceStateMachine)>) -> Self {
        Self {
            resources,
            selected: None,
            scroll_offset: 0,
        }
    }

    pub fn render(&self, frame: &mut ratatui::Frame, area: Rect) {
        let header = Row::new(vec![
            Cell::from("Name"),
            Cell::from("Kind"),
            Cell::from("Namespace"),
            Cell::from("State"),
            Cell::from("Age"),
            Cell::from("Events"),
        ])
        .style(Style::default().fg(Color::Yellow).add_modifier(Modifier::BOLD))
        .height(1);

        let rows: Vec<Row> = self
            .resources
            .iter()
            .skip(self.scroll_offset)
            .take(20)
            .map(|(key, machine)| {
                let state_style = match machine.current_state {
                    ResourceState::Running | ResourceState::Succeeded => Style::default().fg(Color::Green),
                    ResourceState::Failed => Style::default().fg(Color::Red),
                    ResourceState::Terminating => Style::default().fg(Color::Magenta),
                    ResourceState::Pending => Style::default().fg(Color::Yellow),
                    ResourceState::Unknown => Style::default().fg(Color::Gray),
                };

                let age = format_duration(chrono::Utc::now() - machine.last_updated);

                Row::new(vec![
                    Cell::from(machine.resource.name.clone()),
                    Cell::from(machine.resource.kind.clone()),
                    Cell::from(machine.resource.namespace.clone().unwrap_or_else(|| "default".to_string())),
                    Cell::from(machine.current_state.to_string()).style(state_style),
                    Cell::from(age),
                    Cell::from(machine.event_count.to_string()),
                ])
            })
            .collect();

        let table = Table::new(rows, [
                Constraint::Percentage(25),
                Constraint::Percentage(15),
                Constraint::Percentage(15),
                Constraint::Percentage(15),
                Constraint::Percentage(15),
                Constraint::Percentage(15),
            ])
            .header(header)
            .block(Block::default().borders(Borders::ALL).title("Resources"))
            .column_spacing(1);

        frame.render_widget(table, area);
    }
}

pub struct EventList {
    pub events: Vec<ResourceEvent>,
    pub selected: Option<usize>,
    pub scroll_offset: usize,
}

impl EventList {
    pub fn new(events: Vec<ResourceEvent>) -> Self {
        Self {
            events,
            selected: None,
            scroll_offset: 0,
        }
    }

    pub fn render(&self, frame: &mut ratatui::Frame, area: Rect) {
        let items: Vec<ListItem> = self
            .events
            .iter()
            .rev()
            .skip(self.scroll_offset)
            .take(50)
            .map(|event| {
                let timestamp = event.timestamp.format("%H:%M:%S").to_string();
                let severity_icon = match event.event_type.severity() {
                    "info" => "ℹ️",
                    "warning" => "⚠️",
                    "error" => "❌",
                    _ => "📝",
                };

                let content = format!(
                    "{} {} {}/{} - {} → {}",
                    timestamp,
                    severity_icon,
                    event.resource.kind,
                    event.resource.name,
                    event.previous_state.as_ref().map(|s| s.to_string()).unwrap_or_else(|| "None".to_string()),
                    event.current_state
                );

                let style = match event.event_type.severity() {
                    "error" => Style::default().fg(Color::Red),
                    "warning" => Style::default().fg(Color::Yellow),
                    "info" => Style::default().fg(Color::White),
                    _ => Style::default().fg(Color::Gray),
                };

                ListItem::new(Line::from(Span::styled(content, style)))
            })
            .collect();

        let list = List::new(items)
            .block(Block::default().borders(Borders::ALL).title("Recent Events"))
            .highlight_style(Style::default().fg(Color::Black).bg(Color::White));

        frame.render_widget(list, area);
    }
}

pub struct MetricsOverview {
    pub healthy_count: u64,
    pub unhealthy_count: u64,
    pub unknown_count: u64,
    pub total_count: u64,
    pub events_count: u64,
}

impl MetricsOverview {
    pub fn render(&self, frame: &mut ratatui::Frame, area: Rect) {
        let chunks = Layout::default()
            .direction(Direction::Horizontal)
            .constraints([
                Constraint::Percentage(20),
                Constraint::Percentage(20),
                Constraint::Percentage(20),
                Constraint::Percentage(20),
                Constraint::Percentage(20),
            ])
            .split(area);

        let total = self.total_count.max(1);

        // Healthy resources gauge
        let healthy_percent = ((self.healthy_count * 100) / total) as u16;
        let healthy_gauge = Gauge::default()
            .block(Block::default().borders(Borders::ALL).title("Healthy"))
            .gauge_style(Style::default().fg(Color::Green))
            .percent(healthy_percent)
            .label(format!("{}/{}", self.healthy_count, self.total_count));
        frame.render_widget(healthy_gauge, chunks[0]);

        // Unhealthy resources gauge
        let unhealthy_percent = ((self.unhealthy_count * 100) / total) as u16;
        let unhealthy_gauge = Gauge::default()
            .block(Block::default().borders(Borders::ALL).title("Unhealthy"))
            .gauge_style(Style::default().fg(Color::Red))
            .percent(unhealthy_percent)
            .label(format!("{}/{}", self.unhealthy_count, self.total_count));
        frame.render_widget(unhealthy_gauge, chunks[1]);

        // Unknown resources gauge
        let unknown_percent = ((self.unknown_count * 100) / total) as u16;
        let unknown_gauge = Gauge::default()
            .block(Block::default().borders(Borders::ALL).title("Unknown"))
            .gauge_style(Style::default().fg(Color::Yellow))
            .percent(unknown_percent)
            .label(format!("{}/{}", self.unknown_count, self.total_count));
        frame.render_widget(unknown_gauge, chunks[2]);

        // Total resources
        let total_gauge = Gauge::default()
            .block(Block::default().borders(Borders::ALL).title("Total"))
            .gauge_style(Style::default().fg(Color::Blue))
            .percent(100)
            .label(format!("{}", self.total_count));
        frame.render_widget(total_gauge, chunks[3]);

        // Events count
        let events_gauge = Gauge::default()
            .block(Block::default().borders(Borders::ALL).title("Events"))
            .gauge_style(Style::default().fg(Color::Cyan))
            .percent(100)
            .label(format!("{}", self.events_count));
        frame.render_widget(events_gauge, chunks[4]);
    }
}

pub struct ResourceDetails {
    pub resource: ResourceStateMachine,
}

impl ResourceDetails {
    pub fn render(&self, frame: &mut ratatui::Frame, area: Rect) {
        let chunks = Layout::default()
            .direction(Direction::Vertical)
            .constraints([
                Constraint::Length(8),  // Basic info
                Constraint::Min(0),     // State history
            ])
            .split(area);

        // Basic resource information
        let info_text = vec![
            Line::from(vec![
                Span::raw("Name: "),
                Span::styled(self.resource.resource.name.clone(), Style::default().fg(Color::Cyan)),
            ]),
            Line::from(vec![
                Span::raw("Kind: "),
                Span::styled(self.resource.resource.kind.clone(), Style::default().fg(Color::Green)),
            ]),
            Line::from(vec![
                Span::raw("Namespace: "),
                Span::styled(
                    self.resource.resource.namespace.clone().unwrap_or_else(|| "default".to_string()),
                    Style::default().fg(Color::Yellow),
                ),
            ]),
            Line::from(vec![
                Span::raw("Current State: "),
                Span::styled(self.resource.current_state.to_string(), state_color(&self.resource.current_state)),
            ]),
            Line::from(vec![
                Span::raw("Last Updated: "),
                Span::styled(
                    self.resource.last_updated.format("%Y-%m-%d %H:%M:%S UTC").to_string(),
                    Style::default().fg(Color::Gray),
                ),
            ]),
            Line::from(vec![
                Span::raw("Event Count: "),
                Span::styled(self.resource.event_count.to_string(), Style::default().fg(Color::Magenta)),
            ]),
        ];

        let info_paragraph = Paragraph::new(info_text)
            .block(Block::default().borders(Borders::ALL).title("Resource Details"));
        frame.render_widget(info_paragraph, chunks[0]);

        // State history
        let history_items: Vec<ListItem> = self
            .resource
            .state_history
            .iter()
            .rev()
            .take(20)
            .map(|transition| {
                let timestamp = transition.timestamp.format("%H:%M:%S").to_string();
                let content = format!(
                    "{} {} → {} ({})",
                    timestamp,
                    transition.from,
                    transition.to,
                    transition.trigger
                );
                ListItem::new(Line::from(content))
            })
            .collect();

        let history_list = List::new(history_items)
            .block(Block::default().borders(Borders::ALL).title("State History"));
        frame.render_widget(history_list, chunks[1]);
    }
}

fn state_color(state: &ResourceState) -> Style {
    match state {
        ResourceState::Running | ResourceState::Succeeded => Style::default().fg(Color::Green),
        ResourceState::Failed => Style::default().fg(Color::Red),
        ResourceState::Terminating => Style::default().fg(Color::Magenta),
        ResourceState::Pending => Style::default().fg(Color::Yellow),
        ResourceState::Unknown => Style::default().fg(Color::Gray),
    }
}

fn format_duration(duration: chrono::Duration) -> String {
    let total_seconds = duration.num_seconds().abs();
    
    if total_seconds < 60 {
        format!("{}s", total_seconds)
    } else if total_seconds < 3600 {
        format!("{}m", total_seconds / 60)
    } else if total_seconds < 86400 {
        format!("{}h", total_seconds / 3600)
    } else {
        format!("{}d", total_seconds / 86400)
    }
}